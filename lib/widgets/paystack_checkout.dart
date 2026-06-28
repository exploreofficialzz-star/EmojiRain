// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/paystack_checkout.dart
//
// WebView-based Paystack Inline Popup.
//
// WHY THE REWRITE:
//   flutter_paystack required http ^0.13.x, which is permanently incompatible
//   with internet_connection_checker_plus >=2.0.0 (requires http ^1.0.0).
//   This implementation drops flutter_paystack entirely and uses
//   webview_flutter + Paystack's official Inline JS v2 instead — same result,
//   no dependency conflict, and Paystack's own UI renders natively.
//
// PUBLIC API (identical to previous version — no callers need to change):
//   await PaystackCheckout.initialize();          ← call once in main()
//   final res = await PaystackCheckout.pay(       ← use anywhere
//     context, productId: 'emoji_rain_no_ads_week'
//   );
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/paystack_service.dart';

// ── Result ────────────────────────────────────────────────────────────────────

enum PaystackPaymentStatus { success, failed, cancelled }

class PaystackPaymentResult {
  final PaystackPaymentStatus status;
  final String?               reference;
  final String?               productId;

  const PaystackPaymentResult({
    required this.status,
    this.reference,
    this.productId,
  });

  bool get isSuccess => status == PaystackPaymentStatus.success;
}

// ── Checkout handler ──────────────────────────────────────────────────────────

class PaystackCheckout {
  PaystackCheckout._();

  static bool _initialized = false;

  /// Call once from main.dart before runApp().
  /// No-op with this WebView implementation — kept for API compatibility.
  static Future<void> initialize() async {
    _initialized = true;
  }

  /// Launch the Paystack inline payment form in a modal bottom sheet.
  /// Returns a [PaystackPaymentResult] with success / failed / cancelled status.
  static Future<PaystackPaymentResult> pay(
    BuildContext context, {
    required String productId,
  }) async {
    assert(_initialized, 'Call PaystackCheckout.initialize() before pay().');

    final tier = PaystackService.tiers[productId];
    if (tier == null) {
      return const PaystackPaymentResult(status: PaystackPaymentStatus.failed);
    }

    if (!context.mounted) {
      return const PaystackPaymentResult(status: PaystackPaymentStatus.cancelled);
    }

    final reference = PaystackService.generateReference(productId);
    final email     = 'player_${_randomId()}@emojirain.app';
    final completer = Completer<PaystackPaymentResult>();

    await showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      isDismissible:      true,
      enableDrag:         false,
      builder: (_) => _PaystackSheet(
        publicKey:  PaystackService.publicKey,
        email:      email,
        amountKobo: tier.amountKobo,
        currency:   PaystackService.currency,
        reference:  reference,
        productId:  productId,
        tierLabel:  tier.label,
        onResult: (result) {
          if (!completer.isCompleted) completer.complete(result);
          // Pop the bottom sheet that showModalBottomSheet opened.
          if (context.mounted) {
            try {
              Navigator.of(context, rootNavigator: true).pop();
            } catch (_) {}
          }
        },
      ),
    );

    // Covers external dismissal (tap outside / device back button) —
    // the bottom sheet closed without going through onResult.
    if (!completer.isCompleted) {
      completer.complete(PaystackPaymentResult(
        status:    PaystackPaymentStatus.cancelled,
        productId: productId,
      ));
    }

    return completer.future;
  }

  static String _randomId() =>
      Random().nextInt(999999).toString().padLeft(6, '0');
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _PaystackSheet extends StatefulWidget {
  final String publicKey;
  final String email;
  final int    amountKobo;
  final String currency;
  final String reference;
  final String productId;
  final String tierLabel;
  final void Function(PaystackPaymentResult) onResult;

  const _PaystackSheet({
    required this.publicKey,
    required this.email,
    required this.amountKobo,
    required this.currency,
    required this.reference,
    required this.productId,
    required this.tierLabel,
    required this.onResult,
  });

  @override
  State<_PaystackSheet> createState() => _PaystackSheetState();
}

class _PaystackSheetState extends State<_PaystackSheet> {
  late final WebViewController _controller;
  bool _loading    = true;
  bool _resultSent = false;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  WebViewController _buildController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('FlutterBridge', onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadHtmlString(_buildHtml());
  }

  // ── JS → Dart bridge ──────────────────────────────────────────────────────

  void _onBridgeMessage(JavaScriptMessage msg) {
    if (_resultSent) return;
    _resultSent = true;

    try {
      final data      = jsonDecode(msg.message) as Map<String, dynamic>;
      final event     = data['event'] as String? ?? '';
      final reference = data['reference'] as String?;

      final result = switch (event) {
        'success' => PaystackPaymentResult(
            status:    PaystackPaymentStatus.success,
            reference: reference ?? widget.reference,
            productId: widget.productId,
          ),
        'cancelled' => PaystackPaymentResult(
            status:    PaystackPaymentStatus.cancelled,
            productId: widget.productId,
          ),
        _ => PaystackPaymentResult(
            status:    PaystackPaymentStatus.failed,
            productId: widget.productId,
          ),
      };

      widget.onResult(result);
    } catch (_) {
      widget.onResult(PaystackPaymentResult(
        status:    PaystackPaymentStatus.failed,
        productId: widget.productId,
      ));
    }
  }

  void _dismiss() {
    if (_resultSent) return;
    _resultSent = true;
    widget.onResult(PaystackPaymentResult(
      status:    PaystackPaymentStatus.cancelled,
      productId: widget.productId,
    ));
  }

  // ── HTML payload ──────────────────────────────────────────────────────────

  String _buildHtml() {
    // Local variables avoid accidental widget.x interpolation inside JS blocks.
    final pk  = widget.publicKey;
    final em  = widget.email;
    final amt = widget.amountKobo;
    final cur = widget.currency;
    final ref = widget.reference;

    // Paystack Inline JS v2 — container mode renders the form directly into
    // #ps-container without a popup overlay. FlutterBridge.postMessage() sends
    // the result back to Dart via the JavaScriptChannel defined above.
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0,
        maximum-scale=1.0, user-scalable=no">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
      width: 100%;
      background: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    #ps-container { width: 100%; min-height: 580px; }
    .ps-placeholder {
      display: flex; align-items: center; justify-content: center;
      min-height: 300px; color: #aaaaaa; font-size: 14px;
    }
    .ps-error {
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      min-height: 300px; padding: 32px; text-align: center;
    }
    .ps-error h3 { font-size: 17px; color: #cc0000; margin-bottom: 10px; }
    .ps-error p  { font-size: 13px; color: #666666; line-height: 1.6; }
    .ps-btn {
      margin-top: 22px; padding: 13px 30px;
      background: #0050c8; color: #ffffff;
      border: none; border-radius: 9px;
      font-size: 14px; font-weight: 700; cursor: pointer;
    }
  </style>
</head>
<body>
  <div id="ps-container">
    <div class="ps-placeholder">Loading secure payment\u2026</div>
  </div>

  <script src="https://js.paystack.co/v2/inline.js"
          onerror="onScriptError()"></script>
  <script>
    function sendResult(obj) {
      window.FlutterBridge.postMessage(JSON.stringify(obj));
    }

    function goBack() {
      sendResult({ event: 'cancelled' });
    }

    function onScriptError() {
      document.getElementById('ps-container').innerHTML =
        '<div class="ps-error">' +
        '<h3>Could not load payment</h3>' +
        '<p>Please check your internet connection and try again.</p>' +
        '<button class="ps-btn" onclick="goBack()">Go Back</button>' +
        '</div>';
    }

    window.addEventListener('load', function () {
      if (typeof PaystackPop === 'undefined') { onScriptError(); return; }
      try {
        PaystackPop.newTransaction({
          key:       '$pk',
          email:     '$em',
          amount:    $amt,
          currency:  '$cur',
          ref:       '$ref',
          container: 'ps-container',
          onSuccess: function (t) {
            sendResult({ event: 'success', reference: t.reference || '$ref' });
          },
          onCancel: function () {
            sendResult({ event: 'cancelled' });
          }
        });
      } catch (err) {
        sendResult({ event: 'failed', message: String(err) });
      }
    });
  </script>
</body>
</html>''';
  }

  // ── Widget ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      height:     sheetHeight,
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                const Text('🎮', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emoji Rain — Remove Ads',
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w800,
                          color:      Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        widget.tierLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color:    Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding:    const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:        Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      size:  18,
                      color: Color(0xFF555555),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color:       Color(0xFF0050C8),
                      strokeWidth: 2.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
