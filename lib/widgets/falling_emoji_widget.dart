// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/falling_emoji_widget.dart — REVISED
//
// FIX (rendering bug): this widget used to wrap its content in its OWN
// `Positioned`, but every caller (see _EmojiLayer in game_screen.dart)
// already wraps FallingEmojiWidget in an OUTER `Positioned` to place it in
// the Stack. That meant every emoji had TWO nested Positioned widgets, and
// the inner one had no direct Stack ancestor — an invalid ParentDataWidget
// usage that Flutter's own docs call out as a hard "Incorrect use of
// ParentDataWidget" error in debug builds, and silently gets its position
// data ignored in release/profile builds (assertions stripped). This widget
// now returns its raw content only; the outer Positioned in _EmojiLayer is
// the single source of truth for where each emoji sits.
//
// FIX (over-layering): RepaintBoundary was applied to EVERY individual
// emoji and EVERY score popup — with up to 15 emojis + several popups on
// screen at once, that's ~20 simultaneous GPU compositing layers for a
// simple 2D scene. Each RepaintBoundary is a real cost (a separate offscreen
// layer Android's renderer must allocate and composite), and since every
// falling emoji repaints constantly anyway (it's moving every frame), the
// isolation benefit per-emoji is much smaller than the layer-management
// overhead of maintaining ~20 of them concurrently. RepaintBoundary is now
// applied ONCE around the whole emoji layer and ONCE around the effects
// layer (see game_screen.dart's _EmojiLayer / _EffectLayer) instead of
// once per widget — same isolation from the static HUD, far fewer layers.
//
// OTHER FIXES (unchanged from previous revision):
// 1. Target BoxDecoration computed once — original recalculated
//    BorderRadius.circular(size/2) and BoxShadow with withOpacity() on every
//    single build call. Cached per unique size instead.
// 2. TextStyle allocation eliminated — module-level _baseStyle with
//    copyWith only for the fontSize, which is the only changing field.
// 3. ScorePopup key stability — caller passes a stable unique key rather
//    than relying on hashCode.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/emoji_item.dart';

// One allocation shared across all builds; copyWith for fontSize only
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
    // No Positioned/RepaintBoundary here — the caller (_EmojiLayer) already
    // wraps this widget in the ONE Positioned that actually matters, and
    // RepaintBoundary is applied once at the layer level instead of here.
    return _buildEmoji();
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
    // RepaintBoundary removed here — consolidated to one layer around the
    // whole effects region in _EffectLayer (game_screen.dart) instead of
    // one per popup. Positioned is correct here since ScorePopup is placed
    // directly as a Stack child with no outer Positioned wrapping it.
    return Positioned(
      left: x - 40,
      top:  y - 50,
      child: IgnorePointer(
        child: Text(
          isCombo ? '+$points 🔥' : '+$points',
          style: isCombo ? _comboPopupStyle : _normalPopupStyle,
        )
            .animate()
            .moveY(begin: 0, end: -60, duration: 800.ms, curve: Curves.easeOut)
            .fadeOut(begin: 1.0, delay: 300.ms, duration: 500.ms),
      ),
    );
  }
}
