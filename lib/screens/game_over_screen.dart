import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../widgets/network_banner.dart';
import '../widgets/remove_ads_sheet.dart';
import 'game_screen.dart';

class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  bool _bannerLoaded = false;
  bool _showingAd    = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
    _handleInterstitial();
    NotificationService.instance.scheduleComeback(hoursLater: 4);
  }

  void _loadBanner() {
    // AdService already gates behind adsRemoved + network internally
    AdService.instance.loadBanner(
      onLoaded: () {
        if (mounted) setState(() => _bannerLoaded = true);
      },
    );
  }

  Future<void> _handleInterstitial() async {
    final game = context.read<GameProvider>();
    if (!game.shouldShowInterstitial) return;

    game.consumeInterstitialFlag();

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() => _showingAd = true);
    await AdService.instance.showInterstitial(
      onComplete: () {
        if (mounted) setState(() => _showingAd = false);
      },
    );
  }

  void _retry(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:       (_, anim, __) => const GameScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _goHome(BuildContext context) {
    context.read<GameProvider>().goHome();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final game     = context.watch<GameProvider>();
    final purchase = context.watch<PurchaseService>();
    final isNewHigh = game.score >= game.highScore && game.score > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Container(
                  decoration:
                      const BoxDecoration(gradient: AppColors.bgGradient),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 32),

                            // ── Fail emoji ──────────────────────────────
                            _buildFailEmoji(game.tappedEmoji),
                            const SizedBox(height: 20),

                            // ── Title ────────────────────────────────────
                            _buildTitle(isNewHigh),
                            const SizedBox(height: 16),

                            // ── Fail message ─────────────────────────────
                            _buildFailMessage(game.failMessage),
                            const SizedBox(height: 28),

                            // ── Score card ───────────────────────────────
                            _buildScoreCard(game, isNewHigh),
                            const SizedBox(height: 24),

                            // ── Remove Ads banner ────────────────────────
                            if (!purchase.adsRemoved) ...[
                              _buildRemoveAdsBanner(context),
                              const SizedBox(height: 16),
                            ],

                            // ── Active status if purchased ───────────────
                            if (purchase.adsRemoved) ...[
                              _buildAdsRemovedStatus(purchase),
                              const SizedBox(height: 16),
                            ],

                            // ── Retry ─────────────────────────────────────
                            _buildRetryButton(context),
                            const SizedBox(height: 12),

                            // ── Home ──────────────────────────────────────
                            _buildHomeButton(context),
                            const SizedBox(height: 16),

                            // ── Fake stat ──────────────────────────────────
                            _buildFakeStat(game),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Banner Ad ─────────────────────────────────────────────
              if (_bannerLoaded &&
                  AdService.instance.bannerAd != null &&
                  !purchase.adsRemoved)
                Container(
                  color:     AppColors.background,
                  alignment: Alignment.center,
                  width: AdService.instance.bannerAd!.size.width.toDouble(),
                  height: AdService.instance.bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: AdService.instance.bannerAd!),
                ),
            ],
          ),

          // ── Network banner (floats at top) ─────────────────────────────
          const NetworkBanner(),
        ],
      ),
    );
  }

  // ── Remove Ads promo banner ───────────────────────────────────────────────
  Widget _buildRemoveAdsBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => showRemoveAdsSheet(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.35), width: 1.2),
        ),
        child: Row(
          children: [
            const Text('🚫📺', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remove Ads',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w800,
                      color:      AppColors.primary,
                    ),
                  ),
                  Text(
                    'From \$0.99/day — play without interruptions',
                    style: TextStyle(
                      fontSize: 12,
                      color:    AppColors.textSecondary,
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
      ),
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 400.ms)
        .shimmer(
            delay:    1200.ms,
            duration: 2000.ms,
            color:    AppColors.primary.withOpacity(0.25));
  }

  Widget _buildAdsRemovedStatus(PurchaseService purchase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.success.withOpacity(0.30), width: 1),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(
            purchase.statusLabel,
            style: const TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w700,
              color:      AppColors.success,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 700.ms);
  }

  // ── Standard widgets ──────────────────────────────────────────────────────
  Widget _buildFailEmoji(String emoji) {
    return Text(
      emoji.isEmpty ? '💀' : emoji,
      style: const TextStyle(fontSize: 80),
    )
        .animate()
        .scale(
          begin: const Offset(0.3, 0.3),
          end:   const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .shake(hz: 5, duration: 500.ms, delay: 600.ms);
  }

  Widget _buildTitle(bool isNewHigh) {
    return ShaderMask(
      shaderCallback: (bounds) => (isNewHigh
              ? const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)])
              : const LinearGradient(
                  colors: [Color(0xFFFF4081), Color(0xFFFF1744)]))
          .createShader(bounds),
      child: Text(
        isNewHigh ? 'NEW RECORD! 🏆' : 'GAME OVER',
        style: const TextStyle(
          fontSize:      36,
          fontWeight:    FontWeight.w900,
          color:         Colors.white,
          letterSpacing: 1.5,
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildFailMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color:        AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize:   16,
          fontWeight: FontWeight.w600,
          color:      AppColors.textPrimary,
          height:     1.4,
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
        color:        AppColors.surfaceCard,
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
                  color:      AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          _scoreRow('SCORE', '${game.score}', style: AppTextStyles.scoreText),
          const Divider(color: Colors.white12, height: 24),
          Row(
            children: [
              Expanded(child: _miniStat('LEVEL',  '${game.level}',    '🎯')),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(child: _miniStat('BEST',   '${game.highScore}','🏆')),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(child: _miniStat('COMBO',  '×${game.maxCombo}','🔥')),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 400.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end:   const Offset(1.0, 1.0),
          duration: 400.ms,
        );
  }

  Widget _scoreRow(String label, String value, {TextStyle? style}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize:      11,
            fontWeight:    FontWeight.w700,
            color:         AppColors.textSecondary,
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
            fontSize:   18,
            fontWeight: FontWeight.w900,
            color:      AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize:      10,
            color:         AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _retry(context),
      child: Container(
        width:  double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient:     AppColors.primaryBtnGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:      AppColors.primary.withOpacity(0.4),
              blurRadius: 16,
              offset:     const Offset(0, 6),
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
                fontSize:      18,
                fontWeight:    FontWeight.w900,
                color:         Colors.black,
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
          end:   const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildHomeButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _goHome(context),
      child: Container(
        width:  double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color:        AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏠', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'HOME',
              style: TextStyle(
                fontSize:      15,
                fontWeight:    FontWeight.w700,
                color:         AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 900.ms);
  }

  Widget _buildFakeStat(GameProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        game.fakeStat,
        style: const TextStyle(
          fontSize:   13,
          color:      AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    ).animate().fadeIn(delay: 1000.ms);
  }
}
