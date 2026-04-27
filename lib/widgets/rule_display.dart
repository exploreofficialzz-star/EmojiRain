import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';
import '../constants/emoji_data.dart';

class RuleDisplay extends StatelessWidget {
  final LevelConfig level;
  final bool animateIn;
  const RuleDisplay({super.key, required this.level, this.animateIn = false});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.93),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.55), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.12), blurRadius: 12)],
      ),
      child: Text(
        level.instructionText,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: 0.4,
        ),
        textAlign: TextAlign.center,
      ),
    );

    if (!animateIn) return content;
    return content
        .animate()
        .slideY(begin: -0.4, end: 0, duration: 400.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 300.ms);
  }
}

// ─── Level Up Banner ──────────────────────────────────────────────────────────
class LevelUpBanner extends StatelessWidget {
  final int level;
  final String title;
  const LevelUpBanner({super.key, required this.level, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryBtnGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.55), blurRadius: 32, spreadRadius: 6)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 4),
            Text('LEVEL $level', style: const TextStyle(
              fontSize: 34, fontWeight: FontWeight.w900,
              color: Colors.black, letterSpacing: 1,
            )),
            Text(title, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: Colors.black87, letterSpacing: 1.5,
            )),
            const SizedBox(height: 4),
            const Text('SURVIVE 60 SECONDS!', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: Colors.black54, letterSpacing: 1,
            )),
          ],
        ),
      ),
    )
        .animate()
        .scale(begin: const Offset(0.4, 0.4), end: const Offset(1, 1),
            duration: 450.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 200.ms)
        .then(delay: 1800.ms)
        .fadeOut(duration: 400.ms);
  }
}

// ─── Speed Ramp Flash Banner ──────────────────────────────────────────────────
class SpeedUpBanner extends StatelessWidget {
  final int stage;
  const SpeedUpBanner({super.key, required this.stage});

  @override
  Widget build(BuildContext context) {
    final labels = ['', '⚡ SPEED UP!', '⚡⚡ RAPID FIRE!', '💀 MAXIMUM SPEED!'];
    final colors = [Colors.transparent, Colors.lightBlueAccent, Colors.orange, Colors.red];
    final label = labels[stage.clamp(0, 3)];
    final color = colors[stage.clamp(0, 3)];

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20)],
        ),
        child: Text(label, style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: 1,
        )),
      ),
    )
        .animate()
        .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.1, 1.1),
            duration: 200.ms, curve: Curves.easeOut)
        .then()
        .scale(begin: const Offset(1.1, 1.1), end: const Offset(1.0, 1.0),
            duration: 100.ms)
        .fadeIn(duration: 150.ms)
        .then(delay: 1000.ms)
        .fadeOut(duration: 300.ms);
  }
}
