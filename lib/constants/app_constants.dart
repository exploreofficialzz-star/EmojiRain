import 'dart:io';
import 'package:flutter/material.dart';

// ─── Brand Colors ────────────────────────────────────────────────────────────
class AppColors {
  static const Color background   = Color(0xFF08081A);
  static const Color surface      = Color(0xFF12122A);
  static const Color surfaceCard  = Color(0xFF1A1A35);
  static const Color primary      = Color(0xFFFFD700);
  static const Color primaryGlow  = Color(0xFFFFAA00);
  static const Color accent       = Color(0xFF00E5FF);
  static const Color accentGlow   = Color(0xFF0099CC);
  static const Color success      = Color(0xFF00E676);
  static const Color error        = Color(0xFFFF1744);
  static const Color warning      = Color(0xFFFF6D00);
  static const Color textPrimary  = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color heartRed     = Color(0xFFFF4081);
  static const Color comboOrange  = Color(0xFFFF6F00);

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
  static const TextStyle displayLarge = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w900,
    color: AppColors.primary,
    letterSpacing: -1,
    height: 1.0,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
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
class AdIds {
  // ⚠️  Replace these with your real AdMob IDs before publishing.
  // These are Google's official TEST IDs — safe to use during development.

  static bool get _isAndroid => Platform.isAndroid;

  // App-level IDs go in AndroidManifest.xml / Info.plist
  // (already set to test IDs in the config files)

  static String get banner => _isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'   // Android test banner
      : 'ca-app-pub-3940256099942544/2934735716';  // iOS test banner

  static String get interstitial => _isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'   // Android test interstitial
      : 'ca-app-pub-3940256099942544/4411468910';  // iOS test interstitial

  static String get rewarded => _isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'   // Android test rewarded
      : 'ca-app-pub-3940256099942544/1712485313';  // iOS test rewarded
}

// ─── Game Constants ───────────────────────────────────────────────────────────
class GameConstants {
  // Emoji sizing
  static const double emojiSizeBase   = 56.0;
  static const double emojiSizeLarge  = 70.0;
  static const double emojiSizeSmall  = 44.0;

  // Speed (pixels per second)
  static const double speedBase    = 160.0;
  static const double speedMax     = 520.0;
  static const double speedIncrement = 18.0;

  // Spawn
  static const double spawnIntervalBase = 1.2;   // seconds
  static const double spawnIntervalMin  = 0.35;  // seconds

  // Lives
  static const int maxLives = 3;

  // Combo thresholds
  static const int combo2x  = 5;
  static const int combo3x  = 15;
  static const int combo5x  = 30;
  static const int combo10x = 60;

  // Interstitial ad every N game-overs
  static const int adEveryNFails = 3;

  // Score to advance level
  static const int scorePerLevel = 150;

  // Max simultaneous emojis on screen
  static const int maxEmojisOnScreen = 14;

  // Duration of visual feedback (ms)
  static const int feedbackDurationMs = 600;

  // Notification IDs
  static const int notifDailyReminder = 1001;
  static const int notifComeBack      = 1002;
}
