import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'providers/game_provider.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/network_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Portrait lock ──────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Status bar styling ─────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:                    Colors.transparent,
      statusBarIconBrightness:           Brightness.light,
      systemNavigationBarColor:          AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // ── Network — init first so all subsequent services can check status ───────
  await NetworkService.instance.init();

  // ── AdMob ──────────────────────────────────────────────────────────────────
  await MobileAds.instance.initialize();

  // ── In-App Purchases — must init before AdService so adsRemoved is known ──
  await PurchaseService.instance.init();

  // ── Ads — gated by PurchaseService.adsRemoved + NetworkService.isOnline ───
  AdService.instance.init();

  // ── Audio ──────────────────────────────────────────────────────────────────
  await AudioService.instance.init();

  // ── Notifications ──────────────────────────────────────────────────────────
  await NotificationService.instance.init();

  runApp(const EmojiRainApp());
}

class EmojiRainApp extends StatelessWidget {
  const EmojiRainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Game state
        ChangeNotifierProvider(create: (_) => GameProvider()),

        // In-App Purchase state — drives Remove Ads gating across all screens
        ChangeNotifierProvider.value(value: PurchaseService.instance),

        // Network state — drives NetworkBanner across all screens
        ChangeNotifierProvider.value(value: NetworkService.instance),
      ],
      child: MaterialApp(
        title:                      'Emoji Rain',
        debugShowCheckedModeBanner: false,
        theme:                      _buildTheme(),
        home:                       const HomeScreen(),
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
      fontFamily:    'Roboto',
      textTheme: const TextTheme(
        headlineLarge: AppTextStyles.headlineLarge,
        bodyMedium:    AppTextStyles.bodyMedium,
      ),
      splashColor:    Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
