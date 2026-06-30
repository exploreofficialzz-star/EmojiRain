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
  // displayPrice is what the USER SEES on the tier card — shown in USD so it
  // matches the Play Store pricing ($0.99 / $2.99 / $8.99) and reads the same
  // regardless of which payment path a player ends up on.
  //
  // amountKobo / currency are what's ACTUALLY CHARGED — always NGN, since
  // this Paystack account is Nigeria-only (see `currency` above). Paystack's
  // own checkout screen will show the Naira amount (e.g. "₦1,500.00") once
  // the user taps through — that's expected, not a bug. nairaHint is a small
  // secondary label on the tier card so that transition isn't a surprise.
  //
  // If the USD price ever changes, update displayPrice here — amountKobo is
  // independent and won't auto-recalculate from it.
  static const Map<String, PaystackTier> tiers = {
    'emoji_rain_no_ads_day': PaystackTier(
      label:        '1 Day',
      description:  'Perfect for a quick session',
      icon:         '☀️',
      amountKobo:   150000,   // charged amount: ₦1,500
      displayPrice: r'$0.99',
      nairaHint:    '≈₦1,500',
      isBest:       false,
    ),
    'emoji_rain_no_ads_week': PaystackTier(
      label:        '1 Week',
      description:  'Most popular — great value',
      icon:         '🌟',
      amountKobo:   450000,   // charged amount: ₦4,500
      displayPrice: r'$2.99',
      nairaHint:    '≈₦4,500',
      isBest:       true,
    ),
    'emoji_rain_no_ads_month': PaystackTier(
      label:        '1 Month',
      description:  'Best deal for dedicated players',
      icon:         '👑',
      amountKobo:   1350000,  // charged amount: ₦13,500
      displayPrice: r'$8.99',
      nairaHint:    '≈₦13,500',
      isBest:       false,
    ),
  };

  /// Unique reference per transaction.
  /// Format: EMOJIR-NOADS-DAY-1717000000000
  ///
  /// Paystack only allows alphanumeric characters plus `-`, `.`, and `=` in
  /// the `reference` field — underscores are NOT permitted. (This previously
  /// didn't matter because the WebView JS was sending this value under the
  /// wrong parameter name (`ref` instead of `reference`), so Paystack was
  /// silently ignoring it and generating its own reference instead. Now that
  /// the parameter name is fixed and this value actually reaches Paystack,
  /// it has to use only allowed characters.)
  static String generateReference(String productId) {
    final tag       = productId
        .replaceAll('emoji_rain_no_ads_', '')
        .toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'EMOJIR-NOADS-$tag-$timestamp';
  }
}

// ── Tier data class ───────────────────────────────────────────────────────────
class PaystackTier {
  final String label;
  final String description;
  final String icon;
  final int    amountKobo;
  final String displayPrice;
  final String nairaHint;
  final bool   isBest;

  const PaystackTier({
    required this.label,
    required this.description,
    required this.icon,
    required this.amountKobo,
    required this.displayPrice,
    required this.nairaHint,
    required this.isBest,
  });
}
