// ─────────────────────────────────────────────────────────────────────────────
// PaystackService
//
// SECURITY:
//   ✅  PUBLIC KEY → safe in app code (below)
//   🔴  SECRET KEY → NEVER put in app, ever
//
// Going LIVE: already live — pk_live key is set.
// To add more apps later: use the same public key, change the reference prefix.
// ─────────────────────────────────────────────────────────────────────────────

class PaystackService {
  PaystackService._();
  static final PaystackService instance = PaystackService._();

  // ── Public key only — secret key never belongs here ───────────────────────
  static const String publicKey = 'pk_live_d145dd30b0e40a54e3d2533dfc544e41ea63fe94';

  // ── Currency: NGN for Nigerian Paystack account ───────────────────────────
  // Change to 'USD' if you enable international currency on your dashboard
  static const String currency = 'NGN';

  // ── Payment tiers ─────────────────────────────────────────────────────────
  // Amounts are in KOBO (smallest NGN unit). 1 Naira = 100 Kobo.
  // ₦1,500 = 150,000 kobo | ₦4,500 = 450,000 kobo | ₦13,500 = 1,350,000 kobo
  static const Map<String, PaystackTier> tiers = {
    'emoji_rain_no_ads_day': PaystackTier(
      label:       '1 Day',
      description: 'Perfect for a quick session',
      icon:        '☀️',
      amountKobo:  150000,   // ₦1,500
      displayPrice: '₦1,500',
      isBest:      false,
    ),
    'emoji_rain_no_ads_week': PaystackTier(
      label:       '1 Week',
      description: 'Most popular — great value',
      icon:        '🌟',
      amountKobo:  450000,   // ₦4,500
      displayPrice: '₦4,500',
      isBest:      true,
    ),
    'emoji_rain_no_ads_month': PaystackTier(
      label:       '1 Month',
      description: 'Best deal for dedicated players',
      icon:        '👑',
      amountKobo:  1350000,  // ₦13,500
      displayPrice: '₦13,500',
      isBest:      false,
    ),
  };

  /// Unique reference per transaction.
  /// Format: EMOJIR_NOADS_DAY_1717000000000
  static String generateReference(String productId) {
    final tag       = productId
        .replaceAll('emoji_rain_no_ads_', '')
        .toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'EMOJIR_NOADS_${tag}_$timestamp';
  }
}

// ── Tier data class ───────────────────────────────────────────────────────────
class PaystackTier {
  final String label;
  final String description;
  final String icon;
  final int    amountKobo;
  final String displayPrice;
  final bool   isBest;

  const PaystackTier({
    required this.label,
    required this.description,
    required this.icon,
    required this.amountKobo,
    required this.displayPrice,
    required this.isBest,
  });
}
