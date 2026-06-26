import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/coin_service.dart';

class ScoreHUD extends StatelessWidget {
  final GameProvider game;
  const ScoreHUD({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: Level | Score | Pause ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _LevelBadge(level: game.level),
              const Spacer(),

              // Score + combo
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${game.score}',
                    style: AppTextStyles.scoreText.copyWith(fontSize: 30),
                    key: ValueKey(game.score),
                  )
                      .animate(key: ValueKey(game.score))
                      .scale(
                        begin: const Offset(1.3, 1.3),
                        end:   const Offset(1.0, 1.0),
                        duration: 180.ms,
                        curve: Curves.easeOut,
                      ),
                  if (game.combo >= GameConstants.combo2x)
                    Text(
                      '${game.comboMultiplier}x COMBO 🔥',
                      style: AppTextStyles.comboText.copyWith(fontSize: 12),
                    )
                        .animate()
                        .fadeIn(duration: 150.ms)
                        .shimmer(
                          duration: 900.ms,
                          color: AppColors.comboOrange,
                        ),
                ],
              ),

              const Spacer(),

              // Pause button
              GestureDetector(
                onTap: () => game.pauseGame(),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Icon(
                    Icons.pause_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Row 2: Hearts + Session Coin counter ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Hearts
              _HeartsRow(hearts: game.hearts, maxHearts: game.maxHearts),

              // Session coins earned this game
              ListenableBuilder(
                listenable: CoinService.instance,
                builder: (_, __) => _CoinCounter(sessionCoins: game.sessionCoins),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Hearts Row ────────────────────────────────────────────────────────────────
class _HeartsRow extends StatelessWidget {
  final int hearts;
  final int maxHearts;
  const _HeartsRow({required this.hearts, required this.maxHearts});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxHearts, (i) {
        final filled = i < hearts;
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Text(
            filled ? '❤️' : '🖤',
            style: const TextStyle(fontSize: 16),
          )
              .animate(key: ValueKey('heart_${i}_$filled'))
              .scaleXY(
                begin: filled ? 1.0 : 1.3,
                end:   1.0,
                duration: 300.ms,
                curve: Curves.elasticOut,
              ),
        );
      }),
    );
  }
}

// ── Session Coin Counter ──────────────────────────────────────────────────────
class _CoinCounter extends StatelessWidget {
  final int sessionCoins;
  const _CoinCounter({required this.sessionCoins});

  @override
  Widget build(BuildContext context) {
    if (sessionCoins == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            '+$sessionCoins',
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    )
        .animate(key: ValueKey(sessionCoins))
        .fadeIn(duration: 200.ms);
  }
}

// ── Level Badge ───────────────────────────────────────────────────────────────
class _LevelBadge extends StatelessWidget {
  final int level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color:      AppColors.primary.withOpacity(0.35),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LVL',
            style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: Colors.black87, letterSpacing: 1,
            ),
          ),
          Text(
            '$level',
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: Colors.black, height: 1.0,
            ),
          ),
        ],
      ),
    ).animate(key: ValueKey(level)).scale(
          begin: const Offset(1.4, 1.4),
          end:   const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.elasticOut,
        );
  }
}

// ── Combo Streak Badge ────────────────────────────────────────────────────────
class ComboStreakBadge extends StatelessWidget {
  final int combo;
  const ComboStreakBadge({super.key, required this.combo});

  @override
  Widget build(BuildContext context) {
    if (combo < GameConstants.combo2x) return const SizedBox.shrink();

    String label;
    Color  color;
    if (combo >= GameConstants.combo10x) {
      label = '🔥 ${combo}x LEGENDARY'; color = Colors.purple;
    } else if (combo >= GameConstants.combo5x) {
      label = '⚡ ${combo}x INSANE';     color = Colors.deepOrange;
    } else if (combo >= GameConstants.combo3x) {
      label = '🔥 ${combo}x ON FIRE';   color = Colors.orange;
    } else {
      label = '✨ ${combo}x STREAK';    color = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7), width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w900,
          color: color, letterSpacing: 0.5,
        ),
      ),
    )
        .animate(key: ValueKey(combo ~/ 5))
        .shake(hz: 4, duration: 300.ms)
        .shimmer(duration: 800.ms, color: color.withOpacity(0.8));
  }
}
