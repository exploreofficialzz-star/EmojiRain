import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_constants.dart';

/// Renders a shareable result card and provides a "Share result" button.
///
/// Used on both the Classic and Beat Mode game-over screens.
/// Wraps a decorated [RepaintBoundary] widget that gets captured via
/// [RenderRepaintBoundary.toImage] and saved as a PNG, then shared
/// through [Share.shareXFiles] from the share_plus package.
class ShareCardWidget extends StatefulWidget {
  final int    score;
  final int    level;
  final int    maxCombo;
  final double accuracyPct;
  final bool   isBeatMode;
  final double beatAccuracyPct;  // Beat Mode only
  final double bestMultiplier;   // Beat Mode only

  const ShareCardWidget({
    super.key,
    required this.score,
    required this.level,
    required this.maxCombo,
    required this.accuracyPct,
    this.isBeatMode      = false,
    this.beatAccuracyPct = 0,
    this.bestMultiplier  = 1.0,
  });

  @override
  State<ShareCardWidget> createState() => _ShareCardWidgetState();
}

class _ShareCardWidgetState extends State<ShareCardWidget> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;
  bool _shared  = false;

  // ── Dynamic tagline from home_screen style fake stats ─────────────────────
  String get _tagline {
    final lvl = widget.level;
    if (lvl >= 10) return 'Top 1% of players reach level $lvl 🔥';
    if (lvl >= 7)  return 'Only 3% reach level $lvl';
    if (lvl >= 5)  return 'Only 8% survive to level $lvl';
    return 'Can you beat ${widget.score} points?';
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() { _sharing = true; });

    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) { setState(() => _sharing = false); return; }

      // Capture at 3× pixel ratio for a sharp share image
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) { setState(() => _sharing = false); return; }

      final bytes = byteData.buffer.asUint8List();

      // Save to temp dir
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/emoji_rain_result.png');
      await file.writeAsBytes(bytes);

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🎮 I scored ${widget.score} pts on Emoji Rain!\n'
              '${widget.isBeatMode ? "🎵 Beat Mode" : "⚡ Classic"} — '
              'Level ${widget.level}, ×${widget.maxCombo} combo\n'
              '$_tagline\n'
              '#EmojiRain #FocusOrFail',
      );

      if (mounted) setState(() { _sharing = false; _shared = true; });
    } catch (_) {
      if (mounted) setState(() { _sharing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── The card that gets captured ──────────────────────────────────
        RepaintBoundary(
          key: _cardKey,
          child: _buildCard(),
        ),
        const SizedBox(height: 14),

        // ── Share button ─────────────────────────────────────────────────
        GestureDetector(
          onTap: _share,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity, height: 50,
            decoration: BoxDecoration(
              color: _shared
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _shared
                    ? AppColors.success.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_sharing)
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.accent, strokeWidth: 2,
                    ),
                  )
                else
                  Text(_shared ? '✅' : '📸',
                      style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  _sharing ? 'Preparing...'
                      : _shared ? 'Shared!'
                      : 'Share result',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _shared ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 700.ms),
      ],
    );
  }

  // ── Card visual ───────────────────────────────────────────────────────────

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D0D2B), Color(0xFF141432), Color(0xFF0A0A1F)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Logo row ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShaderMask(
                shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                child: const Text('EMOJI RAIN', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 2,
                )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isBeatMode
                      ? AppColors.accent.withOpacity(0.15)
                      : AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isBeatMode
                        ? AppColors.accent.withOpacity(0.5)
                        : AppColors.success.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  widget.isBeatMode ? '🎵 Beat Mode' : '⚡ Classic',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: widget.isBeatMode ? AppColors.accent : AppColors.success,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Score ─────────────────────────────────────────────────────
          Text('${widget.score}', style: const TextStyle(
            fontSize: 56, fontWeight: FontWeight.w900,
            color: AppColors.primary, letterSpacing: -2,
            shadows: [Shadow(color: Color(0xFFFFAA00), blurRadius: 20)],
          )),
          const Text('SCORE', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: AppColors.textSecondary, letterSpacing: 3,
          )),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),

          // ── Stats grid ────────────────────────────────────────────────
          Row(children: [
            _statTile('LEVEL', '${widget.level}', '🎯'),
            _divider(),
            _statTile('COMBO', '×${widget.maxCombo}', '🔥'),
            _divider(),
            _statTile('ACCURACY', '${widget.accuracyPct.toStringAsFixed(0)}%', '💡'),
          ]),

          if (widget.isBeatMode) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            Row(children: [
              _statTile('BEAT ACC', '${widget.beatAccuracyPct.toStringAsFixed(0)}%', '🎵'),
              _divider(),
              _statTile('BEST ×', '${widget.bestMultiplier.toStringAsFixed(1)}×', '⚡'),
            ]),
          ],

          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),

          // ── Tagline ────────────────────────────────────────────────────
          Text(_tagline, style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ), textAlign: TextAlign.center),

          const SizedBox(height: 12),

          // ── Branding ──────────────────────────────────────────────────
          const Text('by ChAs', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w900,
            color: AppColors.primary, letterSpacing: 2,
          )),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, String emoji) {
    return Expanded(
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary,
        )),
        Text(label, style: const TextStyle(
          fontSize: 9, color: AppColors.textSecondary, letterSpacing: 1,
        )),
      ]),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 44, color: Colors.white12,
  );
}
