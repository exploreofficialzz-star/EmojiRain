import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/emoji_item.dart';

class FallingEmojiWidget extends StatelessWidget {
  final EmojiItem emoji;
  final VoidCallback onTap;

  const FallingEmojiWidget({
    super.key,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: emoji.x - emoji.size / 2,
      top:  emoji.y - emoji.size / 2,
      child: _buildEmoji(),
    );
  }

  Widget _buildEmoji() {
    final child = GestureDetector(
      onTap: emoji.isFalling ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Transform.rotate(
        angle: emoji.rotation,
        child: Container(
          width: emoji.size,
          height: emoji.size,
          alignment: Alignment.center,
          decoration: emoji.isTarget
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(emoji.size / 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                )
              : null,
          child: Text(
            emoji.emoji,
            style: TextStyle(
              fontSize: emoji.size * 0.78,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );

    // Tapped: burst then fade
    if (emoji.isTapped) {
      return child
          .animate()
          .scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5),
              duration: 200.ms, curve: Curves.easeOut)
          .fadeOut(begin: 1.0, duration: 200.ms);
    }

    // Missed target: red flash
    if (emoji.isMissed && emoji.isTarget) {
      return child
          .animate()
          .tint(color: Colors.red, duration: 150.ms)
          .fadeOut(duration: 200.ms);
    }

    // Normal falling: subtle entrance
    return child
        .animate()
        .fadeIn(duration: 120.ms)
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1.0, 1.0),
          duration: 150.ms,
          curve: Curves.elasticOut,
        );
  }
}

// ─── Score Popup ──────────────────────────────────────────────────────────────
class ScorePopup extends StatelessWidget {
  final int points;
  final double x;
  final double y;
  final bool isCombo;

  const ScorePopup({
    super.key,
    required this.points,
    required this.x,
    required this.y,
    required this.isCombo,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - 40,
      top:  y - 50,
      child: IgnorePointer(
        child: Text(
          isCombo ? '+$points 🔥' : '+$points',
          style: TextStyle(
            fontSize: isCombo ? 22 : 18,
            fontWeight: FontWeight.w900,
            color: isCombo ? const Color(0xFFFF6F00) : Colors.white,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        )
            .animate()
            .moveY(begin: 0, end: -60, duration: 800.ms, curve: Curves.easeOut)
            .fadeOut(begin: 1.0, delay: 300.ms, duration: 500.ms),
      ),
    );
  }
}
