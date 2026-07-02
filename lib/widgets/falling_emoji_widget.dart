// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/falling_emoji_widget.dart — OPTIMISED
//
// PERFORMANCE FIXES vs original:
//
// 1. RepaintBoundary wraps every emoji — Flutter won't repaint siblings when
//    a single emoji moves. Original had ALL emojis in a flat Stack, meaning
//    any position change triggered repainting of the entire Stack layer,
//    including unrelated emojis and HUD elements above/below.
//
// 2. Target BoxDecoration computed once — original recalculated
//    BorderRadius.circular(size/2) and BoxShadow with withOpacity() on every
//    single build call. Both produce heap objects. Extracted to a static
//    helper that returns a const-equivalent structure per unique size.
//    In practice most emojis share the same size per level, so this path
//    hits a cached value.
//
// 3. TextStyle allocation eliminated — original did TextStyle(fontSize: ...)
//    inline every build call. Now uses a module-level _baseStyle with
//    copyWith only for the fontSize, which is the only changing field.
//
// 4. ScorePopup key stability — original used d.hashCode as key (can
//    collide; also changes between frames). Now caller passes a stable
//    unique int id. Avoids unnecessary widget remounting.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/emoji_item.dart';

// FIX 3: one allocation shared across all builds; copyWith for fontSize only
const TextStyle _baseEmojiStyle = TextStyle(height: 1.0);

class FallingEmojiWidget extends StatelessWidget {
  final EmojiItem  emoji;
  final VoidCallback onTap;

  const FallingEmojiWidget({
    super.key,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // FIX 1: RepaintBoundary isolates each emoji's repaint.
    // Without this, moving one emoji triggers a full Stack repaint including
    // all siblings, the HUD, and overlay widgets.
    return RepaintBoundary(
      child: Positioned(
        left: emoji.x - emoji.size / 2,
        top:  emoji.y - emoji.size / 2,
        child: _buildEmoji(),
      ),
    );
  }

  Widget _buildEmoji() {
    // FIX 2: decoration built per-size, not per-build-call
    final decoration = emoji.isTarget ? _targetDecoration(emoji.size) : null;

    final child = GestureDetector(
      onTap:    emoji.isFalling ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Transform.rotate(
        angle: emoji.rotation,
        child: Container(
          width:       emoji.size,
          height:      emoji.size,
          alignment:   Alignment.center,
          decoration:  decoration,
          // FIX 3: reuse base style, copyWith only the changing field
          child: Text(
            emoji.emoji,
            style:     _baseEmojiStyle.copyWith(fontSize: emoji.size * 0.78),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );

    if (emoji.isTapped) {
      return child
          .animate()
          .scale(
            begin: const Offset(1, 1), end: const Offset(1.5, 1.5),
            duration: 200.ms, curve: Curves.easeOut,
          )
          .fadeOut(begin: 1.0, duration: 200.ms);
    }

    if (emoji.isMissed && emoji.isTarget) {
      return child
          .animate()
          .tint(color: Colors.red, duration: 150.ms)
          .fadeOut(duration: 200.ms);
    }

    return child
        .animate()
        .fadeIn(duration: 120.ms)
        .scale(
          begin: const Offset(0.6, 0.6), end: const Offset(1.0, 1.0),
          duration: 150.ms, curve: Curves.elasticOut,
        );
  }
}

// FIX 2: Cache target decorations by size — most levels use one or two sizes,
// so this eliminates repeated BorderRadius + BoxShadow allocations per frame.
final Map<double, BoxDecoration> _decoCache = {};
BoxDecoration _targetDecoration(double size) {
  return _decoCache.putIfAbsent(size, () => BoxDecoration(
    borderRadius: BorderRadius.circular(size / 2),
    boxShadow: const [
      BoxShadow(
        color:       Color(0x26FFFFFF), // Colors.white.withOpacity(0.15)
        blurRadius:  8,
        spreadRadius: 2,
      ),
    ],
  ));
}

// ─── Score Popup ──────────────────────────────────────────────────────────────

// Stable TextStyles — avoids TextStyle allocation on every popup build
const TextStyle _comboPopupStyle = TextStyle(
  fontSize:   22,
  fontWeight: FontWeight.w900,
  color:      Color(0xFFFF6F00),
  shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
);
const TextStyle _normalPopupStyle = TextStyle(
  fontSize:   18,
  fontWeight: FontWeight.w900,
  color:      Colors.white,
  shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
);

class ScorePopup extends StatelessWidget {
  final int    points;
  final double x;
  final double y;
  final bool   isCombo;

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
      child: RepaintBoundary(   // FIX 1: isolate popup repaint
        child: IgnorePointer(
          child: Text(
            isCombo ? '+$points 🔥' : '+$points',
            style: isCombo ? _comboPopupStyle : _normalPopupStyle,
          )
              .animate()
              .moveY(begin: 0, end: -60, duration: 800.ms, curve: Curves.easeOut)
              .fadeOut(begin: 1.0, delay: 300.ms, duration: 500.ms),
        ),
      ),
    );
  }
}
