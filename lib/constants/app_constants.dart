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
class AdIds {
  // ⚠️  Replace with your real AdMob IDs before publishing.
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

// ─── Game Constants ───────────────────────────────────────────────────────────
class GameConstants {
  // ── Emoji sizing — BIG, impactful, tappable
  static const double emojiSizeBase  = 82.0;
  static const double emojiSizeLarge = 96.0;
  static const double emojiSizeSmall = 66.0;

  // ── Speed (pixels / second)
  static const double speedBase       = 130.0;
  static const double speedMax        = 460.0;
  static const double speedIncrement  = 12.0;
  // ── Continuous speed growth: +5.0 px/s every second throughout the game
  static const double speedGrowthRate = 5.0;

  // ── Spawn — fast and chaotic
  static const double spawnIntervalBase = 0.50;
  static const double spawnIntervalMin  = 0.16;

  // ── NO lives. Wrong tap OR missing a target = INSTANT GAME OVER.
  static const int maxLives = 1;

  // ── Combo thresholds
  static const int combo2x  = 5;
  static const int combo3x  = 12;
  static const int combo5x  = 25;
  static const int combo10x = 50;

  // ── Interstitial after EVERY game over
  static const int adEveryNFails = 1;

  // ── Score base per level advance
  static const int scorePerLevel = 300;

  // ── Dense chaos — up to 28 emojis simultaneously
  static const int maxEmojisOnScreen = 28;

  // ── Notification IDs
  static const int notifDailyReminder = 1001;
  static const int notifComeBack      = 1002;
}
