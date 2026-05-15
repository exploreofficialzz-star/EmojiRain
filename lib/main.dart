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

  // ── 1. Network first — everything checks this ──────────────────────────────
  await NetworkService.instance.init();

  // ── 2. AdMob SDK ──────────────────────────────────────────────────────────
  await MobileAds.instance.initialize();

  // ── 3. IAP — must be ready before AdService checks adsRemoved ─────────────
  await PurchaseService.instance.init();

  // ── 4. Ads — gated by PurchaseService.adsRemoved ──────────────────────────
  //      Also runs DNS-level ad blocker check in background
  await AdService.instance.init();

  // ── 5. Audio ──────────────────────────────────────────────────────────────
  await AudioService.instance.init();

  // ── 6. Notifications ──────────────────────────────────────────────────────
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

        // IAP — drives Remove Ads gating across all screens
        ChangeNotifierProvider.value(value: PurchaseService.instance),

        // Network — drives NetworkBanner + game pause overlay
        ChangeNotifierProvider.value(value: NetworkService.instance),

        // AdService — drives ad blocker overlay app-wide
        ChangeNotifierProvider.value(value: AdService.instance),
      ],
      child: MaterialApp(
        title:                      'Emoji Rain',
        debugShowCheckedModeBanner: false,
        theme:                      _buildTheme(),
        home:                       const HomeScreen(),

        // ── App-level overlay builder ──────────────────────────────────────
        // AdBlockerOverlay sits on top of everything — covers every screen.
        // Only shown when ads are detected as blocked AND user hasn't
        // purchased Remove Ads.
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
