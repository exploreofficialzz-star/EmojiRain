import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'providers/game_provider.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/coin_service.dart';
import 'services/leaderboard_service.dart';
import 'services/network_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/purchase_service.dart';
import 'services/streak_service.dart';
import 'widgets/ad_blocker_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientation ────────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Status bar styling ─────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    statusBarIconBrightness:           Brightness.light,
    systemNavigationBarColor:          AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ── 1. Network ────────────────────────────────────────────────────────────
  await NetworkService.instance.init();

// ── 2. AdMob SDK ─────────────────────────────────────────────────────────
  await MobileAds.instance.initialize();

  // ── Paystack ─────────────────────────────────────────────────────────────
  await PaystackCheckout.initialize();

  // ── 3. IAP ───────────────────────────────────────────────────────────────
  await PurchaseService.instance.init();

  // ── 4. Ads ───────────────────────────────────────────────────────────────
  await AdService.instance.init();

  // ── 5. Audio ─────────────────────────────────────────────────────────────
  await AudioService.instance.init();

  // ── 6. Notifications ─────────────────────────────────────────────────────
  await NotificationService.instance.init();

  // ── 7. Coin wallet ───────────────────────────────────────────────────────
  await CoinService.instance.init();

  // ── 8. Daily streak ──────────────────────────────────────────────────────
  await StreakService.instance.init();

  // ── 9. Leaderboard engine ────────────────────────────────────────────────
  await LeaderboardService.instance.init();

  // ── 10. Player profile ───────────────────────────────────────────────────
  await ProfileService.instance.init();

  runApp(const EmojiRainApp());
}

class EmojiRainApp extends StatelessWidget {
  const EmojiRainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Core game state ───────────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => GameProvider()),

        // ── IAP — drives Remove Ads gating across all screens ─────────────
        ChangeNotifierProvider.value(value: PurchaseService.instance),

        // ── Network — drives NetworkBanner + game pause overlay ────────────
        ChangeNotifierProvider.value(value: NetworkService.instance),

        // ── AdService — drives ad blocker overlay app-wide ────────────────
        ChangeNotifierProvider.value(value: AdService.instance),

        // ── New feature services ──────────────────────────────────────────
        ChangeNotifierProvider.value(value: CoinService.instance),
        ChangeNotifierProvider.value(value: StreakService.instance),
        ChangeNotifierProvider.value(value: LeaderboardService.instance),
        ChangeNotifierProvider.value(value: ProfileService.instance),
      ],
      child: MaterialApp(
        title:                      'Emoji Rain',
        debugShowCheckedModeBanner: false,
        theme:                      _buildTheme(),
        home:                       const HomeScreen(),

        builder: (context, child) {
          return Stack(
            children: [
              child!,
              const AdBlockerOverlay(),
            ],
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3:            true,
      brightness:              Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.primary,
        secondary: AppColors.accent,
        surface:   AppColors.surface,
        error:     AppColors.error,
      ),
      splashColor:    Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
