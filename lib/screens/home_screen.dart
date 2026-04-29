import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _bannerLoaded = false;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startGame(BuildContext context) {
    AudioService.instance.play(SoundEffect.tap);
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => const GameScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Main scrollable content ────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.bgGradient),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      _buildLogo(),
                      const SizedBox(height: 32),
                      _buildEmojiShowcase(),
                      const SizedBox(height: 28),
                      _buildHighScore(game),
                      const SizedBox(height: 36),
                      _buildStartButton(context),
                      const SizedBox(height: 20),
                      _buildSoundToggle(),
                      const SizedBox(height: 16),
                      _buildFakeStats(),
                      const SizedBox(height: 36),
                      // ── "by ChAs" branding ──────────────────────────
                      _buildByChAs(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Banner Ad ─────────────────────────────────────────────────
          if (_bannerLoaded && AdService.instance.bannerAd != null)
            Container(
              color: AppColors.background,
              alignment: Alignment.center,
              width: AdService.instance.bannerAd!.size.width.toDouble(),
              height: AdService.instance.bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: AdService.instance.bannerAd!),
            ),
        ],
      ),
    );
  }

  // ── Logo ───────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Column(
      children: [
        // Game icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.45),
                blurRadius: 36,
                spreadRadius: 6,
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
              end: const Offset(1.05, 1.05),
              duration: 1600.ms,
              curve: Curves.easeInOut,
            ),

        const SizedBox(height: 20),

        // EMOJI RAIN title
        ShaderMask(
          shaderCallback: (b) => AppColors.goldGradient.createShader(b),
          child: const Text(
            'EMOJI RAIN',
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms)
            .slideY(begin: 0.3, end: 0, duration: 500.ms),

        const SizedBox(height: 6),

        Text(
          'FOCUS  OR  FAIL',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.accent.withOpacity(0.9),
            letterSpacing: 5,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
      ],
    );
  }

  // ── Emoji Showcase ─────────────────────────────────────────────────────────
  Widget _buildEmojiShowcase() {
    const emojis = ['❤️', '😊', '🤩', '😱', '💀', '🔥', '😎', '🥳', '💎', '👻'];
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: emojis.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(emojis[i], style: const TextStyle(fontSize: 40))
              .animate(
                delay: Duration(milliseconds: i * 90),
                onPlay: (c) => c.repeat(reverse: true),
              )
              .moveY(
                begin: 0,
                end: -12,
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
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
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
  Widget _buildStartButton(BuildContext context) {
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
          height: 66,
          decoration: BoxDecoration(
            gradient: AppColors.primaryBtnGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.50),
                blurRadius: 24,
                spreadRadius: 2,
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
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: 500.ms,
          curve: Curves.elasticOut,
        );
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
                size: 20,
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
    return Column(
      children: [
        _statBadge('👥', '2.4M games played today'),
        const SizedBox(height: 8),
        _statBadge('🏆', 'Average score: 87 points'),
        const SizedBox(height: 8),
        _statBadge('🔥', 'Only 6% reach level 5'),
      ],
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
          Text(text, style: AppTextStyles.bodyMedium),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary.withOpacity(0.7),
                  letterSpacing: 1,
                ),
              ),
              const TextSpan(
                text: 'ChAs',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 1200.ms, duration: 800.ms)
            .shimmer(delay: 2000.ms, duration: 2000.ms, color: AppColors.primaryGlow),
      ],
    );
  }
}
