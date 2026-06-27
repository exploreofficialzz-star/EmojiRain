import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import '../constants/app_constants.dart';
import 'paystack_service.dart';

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

  static final PaystackPlugin _plugin = PaystackPlugin();
  static bool _initialized = false;

  /// Call once from main.dart before app runs
  static Future<void> initialize() async {
    if (_initialized) return;
    await _plugin.initialize(publicKey: PaystackService.publicKey);
    _initialized = true;
  }

  /// Launch the native Paystack payment popup.
  /// Returns result with success/fail/cancel status.
  static Future<PaystackPaymentResult> pay(
    BuildContext context, {
    required String productId,
  }) async {
    final tier      = PaystackService.tiers[productId];
    if (tier == null) {
      return const PaystackPaymentResult(status: PaystackPaymentStatus.failed);
    }

    final reference = PaystackService.generateReference(productId);

    // Paystack requires a valid-format email — we use a placeholder since
    // we don't collect emails. Paystack accepts any format here.
    final email = 'player_${_randomId()}@emojirain.app';

    final charge = Charge()
      ..amount        = tier.amountKobo
      ..currency      = PaystackService.currency
      ..email         = email
      ..reference     = reference
      ..putCustomField('Product', tier.label)
      ..putCustomField('App', 'Emoji Rain: Focus or Fail')
      ..putMetaData('product_id', productId);

    try {
      final response = await _plugin.checkout(
        context,
        charge:     charge,
        method:     CheckoutMethod.selectable, // Card, Bank, USSD — user picks
        fullscreen: false,                     // Bottom sheet style
        logo: Image.asset(
          'assets/images/icon.png',
          width: 40, height: 40,
          errorBuilder: (_, __, ___) =>
              const Text('🎮', style: TextStyle(fontSize: 28)),
        ),
      );

      if (response.status) {
        return PaystackPaymentResult(
          status:    PaystackPaymentStatus.success,
          reference: response.reference,
          productId: productId,
        );
      } else {
        return PaystackPaymentResult(
          status:    PaystackPaymentStatus.failed,
          productId: productId,
        );
      }
    } catch (e) {
      // User dismissed / error
      return PaystackPaymentResult(
        status:    PaystackPaymentStatus.cancelled,
        productId: productId,
      );
    }
  }

  static String _randomId() =>
      Random().nextInt(999999).toString().padLeft(6, '0');
}
