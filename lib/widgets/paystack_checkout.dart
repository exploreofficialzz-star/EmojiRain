// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/paystack_checkout.dart
//
// CHANGES IN THIS VERSION:
//   1. Email collection step — shows a bottom sheet to capture the user's
//      email before opening the payment page. Email is saved in
//      SharedPreferences so they don't have to re-enter it next time.
//
//   2. Popup mode — uses Paystack's own in-page popup UI (rendered via
//      InlineJS v2's `newTransaction()`) rather than embedding a custom
//      container div. Renders correctly across Android WebView versions.
//
//   3. Full-screen page — payment now uses Navigator.push (fullscreenDialog)
//      instead of showModalBottomSheet so fixed-position elements in the
//      Paystack iframe are not clipped by the sheet boundaries.
//
//   4. STALE-CONTEXT FIX (critical) — callers like RemoveAdsSheet pop their
//      own bottom sheet immediately before calling pay(context, ...). By the
//      time the user finishes typing their email, that original `context`
//      has long since unmounted, so the old `if (!context.mounted) return
//      cancelled;` check silently killed the entire flow right after email
//      entry — the payment page never opened. Fixed by capturing the ROOT
//      Navigator's own BuildContext ONCE, synchronously, at the very start
//      of pay() — before any await runs. That context belongs to the
//      Navigator created by MaterialApp itself, which stays mounted for the
//      entire app session regardless of what the caller's own sheet does.
//   5. ROOT CAUSE OF "Could not load payment" FIXED — the JS was calling
//      `PaystackPop.newTransaction({...})` as a static method then
//      `.openIframe()` on the result. Neither exists in InlineJS v2; both
//      are V1 API leftovers. Confirmed against Paystack's own v2 docs: you
//      must do `new Paystack()` (or `new PaystackPop()` — Paystack's own
//      docs are inconsistent about the name, so both are checked at
//      runtime) then call `.newTransaction({...})` on that INSTANCE, which
//      renders the popup automatically — no separate "open" call exists in
//      v2. The old static call threw a TypeError immediately, silently
//      swallowed by the try/catch into the generic error screen. Also fixed
//      `ref` → `reference` (the real v2 param — `ref` was being silently
//      ignored), added `onError`/`onLoad` handlers, and a 12s safety
//      timeout so a stalled load fails loudly instead of spinning forever.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _emailKey = 'paystack_player_email';

  static Future<void> initialize() async => _initialized = true;

  /// Collect email → open full-screen Paystack page → return result.
  static Future<PaystackPaymentResult> pay(
    BuildContext context, {
    required String productId,
  }) async {
    assert(_initialized, 'Call PaystackCheckout.initialize() first.');

    final tier = PaystackService.tiers[productId];
    if (tier == null) {
      return const PaystackPaymentResult(status: PaystackPaymentStatus.failed);
    }
    if (!context.mounted) {
      return const PaystackPaymentResult(status: PaystackPaymentStatus.cancelled);
    }

    // ── Capture a STABLE context tied to the root Navigator itself ─────────
    // Must happen synchronously, right here, before any `await`. Callers
    // (e.g. RemoveAdsSheet) commonly pop their own bottom sheet immediately
    // before/after invoking pay() — which unmounts their `context` partway
    // through this function. `rootContext` instead belongs to the Navigator
    // MaterialApp itself creates, so it remains valid for the whole app
    // session no matter what the caller's sheet does.
    final BuildContext rootContext =
        Navigator.of(context, rootNavigator: true).context;

    // ── Step 1: collect email ─────────────────────────────────────────────
    final email = await _collectEmail(rootContext);
    if (email == null || email.isEmpty) {
      return PaystackPaymentResult(
        status:    PaystackPaymentStatus.cancelled,
        productId: productId,
      );
    }

    if (!rootContext.mounted) {
      return PaystackPaymentResult(
        status:    PaystackPaymentStatus.cancelled,
        productId: productId,
      );
    }

    // ── Step 2: open full-screen payment page ─────────────────────────────
    final reference = PaystackService.generateReference(productId);

    final result = await Navigator.of(rootContext, rootNavigator: true)
        .push<PaystackPaymentResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PaystackPage(
          publicKey:  PaystackService.publicKey,
          email:      email,
          amountKobo: tier.amountKobo,
          currency:   PaystackService.currency,
          reference:  reference,
          productId:  productId,
          tierLabel:  '${tier.label} · ${tier.displayPrice}',
        ),
      ),
    );

    return result ??
        PaystackPaymentResult(
          status:    PaystackPaymentStatus.cancelled,
          productId: productId,
        );
  }

  // ── Email collection ──────────────────────────────────────────────────────
  static Future<String?> _collectEmail(BuildContext context) async {
    final prefs  = await SharedPreferences.getInstance();
    final saved  = prefs.getString(_emailKey) ?? '';

    if (!context.mounted) return null;

    final email = await showModalBottomSheet<String>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _EmailSheet(prefillEmail: saved),
    );

    if (email != null && email.isNotEmpty) {
      await prefs.setString(_emailKey, email);
    }
    return email;
  }
}

// ── Email collection sheet ────────────────────────────────────────────────────

class _EmailSheet extends StatefulWidget {
  final String prefillEmail;
  const _EmailSheet({required this.prefillEmail});

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  late final TextEditingController _ctrl;
  bool _isValid = false;

  static final _emailRx =
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

  @override
  void initState() {
    super.initState();
    _ctrl     = TextEditingController(text: widget.prefillEmail);
    _isValid  = _emailRx.hasMatch(widget.prefillEmail.trim());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _ctrl.text.trim();
    if (!_emailRx.hasMatch(email)) return;
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color:        Color(0xFF12122A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF2A2A50))),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // Header
            const Text(
              '📧  Enter your email',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Your payment receipt will be sent here.",
              style: TextStyle(fontSize: 13, color: Color(0xFF78909C)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),

            // Email field
            TextField(
              controller:        _ctrl,
              keyboardType:      TextInputType.emailAddress,
              autofocus:         widget.prefillEmail.isEmpty,
              autocorrect:       false,
              enableSuggestions: false,
              textInputAction:   TextInputAction.done,
              inputFormatters:   [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText:  'you@example.com',
                hintStyle: const TextStyle(color: Color(0xFF546E7A)),
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF546E7A), size: 20),
                filled:    true,
                fillColor: const Color(0xFF1A1A35),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2A2A50)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0050C8), width: 1.5),
                ),
              ),
              onChanged:   (v) => setState(() => _isValid = _emailRx.hasMatch(v.trim())),
              onSubmitted: (_) => _isValid ? _submit() : null,
            ),
            const SizedBox(height: 18),

            // Continue button
            GestureDetector(
              onTap: _isValid ? _submit : null,
              child: AnimatedOpacity(
                opacity:  _isValid ? 1.0 : 0.38,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width:  double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color:        const Color(0xFF0050C8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Continue to Payment',
                        style: TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Paystack badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 12, color: Colors.white.withOpacity(0.28)),
                const SizedBox(width: 5),
                Text(
                  'Secured by Paystack',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.28),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full-screen payment page ──────────────────────────────────────────────────

class _PaystackPage extends StatefulWidget {
  final String publicKey;
  final String email;
  final int    amountKobo;
  final String currency;
  final String reference;
  final String productId;
  final String tierLabel;

  const _PaystackPage({
    required this.publicKey,
    required this.email,
    required this.amountKobo,
    required this.currency,
    required this.reference,
    required this.productId,
    required this.tierLabel,
  });

  @override
  State<_PaystackPage> createState() => _PaystackPageState();
}

class _PaystackPageState extends State<_PaystackPage> {
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
      ..setBackgroundColor(const Color(0xFFF8F9FA))
      ..addJavaScriptChannel('FlutterBridge', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished:     (_) { if (mounted) setState(() => _loading = false); },
        onWebResourceError: (_) { if (mounted) setState(() => _loading = false); },
      ))
      // baseUrl gives this page a REAL origin (Paystack's own domain) instead
      // of the opaque/null origin loadHtmlString produces by default. Without
      // this, Paystack's checkout iframe can fail same-origin/postMessage
      // checks during its internal redirects (3DS, bank OTP, etc.).
      ..loadHtmlString(_buildHtml(), baseUrl: 'https://checkout.paystack.com');
  }

  void _onMessage(JavaScriptMessage msg) {
    if (_resultSent) return;
    _resultSent = true;

    try {
      final data  = jsonDecode(msg.message) as Map<String, dynamic>;
      final event = data['event'] as String? ?? '';
      final ref   = data['reference'] as String?;

      final result = switch (event) {
        'success' => PaystackPaymentResult(
            status:    PaystackPaymentStatus.success,
            reference: ref ?? widget.reference,
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

      if (mounted) Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(PaystackPaymentResult(
          status:    PaystackPaymentStatus.failed,
          productId: widget.productId,
        ));
      }
    }
  }

  void _dismiss() {
    if (_resultSent) return;
    _resultSent = true;
    Navigator.of(context).pop(PaystackPaymentResult(
      status:    PaystackPaymentStatus.cancelled,
      productId: widget.productId,
    ));
  }

  // ── HTML: correct InlineJS v2 API ─────────────────────────────────────────
  //
  // ROOT CAUSE OF "Could not load payment": this code was calling
  // `PaystackPop.newTransaction({...})` as a static method, then
  // `.openIframe()` on the result. Neither exists in InlineJS v2 — both are
  // leftover V1 API shapes. Confirmed against Paystack's own v2 reference
  // docs (paystack.com/docs/developer-tools/inlinejs): you must INSTANTIATE
  // the popup first (`new Paystack()`), then call `.newTransaction({...})`
  // on that instance — which renders the popup automatically. There is no
  // separate "open" step in v2. Calling `PaystackPop.newTransaction` as a
  // static method threw a TypeError immediately (newTransaction only exists
  // on the instance prototype), which our try/catch silently swallowed into
  // the generic "Could not load payment" screen.
  //
  // Also fixed: `ref` → `reference` (the actual v2 param name — `ref` was
  // being silently ignored, so Paystack was generating its own reference
  // instead of ours), added `onError` (genuine payment-time failures now
  // surface instead of hanging silently) and `onLoad` (fires once the
  // popup UI itself is actually visible — used to hide the splash screen
  // precisely, with a 12s safety-timeout fallback in case it never fires).
  //
  // Defensive: checks for both `Paystack` (current official docs) and
  // `PaystackPop` (older docs/migration guide reference the same name) since
  // Paystack's own documentation is inconsistent about which name the CDN
  // script exposes — this works correctly regardless of which is actually
  // defined at runtime.
  String _buildHtml() {
    final pk  = widget.publicKey;
    final em  = widget.email;
    final amt = widget.amountKobo;
    final cur = widget.currency;
    final ref = widget.reference;

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport"
        content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
      width: 100%; height: 100%;
      background: #f8f9fa;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    #splash {
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      height: 100vh; color: #aaa; font-size: 14px;
    }
    .spinner {
      width: 38px; height: 38px;
      border: 3px solid #e5e5e5;
      border-top-color: #0050C8;
      border-radius: 50%;
      animation: spin 0.75s linear infinite;
      margin-bottom: 16px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    #error-box {
      display: none; flex-direction: column;
      align-items: center; justify-content: center;
      height: 100vh; padding: 32px; text-align: center;
    }
    #error-box h3 { font-size: 18px; color: #c00; margin-bottom: 10px; }
    #error-box p  { font-size: 13px; color: #666; line-height: 1.6; }
    .btn {
      margin-top: 20px; padding: 13px 28px;
      background: #0050C8; color: #fff;
      border: none; border-radius: 10px;
      font-size: 14px; font-weight: 700; cursor: pointer;
    }
  </style>
</head>
<body>
  <div id="splash">
    <div class="spinner"></div>
    <span>Opening secure payment\u2026</span>
  </div>
  <div id="error-box">
    <h3>Could not load payment</h3>
    <p>Please check your internet connection and try again.</p>
    <button class="btn" onclick="goBack()">Go Back</button>
  </div>

  <script src="https://js.paystack.co/v2/inline.js"
          onerror="showError()"></script>
  <script>
    var done = false;

    function send(obj) {
      if (done) return;
      done = true;
      window.FlutterBridge.postMessage(JSON.stringify(obj));
    }
    function goBack()    { send({ event: 'cancelled' }); }
    function showError() {
      if (done) return;
      document.getElementById('splash').style.display    = 'none';
      document.getElementById('error-box').style.display = 'flex';
    }

    window.addEventListener('load', function () {
      // Defensive: official Paystack docs use `Paystack` as the v2
      // constructor name, but their own migration guide uses `PaystackPop`.
      // Accept whichever the loaded script actually defines.
      var Ctor = (typeof Paystack !== 'undefined') ? Paystack
               : (typeof PaystackPop !== 'undefined' ? PaystackPop : null);

      if (!Ctor) { showError(); return; }

      try {
        var popup = new Ctor();

        // Safety net: if the popup UI never reports onLoad within 12s
        // (network stall, blocked resource, etc.), fail loudly instead of
        // spinning forever with no feedback.
        var safetyTimer = setTimeout(function () {
          if (!done) showError();
        }, 12000);

        popup.newTransaction({
          key:       '$pk',
          email:     '$em',
          amount:    $amt,
          currency:  '$cur',
          reference: '$ref',
          onLoad: function () {
            // Popup UI is actually visible now — clear the splash.
            clearTimeout(safetyTimer);
            document.getElementById('splash').style.display = 'none';
          },
          onSuccess: function (transaction) {
            send({ event: 'success', reference: transaction.reference || '$ref' });
          },
          onCancel: function () {
            send({ event: 'cancelled' });
          },
          onError: function (error) {
            send({
              event:   'failed',
              message: (error && error.message) ? error.message : 'unknown_error'
            });
          }
        });
      } catch (err) {
        showError();
      }
    });
  </script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0050C8),
        elevation:       0,
        leading: IconButton(
          icon:    const Icon(Icons.close, color: Colors.white),
          onPressed: _dismiss,
          tooltip: 'Cancel',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Secure Payment',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white,
              ),
            ),
            Text(
              widget.tierLabel,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white70, size: 13),
                const SizedBox(width: 4),
                Text(
                  'Paystack',
                  style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
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
    );
  }
}
