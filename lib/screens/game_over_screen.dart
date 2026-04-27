import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/notification_service.dart';
import 'game_screen.dart';

class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  bool _bannerLoaded  = false;
  bool _showingAd     = false;
  bool _rewardOffered = false;
  bool _adShown       = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
    _handleAds();
    // Schedule comeback notification
    NotificationService.instance.scheduleComeback(hoursLater: 4);
  }

  void _loadBanner() {
    AdService.instance.loadBanner(
      onLoaded: () => setState(() => _bannerLoaded = true),
    );
  }

  Future<void> _handleAds() async {
    final game = context.read<GameProvider>();

    // Brief delay for dramatic effect then show interstitial
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    if (game.shouldShowInterstitial) {
      game.consumeInterstitialFlag();
      setState(() => _showingAd = true);
      await AdService.instance.showInterstitial(
        onDismissed: () {
          if (mounted) setState(() { _showingAd = false; _adShown = true; });
        },
      );
    } else {
      setState(() => _adShown = true);
    }
  }

  void _retry(BuildContext context) {
    final game = context.read<GameProvider>();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const GameScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    // game.retryGame() is called inside GameScreen.initState via startGame
  }

  void _goHome(BuildContext context) {
    context.read<GameProvider>().goHome();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _watchAdForContinue(BuildContext context) async {
    final game = context.read<GameProvider>();
    final shown = await AdService.instance.showRewarded(
      onRewarded: () {
        game.continueAfterRewardedAd();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, anim, __) => const GameScreen(isContinue: true),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      },
      onDismissed: () {
        if (mounted) setState(() {});
      },
    );
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ad available. Try again shortly.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final isNewHigh = game.score >= game.highScore && game.score > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.bgGradient),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),

                        // ── Fail Emoji ──────────────────────────────────
                        _buildFailEmoji(game.tappedEmoji),

                        const SizedBox(height: 20),

                        // ── Game Over Title ─────────────────────────────
                        _buildTitle(isNewHigh),

                        const SizedBox(height: 16),

                        // ── Fail Message ────────────────────────────────
                        _buildFailMessage(game.failMessage),

                        const SizedBox(height: 28),

                        // ── Score Card ──────────────────────────────────
                        _buildScoreCard(game, isNewHigh),

                        const SizedBox(height: 24),

                        // ── Watch Ad to Continue ────────────────────────
                        if (game.shouldShowRewarded && !_rewardOffered) ...[
                          _buildRewardedButton(context),
                          const SizedBox(height: 12),
                        ],

                        // ── Retry ───────────────────────────────────────
                        _buildRetryButton(context),

                        const SizedBox(height: 12),

                        // ── Home ────────────────────────────────────────
                        _buildHomeButton(context),

                        const SizedBox(height: 16),

                        // ── Fake Stats ──────────────────────────────────
                        _buildFakeStats(game),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Banner Ad ──────────────────────────────────────────────────
          if (_bannerLoaded && AdService.instance.bannerAd != null)
            Container(
              color: AppColors.background,
              width: AdService.instance.bannerAd!.size.width.toDouble(),
              height: AdService.instance.bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: AdService.instance.bannerAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildFailEmoji(String emoji) {
    return Text(
      emoji.isEmpty ? '💀' : emoji,
      style: const TextStyle(fontSize: 80),
    )
        .animate()
        .scale(
          begin: const Offset(0.3, 0.3),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .shake(hz: 5, duration: 500.ms, delay: 600.ms);
  }

  Widget _buildTitle(bool isNewHigh) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => (isNewHigh
                  ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)])
                  : const LinearGradient(
                      colors: [Color(0xFFFF4081), Color(0xFFFF1744)]))
              .createShader(bounds),
          child: Text(
            isNewHigh ? 'NEW RECORD! 🏆' : 'GAME OVER',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildFailMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildScoreCard(GameProvider game, bool isNewHigh) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNewHigh
              ? AppColors.primary.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: isNewHigh ? 2 : 1,
        ),
        boxShadow: isNewHigh
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Main score
          _scoreRow('SCORE', '${game.score}',
              style: AppTextStyles.scoreText),
          const Divider(color: Colors.white12, height: 24),
          // Sub stats
          Row(
            children: [
              Expanded(child: _miniStat('LEVEL', '${game.level}', '🎯')),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(child: _miniStat('BEST', '${game.highScore}', '🏆')),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(child: _miniStat('COMBO', '×${game.maxCombo}', '🔥')),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 400.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 400.ms,
        );
  }

  Widget _scoreRow(String label, String value, {TextStyle? style}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: style ?? AppTextStyles.headlineLarge),
      ],
    );
  }

  Widget _miniStat(String label, String value, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardedButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _rewardOffered = true);
        _watchAdForContinue(context);
      },
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.6), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📺', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WATCH AD TO CONTINUE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Keep your score + 1 life',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 700.ms)
        .shimmer(delay: 1000.ms, duration: 1500.ms, color: AppColors.accent.withOpacity(0.4));
  }

  Widget _buildRetryButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _retry(context),
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: AppColors.primaryBtnGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔄', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Text(
              'TRY AGAIN',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 800.ms, duration: 400.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildHomeButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _goHome(context),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏠', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'HOME',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 900.ms);
  }

  Widget _buildFakeStats(GameProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        game.fakeStat,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    ).animate().fadeIn(delay: 1000.ms);
  }

}
