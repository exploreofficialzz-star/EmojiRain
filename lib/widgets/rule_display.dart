import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';
import '../constants/emoji_data.dart';

class RuleDisplay extends StatelessWidget {
  final LevelConfig level;
  final bool animateIn;

  const RuleDisplay({
    super.key,
    required this.level,
    this.animateIn = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'LVL ${level.level}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              level.instructionText,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (!animateIn) return content;

    return content
        .animate()
        .slideY(begin: -0.3, end: 0, duration: 400.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 300.ms);
  }
}

// ─── Level Up Banner ──────────────────────────────────────────────────────────
class LevelUpBanner extends StatelessWidget {
  final int level;

  const LevelUpBanner({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryBtnGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.5),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 4),
            Text(
              'LEVEL $level',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 1,
              ),
            ),
            const Text(
              'UNLOCKED!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1),
            duration: 400.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 200.ms)
        .then(delay: 1200.ms)
        .fadeOut(duration: 400.ms);
  }
}
