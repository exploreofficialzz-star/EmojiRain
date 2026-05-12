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

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    statusBarIconBrightness:           Brightness.light,
    systemNavigationBarColor:          AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ── Network first — everything else depends on it ──────────────────────────
  await NetworkService.instance.init();

  // ── AdMob ──────────────────────────────────────────────────────────────────
  await MobileAds.instance.initialize();

  // ── IAP — must be ready before AdService checks adsRemoved ────────────────
  await PurchaseService.instance.init();

  // ── Ads ────────────────────────────────────────────────────────────────────
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
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider.value(value: PurchaseService.instance),
        ChangeNotifierProvider.value(value: NetworkService.instance),
        // AdService is ChangeNotifier so the ad blocker overlay reacts to it
        ChangeNotifierProvider.value(value: AdService.instance),
      ],
      child: MaterialApp(
        title:                      'Emoji Rain',
        debugShowCheckedModeBanner: false,
        theme:                      _buildTheme(),
        home:                       const HomeScreen(),
        // App-level builder — places AdBlockerOverlay on top of everything
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              // Ad Blocker overlay sits above every screen — cannot be dismissed
              // until user enables ads or purchases Remove Ads
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
