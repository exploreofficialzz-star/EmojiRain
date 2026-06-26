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
  static const Color comboOrange   = Color(0xFFFF6F00);
  static const Color heartRed      = Color(0xFFFF1744);

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

  static const LinearGradient heartGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4081), Color(0xFFFF1744)],
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

// ─── Production AdMob IDs ─────────────────────────────────────────────────────
class AdIds {
  static bool get _isAndroid => Platform.isAndroid;

  static String get banner => _isAndroid
      ? 'ca-app-pub-2492078126313994/7350905810'
      : 'ca-app-pub-2492078126313994/7350905810';

  static String get interstitial => _isAndroid
      ? 'ca-app-pub-2492078126313994/4136979727'
      : 'ca-app-pub-2492078126313994/4136979727';

  static String get rewarded => _isAndroid
      ? 'ca-app-pub-2492078126313994/3229873572'
      : 'ca-app-pub-2492078126313994/3229873572';

  static String get rewardedInterstitial =>
      'ca-app-pub-2492078126313994/4729823354';

  static String get native => 'ca-app-pub-2492078126313994/6069008490';
}

// ─── In-App Purchase Product IDs ─────────────────────────────────────────────
class IAPIds {
  // ── Remove Ads (existing) ─────────────────────────────────────────────────
  static const String noAdsDay   = 'emoji_rain_no_ads_day';
  static const String noAdsWeek  = 'emoji_rain_no_ads_week';
  static const String noAdsMonth = 'emoji_rain_no_ads_month';

  // ── Coin Packs (new) — create in Play Console as CONSUMABLE ──────────────
  static const String coinPack100  = 'emoji_rain_coins_100';   // small pack
  static const String coinPack500  = 'emoji_rain_coins_500';   // medium pack
  static const String coinPack1500 = 'emoji_rain_coins_1500';  // best value

  static const Set<String> all = {
    noAdsDay, noAdsWeek, noAdsMonth,
    coinPack100, coinPack500, coinPack1500,
  };

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
  // ── Emoji / Speed ─────────────────────────────────────────────────────────
  static const double emojiSizeBase     = 82.0;
  static const double emojiSizeLarge    = 96.0;
  static const double emojiSizeSmall    = 66.0;
  static const double speedBase         = 150.0;
  static const double speedMax          = 3000.0;
  static const double speedIncrement    = 12.0;
  static const double speedGrowthRate   = 1.25;
  static const double spawnIntervalBase = 0.50;
  static const double spawnIntervalMin  = 0.16;

  // ── Combo thresholds ──────────────────────────────────────────────────────
  static const int combo2x  = 5;
  static const int combo3x  = 12;
  static const int combo5x  = 25;
  static const int combo10x = 50;

  // ── Ads ───────────────────────────────────────────────────────────────────
  static const int adEveryNFails     = 1;
  static const int maxEmojisOnScreen = 40;

  // ── Notifications ─────────────────────────────────────────────────────────
  static const int notifDailyReminder = 1001;
  static const int notifComeBack      = 1002;

  // ── Hearts / Lives (Feature 1) ────────────────────────────────────────────
  static const int maxHearts = 3;

  // ── Coins earned per game event (Feature 2) ───────────────────────────────
  // Per correct tap: comboMultiplier × coinsPerTap  (min 1, max 10 coins/tap)
  static const int coinsPerTap      = 1;
  static const int coinsPerLevelUp  = 25;   // × level number
  static const int coinsNewHighScore = 100; // one-time bonus

  // ── Power-Up coin costs (Feature 4) ──────────────────────────────────────
  static const int slowMoCost    = 100;
  static const int shieldCost    = 150;
  static const int clearWaveCost = 200;

  // ── Power-Up durations ────────────────────────────────────────────────────
  static const Duration slowMoDuration = Duration(seconds: 5);
  static const double  slowMoFactor    = 0.30; // 30% of normal speed
}

// ─── Support ──────────────────────────────────────────────────────────────────
class AppSupport {
  static const String email = 'chastechnologiesllc@gmail.com';
}
