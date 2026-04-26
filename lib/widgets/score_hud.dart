import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';

class ScoreHUD extends StatelessWidget {
  final GameProvider game;

  const ScoreHUD({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lives
          _LivesRow(lives: game.lives),
          const Spacer(),

          // Score
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
                    end: const Offset(1.0, 1.0),
                    duration: 200.ms,
                    curve: Curves.easeOut,
                  ),
              if (game.combo >= GameConstants.combo2x)
                Text(
                  '${game.comboMultiplier}x COMBO 🔥',
                  style: AppTextStyles.comboText.copyWith(fontSize: 12),
                )
                    .animate()
                    .fadeIn(duration: 150.ms)
                    .shimmer(duration: 1000.ms, color: AppColors.comboOrange),
            ],
          ),
          const Spacer(),

          // Pause button
          GestureDetector(
            onTap: () => game.pauseGame(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: const Icon(Icons.pause_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _LivesRow extends StatelessWidget {
  final int lives;
  const _LivesRow({required this.lives});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(GameConstants.maxLives, (i) {
        final active = i < lives;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            '❤️',
            style: TextStyle(
              fontSize: 18,
              color: active ? null : Colors.grey.withOpacity(0.3),
            ),
          )
              .animate(target: active ? 0 : 1)
              .tint(color: Colors.grey.withOpacity(0.8)),
        );
      }),
    );
  }
}

// ─── Combo Streak Badge ───────────────────────────────────────────────────────
class ComboStreakBadge extends StatelessWidget {
  final int combo;

  const ComboStreakBadge({super.key, required this.combo});

  @override
  Widget build(BuildContext context) {
    if (combo < GameConstants.combo2x) return const SizedBox.shrink();

    String label;
    Color color;
    if (combo >= GameConstants.combo10x) {
      label = '🔥 ${combo}x LEGENDARY';
      color = Colors.purple;
    } else if (combo >= GameConstants.combo5x) {
      label = '⚡ ${combo}x INSANE';
      color = Colors.deepOrange;
    } else if (combo >= GameConstants.combo3x) {
      label = '🔥 ${combo}x ON FIRE';
      color = Colors.orange;
    } else {
      label = '✨ ${combo}x STREAK';
      color = Colors.amber;
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
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    )
        .animate(key: ValueKey(combo ~/ 5))
        .shake(hz: 4, duration: 300.ms)
        .shimmer(duration: 800.ms, color: color.withOpacity(0.8));
  }
}
