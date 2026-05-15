import 'dart:math';
import 'package:flutter/material.dart';

// ── Tap Effect Type ───────────────────────────────────────────────────────────
enum TapEffectType { correct, wrong }

// ── Tap Effect Data ───────────────────────────────────────────────────────────
class TapEffect {
  final String id;
  final double x;
  final double y;
  final TapEffectType type;
  final String emoji;

  TapEffect({
    required this.x,
    required this.y,
    required this.type,
    required this.emoji,
  }) : id = '${DateTime.now().microsecondsSinceEpoch}_${x.toInt()}';
}

// ── Tap Effect Widget ─────────────────────────────────────────────────────────
class TapEffectWidget extends StatefulWidget {
  final TapEffect effect;
  final VoidCallback onComplete;

  const TapEffectWidget({
    super.key,
    required this.effect,
    required this.onComplete,
  });

  @override
  State<TapEffectWidget> createState() => _TapEffectWidgetState();
}

class _TapEffectWidgetState extends State<TapEffectWidget>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _ringController;
  late AnimationController _emojiController;

  late Animation<double> _particleAnim;
  late Animation<double> _ringAnim;
  late Animation<double> _emojiAnim;
  late Animation<double> _emojiOpacity;

  static const Duration _duration = Duration(milliseconds: 650);

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete();
      });

    _ringController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _emojiController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _particleAnim = CurvedAnimation(
        parent: _particleController, curve: Curves.easeOut);

    _ringAnim = CurvedAnimation(
        parent: _ringController, curve: Curves.easeOut);

    _emojiAnim = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.4)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.4, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 60),
    ]).animate(_emojiController);

    _emojiOpacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _emojiController,
          curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    _particleController.forward();
    _ringController.forward();
    _emojiController.forward();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _ringController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = widget.effect.type == TapEffectType.correct;

    return Positioned(
      left: widget.effect.x - 60,
      top:  widget.effect.y - 60,
      child: SizedBox(
        width:  120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Ring expansion ────────────────────────────────────────
            AnimatedBuilder(
              animation: _ringAnim,
              builder: (_, __) => CustomPaint(
                size: const Size(120, 120),
                painter: _RingPainter(
                  progress:  _ringAnim.value,
                  isCorrect: isCorrect,
                ),
              ),
            ),

            // ── Particles ─────────────────────────────────────────────
            AnimatedBuilder(
              animation: _particleAnim,
              builder: (_, __) => CustomPaint(
                size: const Size(120, 120),
                painter: _ParticlePainter(
                  progress:  _particleAnim.value,
                  isCorrect: isCorrect,
                ),
              ),
            ),

            // ── Emoji pop ─────────────────────────────────────────────
            AnimatedBuilder(
              animation: _emojiController,
              builder: (_, __) => Opacity(
                opacity: _emojiOpacity.value,
                child: Transform.scale(
                  scale: _emojiAnim.value,
                  child: Text(
                    widget.effect.emoji,
                    style: const TextStyle(fontSize: 44),
                  ),
                ),
              ),
            ),

            // ── Correct tick / Wrong X ────────────────────────────────
            AnimatedBuilder(
              animation: _emojiController,
              builder: (_, __) {
                if (_emojiController.value < 0.3) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  opacity: (((_emojiController.value - 0.3) / 0.3).clamp(0.0, 1.0) *
                      (1.0 - ((_emojiController.value - 0.7) / 0.3).clamp(0.0, 1.0))),
                  child: Text(
                    isCorrect ? '✓' : '✕',
                    style: TextStyle(
                      fontSize:   28,
                      fontWeight: FontWeight.w900,
                      color:      isCorrect
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF1744),
                      shadows: [
                        Shadow(
                          color:      (isCorrect
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFF1744))
                              .withOpacity(0.8),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ring Painter ──────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final bool   isCorrect;
  _RingPainter({required this.progress, required this.isCorrect});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 20.0 + progress * 48.0;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    final color = isCorrect
        ? const Color(0xFFFFD700)
        : const Color(0xFFFF1744);

    final paint = Paint()
      ..color       = color.withOpacity(opacity * 0.7)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 3.0 * (1.0 - progress * 0.6);

    canvas.drawCircle(center, radius, paint);

    // Second ring slightly behind
    if (progress > 0.15) {
      final ring2 = Paint()
        ..color       = color.withOpacity((opacity * 0.4).clamp(0.0, 1.0))
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - progress * 0.5);
      canvas.drawCircle(center, radius * 0.7, ring2);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Particle Painter ──────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  final bool   isCorrect;
  static final Random _rng = Random(42);

  _ParticlePainter({required this.progress, required this.isCorrect});

  @override
  void paint(Canvas canvas, Size size) {
    final center  = Offset(size.width / 2, size.height / 2);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    // Correct: gold + cyan + green  |  Wrong: red + orange + pink
    final colors = isCorrect
        ? [
            const Color(0xFFFFD700),
            const Color(0xFF00E5FF),
            const Color(0xFF00E676),
            const Color(0xFFFFAA00),
            const Color(0xFFFFFFFF),
          ]
        : [
            const Color(0xFFFF1744),
            const Color(0xFFFF6D00),
            const Color(0xFFFF4081),
            const Color(0xFFFFFFFF),
            const Color(0xFFFF8A80),
          ];

    const particleCount = 12;

    for (int i = 0; i < particleCount; i++) {
      final angle    = (i / particleCount) * 2 * pi + (i.isEven ? 0.2 : -0.2);
      final speed    = 40.0 + (i % 3) * 12.0;
      final distance = progress * speed;
      final x        = center.dx + cos(angle) * distance;
      final y        = center.dy + sin(angle) * distance;
      final color    = colors[i % colors.length];
      final size2    = (3.0 + (i % 3) * 1.5) * (1.0 - progress * 0.5);

      final paint = Paint()
        ..color       = color.withOpacity(opacity)
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 1.5);

      // Alternate between circles and small diamonds
      if (i % 3 == 0) {
        final path = Path()
          ..moveTo(x, y - size2)
          ..lineTo(x + size2 * 0.6, y)
          ..lineTo(x, y + size2)
          ..lineTo(x - size2 * 0.6, y)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(Offset(x, y), size2, paint);
      }
    }

    // Extra sparkle dots
    for (int i = 0; i < 6; i++) {
      final angle    = (i / 6) * 2 * pi + pi / 6 + progress * 0.5;
      final distance = progress * 55.0;
      final x        = center.dx + cos(angle) * distance;
      final y        = center.dy + sin(angle) * distance;
      final sparklePaint = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.9);
      canvas.drawCircle(Offset(x, y), 2.0 * (1.0 - progress), sparklePaint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
