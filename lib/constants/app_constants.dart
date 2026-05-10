import 'dart:io';
import 'package:flutter/material.dart';

// ─── Brand Colors ────────────────────────────────────────────────────────────
class AppColors {
  static const Color background    = Color(0xFF08081A);
  static const Color surface       = Color(0xFF12122A);
  static const Color surfaceCard   = Color(0xFF1A1A35);
  static const Color primary       = Color(0xFFFFD700);
  static const Color primaryGlow   = Color(0xFFFFAA00);
  static const Color accent        = Color(0xFF00E5FF);
  static const Color accentGlow    = Color(0xFF0099CC);
  static const Color success       = Color(0xFF00E676);
  static const Color error         = Color(0xFFFF1744);
  static const Color warning       = Color(0xFFFF6D00);
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color heartRed      = Color(0xFFFF4081);
  static const Color comboOrange   = Color(0xFFFF6F00);
  static const Color slowMoBlue    = Color(0xFF29B6F6);

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D0D2B), Color(0xFF08081A), Color(0xFF0A0A1F)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
  );

  static const LinearGradient primaryBtnGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFF6F00)],
  );
}

// ─── Text Styles ─────────────────────────────────────────────────────────────
class AppTextStyles {
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle scoreText = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w900,
    color: AppColors.primary,
    letterSpacing: -1,
  );

  static const TextStyle comboText = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: AppColors.comboOrange,
  );
}

// ─── AdMob Unit IDs ──────────────────────────────────────────────────────────
// TODO: Replace with your real AdMob IDs before publishing
class AdIds {
  static bool get _isAndroid => Platform.isAndroid;

  static String get banner => _isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  static String get interstitial => _isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';

  static String get rewarded => _isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';
}

// ─── In-App Purchase Product IDs ─────────────────────────────────────────────
// Create these exact IDs in:
//   Google Play Console → Monetize → In-app products (Consumable)
//   App Store Connect   → Features → In-App Purchases (Consumable)
class IAPIds {
  static const String noAdsDay   = 'emoji_rain_no_ads_day';   // $0.99
  static const String noAdsWeek  = 'emoji_rain_no_ads_week';  // $2.99
  static const String noAdsMonth = 'emoji_rain_no_ads_month'; // $8.99

  static const Set<String> all = {noAdsDay, noAdsWeek, noAdsMonth};

  static const Map<String, Duration> durations = {
    noAdsDay:   Duration(days: 1),
    noAdsWeek:  Duration(days: 7),
    noAdsMonth: Duration(days: 30),
  };

  static const Map<String, String> displayPrices = {
    noAdsDay:   '\$0.99',
    noAdsWeek:  '\$2.99',
    noAdsMonth: '\$8.99',
  };

  static const Map<String, String> displayLabels = {
    noAdsDay:   '1 Day',
    noAdsWeek:  '1 Week',
    noAdsMonth: '1 Month',
  };
}

// ─── Game Constants ───────────────────────────────────────────────────────────
class GameConstants {
  // ── Emoji sizing
  static const double emojiSizeBase  = 82.0;
  static const double emojiSizeLarge = 96.0;
  static const double emojiSizeSmall = 66.0;

  // ── Speed (pixels / second)
  static const double speedBase       = 150.0;
  static const double speedMax        = 3000.0;
  static const double speedIncrement  = 12.0;
  static const double speedGrowthRate = 1.25;

  // ── Spawn
  static const double spawnIntervalBase = 0.50;
  static const double spawnIntervalMin  = 0.16;

  // ── Wrong Tap Lives — player gets 3 chances per session
  // Each wrong tap shows a rewarded ad offer instead of instant game over.
  static const int maxWrongTaps = 3;

  // ── Slow Mo (rewarded ad power-up)
  static const int    slowMoSeconds     = 10;   // how long slow mo lasts
  static const double slowMoFactor      = 0.30; // speed reduced to 30%
  static const int    maxSlowMoPerSession = 2;  // times player can activate

  // ── Combo thresholds
  static const int combo2x  = 5;
  static const int combo3x  = 12;
  static const int combo5x  = 25;
  static const int combo10x = 50;

  // ── Interstitial — after every game over (gated by PurchaseService)
  static const int adEveryNFails = 1;

  // ── Score base per level advance
  static const int scorePerLevel = 300;

  // ── Dense chaos — up to 40 emojis simultaneously
  static const int maxEmojisOnScreen = 40;

  // ── Notification IDs
  static const int notifDailyReminder = 1001;
  static const int notifComeBack      = 1002;
}
