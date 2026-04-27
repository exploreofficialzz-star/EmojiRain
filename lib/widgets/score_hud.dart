import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';

// ─── Top HUD ─────────────────────────────────────────────────────────────────
class ScoreHUD extends StatelessWidget {
  final GameProvider game;
  const ScoreHUD({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Level badge ──────────────────────────────────────────────────
          _LevelBadge(level: game.level),
          const SizedBox(width: 10),

          // ── Countdown timer ──────────────────────────────────────────────
          _CountdownTimer(secsRemaining: game.levelSecsRemaining),

          const Spacer(),

          // ── Score + combo ─────────────────────────────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${game.score}',
                style: AppTextStyles.scoreText.copyWith(fontSize: 28),
                key: ValueKey(game.score),
              )
                  .animate(key: ValueKey(game.score))
                  .scale(
                    begin: const Offset(1.3, 1.3),
                    end: const Offset(1.0, 1.0),
                    duration: 160.ms,
                    curve: Curves.easeOut,
                  ),
              if (game.combo >= GameConstants.combo2x)
                Text(
                  '${game.comboMultiplier}x COMBO 🔥',
                  style: AppTextStyles.comboText.copyWith(fontSize: 11),
                )
                    .animate()
                    .fadeIn(duration: 150.ms)
                    .shimmer(duration: 900.ms, color: AppColors.comboOrange),
            ],
          ),
          const SizedBox(width: 10),

          // ── Pause ─────────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => game.pauseGame(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withOpacity(0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: const Icon(Icons.pause_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Level Badge ──────────────────────────────────────────────────────────────
class _LevelBadge extends StatelessWidget {
  final int level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('LVL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1)),
          Text('$level', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black, height: 1.0)),
        ],
      ),
    ).animate(key: ValueKey(level)).scale(
          begin: const Offset(1.5, 1.5), end: const Offset(1.0, 1.0),
          duration: 400.ms, curve: Curves.elasticOut,
        );
  }
}

// ─── Countdown Timer ─────────────────────────────────────────────────────────
class _CountdownTimer extends StatelessWidget {
  final int secsRemaining;
  const _CountdownTimer({required this.secsRemaining});

  @override
  Widget build(BuildContext context) {
    // Colour shifts: green → orange → red as time runs out
    Color barColor;
    if (secsRemaining > 30) {
      barColor = AppColors.timerGreen;
    } else if (secsRemaining > 15) {
      barColor = AppColors.timerOrange;
    } else {
      barColor = AppColors.timerRed;
    }

    final fraction = (secsRemaining / GameConstants.levelDurationSecs).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time text
        Row(
          children: [
            Icon(Icons.timer_rounded, size: 11, color: barColor),
            const SizedBox(width: 3),
            Text(
              '${secsRemaining}s',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        // Progress bar
        Container(
          width: 72,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: barColor.withOpacity(0.6), blurRadius: 4)],
              ),
            ),
          ),
        ),
      ],
    )
        // Pulse when < 10 seconds
        .animate(target: secsRemaining <= 10 ? 1 : 0)
        .shimmer(duration: 600.ms, color: AppColors.timerRed.withOpacity(0.6));
  }
}

// ─── Combo Streak Badge ───────────────────────────────────────────────────────
class ComboStreakBadge extends StatelessWidget {
  final int combo;
  const ComboStreakBadge({super.key, required this.combo});

  @override
  Widget build(BuildContext context) {
    if (combo < GameConstants.combo2x) return const SizedBox.shrink();

    final (label, color) = switch (true) {
      _ when combo >= GameConstants.combo10x => ('🔥 ${combo}x LEGENDARY', Colors.purple),
      _ when combo >= GameConstants.combo5x  => ('⚡ ${combo}x INSANE', Colors.deepOrange),
      _ when combo >= GameConstants.combo3x  => ('🔥 ${combo}x ON FIRE', Colors.orange),
      _                                      => ('✨ ${combo}x STREAK', Colors.amber),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7), width: 1.5),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w900,
        color: color, letterSpacing: 0.5,
      )),
    )
        .animate(key: ValueKey(combo ~/ 5))
        .shake(hz: 4, duration: 300.ms)
        .shimmer(duration: 800.ms, color: color.withOpacity(0.8));
  }
}

// ─── Speed Stage Indicator ────────────────────────────────────────────────────
class SpeedStageIndicator extends StatelessWidget {
  final int stage;
  const SpeedStageIndicator({super.key, required this.stage});

  @override
  Widget build(BuildContext context) {
    if (stage == 0) return const SizedBox.shrink();

    final labels = ['', '⚡ FASTER', '⚡⚡ RAPID', '⚡⚡⚡ INSANE'];
    final colors = [Colors.transparent, Colors.lightBlueAccent, Colors.orange, Colors.red];
    final label = labels[stage.clamp(0, 3)];
    final color = colors[stage.clamp(0, 3)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w900, color: color,
      )),
    )
        .animate(key: ValueKey(stage))
        .fadeIn(duration: 300.ms)
        .shake(hz: 5, duration: 500.ms)
        .shimmer(duration: 1000.ms, color: color.withOpacity(0.7));
  }
}
