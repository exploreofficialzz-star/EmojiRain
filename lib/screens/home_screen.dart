// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/home_screen.dart — REVISED
//
// CHANGES:
//
// 1. RESPONSIVE SCALING (the "fit all phone screens" fix). The layout was
//    already wrapped in a SingleChildScrollView, so it never technically
//    overflowed/crashed — but on shorter phones (older/budget Android
//    devices in particular), the ~236px of fixed gap spacing plus fixed
//    element sizes (120px logo, 66px button, 72px emoji showcase) pushed
//    the PLAY NOW button — the single most important element on this
//    screen — well past one screenful, requiring real scrolling to reach
//    it. A LayoutBuilder now computes a `scale` factor from the actual
//    available height vs a comfortable reference height (720dp — roughly
//    what a mid-size modern phone offers after status bar/nav bar/banner
//    ad). Phones at or above that reference get the exact original,
//    spacious layout unchanged. Shorter phones get proportionally
//    compressed spacing and element sizes, with floors so nothing shrinks
//    below a legible/tappable minimum. The scroll view stays in place
//    regardless, as a safety net for extreme cases (very short screens,
//    large system font-size accessibility settings, split-screen, etc.).
//
// 2. HORIZONTAL OVERFLOW SAFETY in the fake-stats badges. Their text is
//    dynamically generated (varies in length depending on current time —
//    see _dynamicGamesPlayed / _dynamicSurvivalStat) and was rendered in
//    an unconstrained Row with no wrap/ellipsis fallback. On a narrow
//    device, a longer generated string could overflow the row. Wrapped in
//    Flexible + ellipsis so it gracefully truncates instead.
//
// 3. BACKGROUND BUTTON — the custom-wallpaper feature previously only had
//    an entry point inside the in-game pause menu, with no way to set a
//    background before starting a game at all. Added alongside the sound
//    toggle as a matched pair of secondary utility controls, using the
//    shared showBackgroundPickerSheet() (see widgets/background_picker_
//    sheet.dart) — same sheet the pause menu uses, not a duplicate.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/coin_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../services/streak_service.dart';
import '../widgets/background_picker_sheet.dart';
import '../widgets/daily_reward_modal.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';

// Reference viewport height for the responsive scale factor. Phones with
// at least this much available height get the original, unscaled layout.
const double _kReferenceHeight = 720.0;
const double _kMinScale        = 0.62;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool   _bannerLoaded = false;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    AdService.instance.loadBanner(
      onLoaded: () => mounted ? setState(() => _bannerLoaded = true) : null,
    );

    NotificationService.instance.cancelComeback();

    // Refresh stats every 90 s so numbers shift while user watches
    _statsTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) { if (mounted) setState(() {}); },
    );

    // Feature 3: check daily streak after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDailyStreak());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statsTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDailyStreak() async {
    if (!mounted) return;
    if (StreakService.instance.canClaimToday) {
      await showDailyRewardModal(context);
    }
  }

  void _startGame(BuildContext context) {
    AudioService.instance.play(SoundEffect.tap);
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder:        (_, anim, __) => const GameScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  void _openLeaderboard(BuildContext context) {
    AudioService.instance.play(SoundEffect.tap);
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder:        (_, anim, __) => const LeaderboardScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final game     = context.watch<GameProvider>();
    final purchase = context.watch<PurchaseService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Main scrollable content ────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.bgGradient),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale = (constraints.maxHeight / _kReferenceHeight)
                        .clamp(_kMinScale, 1.0);

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        // On tall screens (content shorter than the
                        // viewport), minHeight + mainAxisAlignment.center
                        // below together center everything vertically
                        // instead of leaving a dead gap at the bottom. On
                        // short screens, min (not max/tight) means content
                        // simply scrolls as needed rather than being forced
                        // to compress below what `scale` already allows.
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 12 * scale),
                            _buildTopBar(context),
                            SizedBox(height: 20 * scale),
                            _buildLogo(scale),
                            SizedBox(height: 28 * scale),
                            _buildEmojiShowcase(scale),
                            SizedBox(height: 24 * scale),
                            _buildHighScore(game),
                            SizedBox(height: 24 * scale),
                            _buildLeaderboardBanner(context),
                            SizedBox(height: 24 * scale),
                            _buildStartButton(context, scale),
                            SizedBox(height: 18 * scale),
                            _buildUtilityRow(context),
                            SizedBox(height: 16 * scale),
                            _buildFakeStats(),
                            SizedBox(height: 24 * scale),
                            _buildByChAs(),
                            SizedBox(height: 20 * scale),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Banner Ad ──────────────────────────────────────────────────
          if (_bannerLoaded &&
              AdService.instance.bannerAd != null &&
              !purchase.adsRemoved)
            Container(
              color:     AppColors.background,
              alignment: Alignment.center,
              width:  AdService.instance.bannerAd!.size.width.toDouble(),
              height: AdService.instance.bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: AdService.instance.bannerAd!),
            ),
        ],
      ),
    );
  }


  // ── Dynamic stat calculations — all driven by current UTC time ────────────
  String get _dynamicGamesPlayed {
    final now         = DateTime.now().toUtc();
    final minsIntoDay = now.hour * 60 + now.minute;
    final fraction    = minsIntoDay / 1440.0;
    final base        = (fraction * (2 - fraction) * 3400000).round();
    final jitter      = ((now.minute ~/ 3) * 11743) % 28000;
    final total       = (base + jitter).clamp(84000, 3400000);
    if (total >= 1000000) return '${(total / 1000000).toStringAsFixed(1)}M';
    return '${(total / 1000).toStringAsFixed(0)}K';
  }

  int get _dynamicAvgScore {
    final seed = DateTime.now().toUtc().minute ~/ 5;
    return 81 + (seed * 13) % 18;
  }

  String get _dynamicSurvivalStat {
    final seed  = DateTime.now().toUtc().minute ~/ 7;
    final pct   = 3 + (seed * 7) % 7;
    final level = 5 + (seed % 2);
    return 'Only $pct% reach level $level';
  }

  // ── Top Bar (Coins + Streak) ───────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Coin balance
          ListenableBuilder(
            listenable: CoinService.instance,
            builder: (_, __) => _CoinBadge(
              balance: CoinService.instance.formattedBalance,
            ),
          ),

          // Daily streak badge
          ListenableBuilder(
            listenable: StreakService.instance,
            builder: (_, __) {
              final streak = StreakService.instance.streak;
              final can    = StreakService.instance.canClaimToday;
              return GestureDetector(
                onTap: can
                    ? () => showDailyRewardModal(context)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: can
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: can
                          ? AppColors.primary.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        can ? '🎁' : '🔥',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        can
                            ? 'Claim!'
                            : streak > 0 ? '${streak}d streak' : 'Daily',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: can
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate(target: can ? 1 : 0)
                  .shimmer(
                    duration: 1200.ms,
                    color: AppColors.primary.withOpacity(0.6),
                  );
            },
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  // ── Leaderboard Teaser Banner ──────────────────────────────────────────────
  Widget _buildLeaderboardBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => _openLeaderboard(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A40),
              AppColors.primary.withOpacity(0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LEADERBOARD',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900,
                      color: AppColors.primary, letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Compete daily · Prizes up to \$50',
                    style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: 550.ms, duration: 500.ms)
          .shimmer(delay: 2500.ms, duration: 1800.ms, color: AppColors.primaryGlow),
    );
  }

  // ── Logo ───────────────────────────────────────────────────────────────────
  Widget _buildLogo(double scale) {
    final logoSize  = (120 * scale).clamp(84.0, 120.0);
    final titleSize = (46  * scale).clamp(32.0, 46.0);

    return Column(
      children: [
        Container(
          width: logoSize, height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.45),
                blurRadius: 36, spreadRadius: 6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/images/icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceCard,
                child: const Text('🎮', style: TextStyle(fontSize: 60)),
              ),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1.0, 1.0),
              end:   const Offset(1.05, 1.05),
              duration: 1600.ms,
              curve: Curves.easeInOut,
            ),

        SizedBox(height: 20 * scale),

        ShaderMask(
          shaderCallback: (b) => AppColors.goldGradient.createShader(b),
          child: Text(
            'EMOJI RAIN',
            style: TextStyle(
              fontSize: titleSize, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: 2,
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms)
            .slideY(begin: 0.3, end: 0, duration: 500.ms),

        SizedBox(height: 6 * scale),

        Text(
          'FOCUS  OR  FAIL',
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.accent.withOpacity(0.9), letterSpacing: 5,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
      ],
    );
  }

  // ── Emoji Showcase ─────────────────────────────────────────────────────────
  Widget _buildEmojiShowcase(double scale) {
    const emojis = ['❤️', '😊', '🤩', '😱', '💀', '🔥', '😎', '🥳', '💎', '👻'];
    final rowHeight = (72 * scale).clamp(56.0, 72.0);
    return SizedBox(
      height: rowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount:       emojis.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(emojis[i], style: const TextStyle(fontSize: 40))
              .animate(
                delay:   Duration(milliseconds: i * 90),
                onPlay: (c) => c.repeat(reverse: true),
              )
              .moveY(
                begin: 0, end: -12,
                duration: Duration(milliseconds: 750 + i * 70),
                curve: Curves.easeInOut,
              ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms);
  }

  // ── High Score ─────────────────────────────────────────────────────────────
  Widget _buildHighScore(GameProvider game) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BEST SCORE',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary, letterSpacing: 2,
                ),
              ),
              Text('${game.highScore}', style: AppTextStyles.scoreText),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.3, end: 0);
  }

  // ── Start Button ───────────────────────────────────────────────────────────
  Widget _buildStartButton(BuildContext context, double scale) {
    final btnHeight = (66 * scale).clamp(54.0, 66.0);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) => Transform.scale(
        scale: 1.0 + _pulseController.value * 0.03,
        child: child,
      ),
      child: GestureDetector(
        onTap: () => _startGame(context),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          height: btnHeight,
          decoration: BoxDecoration(
            gradient: AppColors.primaryBtnGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color:      AppColors.primary.withOpacity(0.50),
                blurRadius: 24, spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎮', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Text(
                'PLAY NOW',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: Colors.black, letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).scale(
          begin: const Offset(0.8, 0.8),
          end:   const Offset(1, 1),
          duration: 500.ms,
          curve: Curves.elasticOut,
        );
  }

  // ── Utility Row: Sound + Background ────────────────────────────────────────
  // Matched pair of secondary controls. Background was previously only
  // reachable from the in-game pause menu — this gives players a way to
  // set it before ever starting a game, using the exact same shared sheet.
  Widget _buildUtilityRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSoundToggle(),
        const SizedBox(width: 20),
        Container(
          width: 1, height: 16,
          color: Colors.white.withOpacity(0.15),
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: () => showBackgroundPickerSheet(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wallpaper_rounded,
                color: AppColors.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Background',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 700.ms, duration: 500.ms);
  }

  // ── Sound Toggle ───────────────────────────────────────────────────────────
  Widget _buildSoundToggle() {
    return StatefulBuilder(
      builder: (context, setState) {
        final on = AudioService.instance.soundEnabled;
        return GestureDetector(
          onTap: () async {
            await AudioService.instance.toggleSound();
            setState(() {});
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: on ? AppColors.accent : AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                on ? 'Sound ON' : 'Sound OFF',
                style: TextStyle(
                  fontSize: 13,
                  color: on ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Fake Stats ─────────────────────────────────────────────────────────────
  Widget _buildFakeStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _statBadge('👥', '$_dynamicGamesPlayed games played today'),
          const SizedBox(height: 8),
          _statBadge('🏆', 'Average score: $_dynamicAvgScore points'),
          const SizedBox(height: 8),
          _statBadge('🔥', _dynamicSurvivalStat),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms, duration: 600.ms);
  }

  Widget _statBadge(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          // FIX: dynamically-generated text (length varies with time of
          // day) could overflow the row on narrow screens with no
          // wrap/ellipsis fallback. Flexible lets it shrink gracefully
          // instead of forcing a hard overflow.
          Flexible(
            child: Text(
              text,
              style:     AppTextStyles.bodyMedium,
              overflow:  TextOverflow.ellipsis,
              maxLines:  1,
            ),
          ),
        ],
      ),
    );
  }

  // ── By ChAs Branding ───────────────────────────────────────────────────────
  Widget _buildByChAs() {
    return Column(
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 60),
          color: Colors.white.withOpacity(0.08),
        ),
        const SizedBox(height: 14),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'by ',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary.withOpacity(0.7),
                  letterSpacing: 1,
                ),
              ),
              const TextSpan(
                text: 'ChAs',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: AppColors.primary, letterSpacing: 2,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 1200.ms, duration: 800.ms)
            .shimmer(
              delay: 2000.ms, duration: 2000.ms,
              color: AppColors.primaryGlow,
            ),
      ],
    );
  }
}

// ── Coin Badge ─────────────────────────────────────────────────────────────────
class _CoinBadge extends StatelessWidget {
  final String balance;
  const _CoinBadge({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            balance,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
