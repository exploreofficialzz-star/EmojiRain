import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/network_service.dart';

class WrongTapOverlay extends StatefulWidget {
  const WrongTapOverlay({super.key});

  @override
  State<WrongTapOverlay> createState() => _WrongTapOverlayState();
}

class _WrongTapOverlayState extends State<WrongTapOverlay> {
  static const int _countdownSeconds = 10;

  int    _secondsLeft = _countdownSeconds;
  bool   _loadingAd  = false;
  String _adError    = '';
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _secondsLeft = _countdownSeconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _countdown?.cancel();
        _giveUp();
      }
    });
  }

  Future<void> _watchAd() async {
    final net = NetworkService.instance;
    if (net.isOffline) {
      setState(() => _adError = net.shortMessage);
      return;
    }

    if (!AdService.instance.rewardedReady) {
      setState(() => _adError = 'Ad not ready yet. Try again in a moment.');
      return;
    }

    _countdown?.cancel();
    setState(() {
      _loadingAd = true;
      _adError   = '';
    });

    await AdService.instance.showRewarded(
      onRewarded: () {
        if (mounted) {
          context.read<GameProvider>().continueAfterWrongTap();
        }
      },
      onSkipped: () {
        // User closed the ad before earning reward — resume countdown
        if (mounted) {
          setState(() { _loadingAd = false; _adError = ''; });
          _startCountdown();
        }
      },
      onUnavailable: () {
        if (mounted) {
          setState(() {
            _loadingAd = false;
            _adError   = 'Ad unavailable. Try again or give up.';
          });
          _startCountdown();
        }
      },
    );
  }

  void _giveUp() {
    _countdown?.cancel();
    if (mounted) {
      context.read<GameProvider>().declineWrongTapContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();

    // How many lives are left AFTER this wrong tap is resolved
    final livesAfter  = game.continuesLeft - 1;
    final continueNum = GameConstants.maxWrongTaps - game.continuesLeft + 1;

    return Container(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Wrong emoji ─────────────────────────────────────────────
              _buildWrongEmoji(game.tappedEmoji),
              const SizedBox(height: 16),

              // ── "Wrong tap!" ─────────────────────────────────────────────
              const Text(
                'Wrong Tap!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ).animate().shakeX(duration: 400.ms),
              const SizedBox(height: 6),

              // ── Fail message ─────────────────────────────────────────────
              Text(
                game.failMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFB0BEC5),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // ── Lives remaining ──────────────────────────────────────────
              _buildLivesRow(
                continueNum: continueNum,
                livesAfter:  livesAfter,
              ),
              const SizedBox(height: 28),

              // ── Countdown ring ───────────────────────────────────────────
              _buildCountdownRing(),
              const SizedBox(height: 28),

              // ── Error message ────────────────────────────────────────────
              if (_adError.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⚠️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _adError,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFEF9A9A),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Watch Ad button ──────────────────────────────────────────
              _buildWatchAdButton(),
              const SizedBox(height: 12),

              // ── Give Up button ───────────────────────────────────────────
              _buildGiveUpButton(),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildWrongEmoji(String emoji) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFB71C1C).withOpacity(0.2),
            border: Border.all(
                color: const Color(0xFFEF5350).withOpacity(0.5), width: 2),
          ),
        ),
        Text(
          emoji.isEmpty ? '❓' : emoji,
          style: const TextStyle(fontSize: 52),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFB71C1C),
            ),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 18),
          ),
        ),
      ],
    )
        .animate()
        .scale(
          begin: const Offset(0.3, 0.3),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildLivesRow({
    required int continueNum,
    required int livesAfter,
  }) {
    return Column(
      children: [
        Text(
          'Continue $continueNum of ${GameConstants.maxWrongTaps}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF78909C),
            letterSpacing: 1.5,
            textBaseline: TextBaseline.alphabetic,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(GameConstants.maxWrongTaps, (i) {
            // Hearts after this tap: livesAfter remaining full hearts
            // (maxWrongTaps - 1 - i) counts from right
            final isActive = i < livesAfter;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isActive ? '❤️' : '🖤',
                style: const TextStyle(fontSize: 26),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          livesAfter == 0
              ? 'Last chance — no more continues!'
              : '$livesAfter continue${livesAfter == 1 ? '' : 's'} remaining after this',
          style: TextStyle(
            fontSize: 12,
            color: livesAfter == 0
                ? const Color(0xFFEF5350)
                : const Color(0xFF78909C),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownRing() {
    final progress = _secondsLeft / _countdownSeconds;
    final isUrgent = _secondsLeft <= 3;

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              isUrgent ? const Color(0xFFEF5350) : AppColors.primary,
            ),
          ),
          Text(
            '$_secondsLeft',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isUrgent ? const Color(0xFFEF5350) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchAdButton() {
    final isOffline = NetworkService.instance.isOffline;

    return GestureDetector(
      onTap: _loadingAd || isOffline ? null : _watchAd,
      child: AnimatedOpacity(
        opacity: _loadingAd || isOffline ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFF6F00)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _loadingAd
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📺', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WATCH AD — CONTINUE FREE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          isOffline
                              ? '⚠️ Offline — no ads available'
                              : 'Keep your score and keep going',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    )
        .animate(key: const ValueKey('watchBtn'))
        .shimmer(delay: 600.ms, duration: 1800.ms,
            color: Colors.white.withOpacity(0.35));
  }

  Widget _buildGiveUpButton() {
    return GestureDetector(
      onTap: _giveUp,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('💀', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text(
              'Give Up',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF78909C),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
