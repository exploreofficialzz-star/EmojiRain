import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../data/beat_tracks.dart';
import '../models/beat_track.dart';
import '../models/emoji_item.dart';
import '../providers/beat_provider.dart';
import '../providers/game_provider.dart';
import '../services/audio_service.dart';
import '../widgets/share_card_widget.dart';

// ── Entry point ────────────────────────────────────────────────────────────────
class BeatModeScreen extends StatelessWidget {
  const BeatModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide a fresh GameProvider and BeatProvider scoped to this mode
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProxyProvider<GameProvider, BeatProvider>(
          create: (c) => BeatProvider(c.read<GameProvider>()),
          update: (_, game, prev) => prev ?? BeatProvider(game),
        ),
      ],
      child: const _BeatModeNavigator(),
    );
  }
}

// ── Internal navigator — tracks which "step" we are on ─────────────────────────
enum _BeatStep { trackSelect, calibration, gameplay, gameOver }

class _BeatModeNavigator extends StatefulWidget {
  const _BeatModeNavigator();

  @override
  State<_BeatModeNavigator> createState() => _BeatModeNavigatorState();
}

class _BeatModeNavigatorState extends State<_BeatModeNavigator> {
  _BeatStep _step = _BeatStep.trackSelect;

  void _goTo(_BeatStep step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _BeatStep.trackSelect   => _TrackSelectorScreen(onContinue: _startCalibration),
      _BeatStep.calibration   => _CalibrationScreen(onReady: _startGameplay),
      _BeatStep.gameplay      => _BeatGameplayScreen(onGameOver: () => _goTo(_BeatStep.gameOver)),
      _BeatStep.gameOver      => _BeatGameOverScreen(
          onRetry: _startRetry,
          onHome:  _goHome,
        ),
    };
  }

  Future<void> _startCalibration() async {
    _goTo(_BeatStep.calibration);
  }

  Future<void> _startGameplay() async {
    final beat = context.read<BeatProvider>();
    final game = context.read<GameProvider>();
    final size = MediaQuery.of(context).size;
    await beat.startBeatMode();
    game.startGame(screenWidth: size.width, screenHeight: size.height);
    _goTo(_BeatStep.gameplay);
  }

  void _startRetry() {
    final beat = context.read<BeatProvider>();
    beat.stopBeatMode();
    _goTo(_BeatStep.trackSelect);
  }

  void _goHome() {
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — TRACK SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class _TrackSelectorScreen extends StatelessWidget {
  final VoidCallback onContinue;
  const _TrackSelectorScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final beat = context.watch<BeatProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Device sync option ──────────────────────────────
                      _buildDeviceSyncCard(context, beat),
                      const SizedBox(height: 16),

                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'FREE BUILT-IN TRACKS',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary, letterSpacing: 2,
                          ),
                        ),
                      ),

                      // ── Built-in tracks ─────────────────────────────────
                      ...BuiltInTracks.all.map((t) =>
                          _TrackCard(track: t, beat: beat)),
                    ],
                  ),
                ),
              ),

              // ── Continue button ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _ContinueButton(
                  enabled: beat.selectedTrack != null || beat.usingDeviceSync,
                  onTap:   onContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color:        AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎵  BEAT MODE', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: AppColors.accent, letterSpacing: 1,
              )),
              Text('Pick a track or sync to your music',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildDeviceSyncCard(BuildContext context, BeatProvider beat) {
    final selected = beat.usingDeviceSync;
    return GestureDetector(
      onTap: () => beat.selectDeviceSync(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withOpacity(0.1)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.accent.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mic_rounded, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sync to my music', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
                  SizedBox(height: 3),
                  Text('Taps Spotify, YouTube or any music\nplaying on your phone',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
              ),
              child: const Text('🎤 Mic', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent,
              )),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }
}

// ── Individual track card ──────────────────────────────────────────────────────

class _TrackCard extends StatelessWidget {
  final BeatTrack  track;
  final BeatProvider beat;
  const _TrackCard({required this.track, required this.beat});

  @override
  Widget build(BuildContext context) {
    final selected = beat.selectedTrack?.id == track.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => beat.selectBuiltInTrack(track),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.08)
                : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.white.withOpacity(0.06),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Genre emoji
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(track.emoji,
                    style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),

              // Name + genre chip
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.name, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _genreChip(track.genre),
                        const SizedBox(width: 6),
                        _bpmBadge(track.bpm),
                      ],
                    ),
                  ],
                ),
              ),

              // Play preview button
              GestureDetector(
                onTap: () {
                  AudioService.instance.play(SoundEffect.tap);
                  beat.previewTrack(track);
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genreChip(String genre) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Text(genre, style: const TextStyle(
        fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accent,
      )),
    );
  }

  Widget _bpmBadge(int bpm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text('$bpm BPM', style: const TextStyle(
        fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary,
      )),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final bool      enabled;
  final VoidCallback onTap;
  const _ContinueButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity, height: 58,
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryBtnGradient : null,
          color:    enabled ? null : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? [BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 18, offset: const Offset(0, 6),
                )]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎵', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              enabled ? 'CONTINUE' : 'SELECT A TRACK',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: enabled ? Colors.black : AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — CALIBRATION
// ─────────────────────────────────────────────────────────────────────────────

class _CalibrationScreen extends StatefulWidget {
  final VoidCallback onReady;
  const _CalibrationScreen({required this.onReady});

  @override
  State<_CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<_CalibrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _barCtrl;
  late AnimationController _countdownCtrl;
  int    _countdown    = 3;
  bool   _calibDone    = false;
  double _detectedBpm  = 0;
  bool   _usedFallback = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _countdownCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 1),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _runCalibration());
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    _countdownCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _runCalibration() async {
    final beat = context.read<BeatProvider>();
    final bpm  = await beat.calibrate();
    if (!mounted) return;

    setState(() {
      _detectedBpm  = bpm;
      _usedFallback = beat.confidence < 0.6;
      _calibDone    = true;
    });

    // 3-2-1 countdown before gameplay
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_countdown <= 1) {
          timer.cancel();
          widget.onReady();
        } else {
          _countdown--;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_calibDone) ...[ 
                    _buildListeningState(),
                  ] else ...[
                    _buildReadyState(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListeningState() {
    return Column(
      children: [
        const Text('🎤', style: TextStyle(fontSize: 60))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1.0, end: 1.12, duration: 700.ms),
        const SizedBox(height: 24),
        const Text('Listening...', style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textPrimary,
        )),
        const SizedBox(height: 10),
        const Text('Hold your phone near the speaker',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Animated bars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            return AnimatedBuilder(
              animation: _barCtrl,
              builder: (_, __) {
                final h = 20.0 + 40.0 * ((_barCtrl.value + i * 0.2) % 1.0);
                return Container(
                  width: 8, height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.7 + 0.3 * _barCtrl.value),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildReadyState() {
    return Column(
      children: [
        const Text('✅', style: TextStyle(fontSize: 60))
            .animate().scale(
              begin: const Offset(0.3, 0.3), end: const Offset(1.0, 1.0),
              duration: 500.ms, curve: Curves.elasticOut,
            ),
        const SizedBox(height: 20),
        Text(
          _usedFallback
              ? 'Using ${_detectedBpm.round()} BPM'
              : 'Got it! ${_detectedBpm.round()} BPM',
          style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary,
          ),
        ),
        if (_usedFallback)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('(closest built-in beat)', style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary,
            )),
          ),
        const SizedBox(height: 32),
        // Countdown
        Text(
          '$_countdown',
          style: const TextStyle(
            fontSize: 80, fontWeight: FontWeight.w900, color: AppColors.accent,
          ),
        ).animate(key: ValueKey(_countdown)).scale(
          begin: const Offset(1.4, 1.4), end: const Offset(1.0, 1.0),
          duration: 400.ms, curve: Curves.easeOut,
        ),
        const Text('Starting...', style: TextStyle(
          fontSize: 14, color: AppColors.textSecondary, letterSpacing: 2,
        )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — GAMEPLAY
// ─────────────────────────────────────────────────────────────────────────────

class _BeatGameplayScreen extends StatefulWidget {
  final VoidCallback onGameOver;
  const _BeatGameplayScreen({required this.onGameOver});

  @override
  State<_BeatGameplayScreen> createState() => _BeatGameplayScreenState();
}

class _BeatGameplayScreenState extends State<_BeatGameplayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringCtrl;
  Timer? _labelTimer;
  bool   _showBeatLabel = false;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );

    // Watch for game over
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().addListener(_onGameState);
      context.read<BeatProvider>().addListener(_onBeatState);
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _labelTimer?.cancel();
    context.read<GameProvider>().removeListener(_onGameState);
    context.read<BeatProvider>().removeListener(_onBeatState);
    super.dispose();
  }

  void _onGameState() {
    final game = context.read<GameProvider>();
    if (game.isGameOver) {
      context.read<BeatProvider>().stopBeatMode();
      widget.onGameOver();
    }
  }

  void _onBeatState() {
    final beat = context.read<BeatProvider>();
    if (beat.lastBeatLabel != BeatLabel.none) {
      _ringCtrl.forward(from: 0);
      setState(() => _showBeatLabel = true);
      _labelTimer?.cancel();
      _labelTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _showBeatLabel = false);
          beat.clearBeatLabel();
        }
      });
    }
  }

  void _handleTap(EmojiItem emoji) {
    context.read<BeatProvider>().onBeatTap(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final beat = context.watch<BeatProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Reuse existing game canvas ──────────────────────────────────
          _BeatGameCanvas(
            game: game,
            size: size,
            onEmojiTap: _handleTap,
          ),

          // ── Beat HUD overlay ────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildBpmBar(beat),
                const Spacer(),
                _buildBeatMultiplierBadge(beat),
                const SizedBox(height: 12),
                _buildPulsingRing(beat),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Beat streak counter (top right) ─────────────────────────────
          Positioned(
            top: 56, right: 16,
            child: _buildStreakBadge(beat),
          ),
        ],
      ),
    );
  }

  Widget _buildBpmBar(BeatProvider beat) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note_rounded, color: AppColors.accent, size: 16),
              const SizedBox(width: 6),
              Text('${beat.currentBpm.round()} BPM', style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.accent,
              )),
            ],
          ),
          Text('BEAT MODE', style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: AppColors.textSecondary, letterSpacing: 2,
          )),
        ],
      ),
    );
  }

  Widget _buildBeatMultiplierBadge(BeatProvider beat) {
    if (!_showBeatLabel) return const SizedBox.shrink();

    final (label, color) = switch (beat.lastBeatLabel) {
      BeatLabel.onBeat => ('🔥 ON BEAT', AppColors.primary),
      BeatLabel.close  => ('✨ CLOSE',   AppColors.accent),
      _                => ('',           Colors.transparent),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Text(label, style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w900, color: color,
        )).animate().fadeIn(duration: 150.ms).slideY(begin: 0.3, end: 0),
        const SizedBox(height: 4),
        Text('${beat.beatMultiplier.toStringAsFixed(1)}×',
          style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w900, color: color,
          ),
        ).animate().scale(
          begin: const Offset(0.6, 0.6), end: const Offset(1.0, 1.0),
          duration: 300.ms, curve: Curves.elasticOut,
        ),
      ],
    );
  }

  Widget _buildPulsingRing(BeatProvider beat) {
    return AnimatedBuilder(
      animation: _ringCtrl,
      builder: (_, __) {
        final scale = 1.0 + _ringCtrl.value * 0.25;
        final opacity = 1.0 - _ringCtrl.value * 0.6;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.8), width: 3,
                ),
                color: AppColors.accent.withOpacity(0.08),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: AppColors.accent, size: 32),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreakBadge(BeatProvider beat) {
    if (beat.beatStreak < 3) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          Text('${beat.beatStreak}', style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary,
          )),
          const Text('STREAK', style: TextStyle(
            fontSize: 8, color: AppColors.textSecondary, letterSpacing: 1,
          )),
        ],
      ),
    );
  }
}

// ── Minimal game canvas wrapping the existing emoji physics ───────────────────

class _BeatGameCanvas extends StatelessWidget {
  final GameProvider game;
  final Size         size;
  final void Function(EmojiItem) onEmojiTap;

  const _BeatGameCanvas({
    required this.game,
    required this.size,
    required this.onEmojiTap,
  });

  @override
  Widget build(BuildContext context) {
    // Reuse the AnimatedBuilder pattern from GameScreen for smooth motion
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) => Stack(
        children: [
          // Dark background
          Container(decoration: const BoxDecoration(gradient: AppColors.bgGradient)),

          // Hearts HUD
          Positioned(
            top: 8, left: 12,
            child: SafeArea(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(GameConstants.maxHearts, (i) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    i < game.hearts ? '❤️' : '🖤',
                    style: const TextStyle(fontSize: 18),
                  ),
                )),
              ),
            ),
          ),

          // Score
          Positioned(
            top: 8, right: 12,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${context.read<BeatProvider>().beatScore}',
                    style: AppTextStyles.scoreText.copyWith(fontSize: 28)),
                  Text('Combo ×${game.comboMultiplier}',
                    style: const TextStyle(fontSize: 11, color: AppColors.comboOrange,
                        fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),

          // Emojis
          ...game.emojis.where((e) => e.isFalling).map((emoji) => Positioned(
            left: emoji.x - emoji.size / 2,
            top:  emoji.y - emoji.size / 2,
            child: GestureDetector(
              onTap: () => onEmojiTap(emoji),
              child: Transform.rotate(
                angle: emoji.rotation,
                child: Text(emoji.emoji,
                    style: TextStyle(fontSize: emoji.size * 0.5)),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4 — GAME OVER
// ─────────────────────────────────────────────────────────────────────────────

class _BeatGameOverScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onHome;
  const _BeatGameOverScreen({required this.onRetry, required this.onHome});

  @override
  Widget build(BuildContext context) {
    final beat = context.watch<BeatProvider>();
    final game = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Text('🎵', style: TextStyle(fontSize: 70))
                    .animate().scale(
                      begin: const Offset(0.3, 0.3), end: const Offset(1.0, 1.0),
                      duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 20),
                ShaderMask(
                  shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                  child: const Text('BEAT OVER', style: TextStyle(
                    fontSize: 36, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 2,
                  )),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 28),

                // ── Beat stats card ────────────────────────────────────
                _buildBeatStatsCard(beat, game),
                const SizedBox(height: 20),

                // ── Share card ─────────────────────────────────────────
                ShareCardWidget(
                  score:          beat.beatScore,
                  level:          game.level,
                  maxCombo:       game.maxCombo,
                  accuracyPct:    beat.beatAccuracyPct,
                  isBeatMode:     true,
                  beatAccuracyPct: beat.beatAccuracyPct,
                  bestMultiplier:  beat.bestMultiplierHit,
                ),
                const SizedBox(height: 16),

                // ── Retry ──────────────────────────────────────────────
                _buildButton(
                  emoji: '🔄', label: 'TRY AGAIN',
                  gradient: AppColors.primaryBtnGradient,
                  textColor: Colors.black, onTap: onRetry,
                ).animate().fadeIn(delay: 800.ms),
                const SizedBox(height: 12),
                _buildButton(
                  emoji: '🏠', label: 'HOME',
                  color: AppColors.surfaceCard,
                  textColor: AppColors.textSecondary, onTap: onHome,
                ).animate().fadeIn(delay: 900.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeatStatsCard(BeatProvider beat, GameProvider game) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          // Beat score
          Text('${beat.beatScore}', style: AppTextStyles.scoreText),
          const Text('BEAT SCORE', style: TextStyle(
            fontSize: 10, color: AppColors.textSecondary,
            letterSpacing: 2, fontWeight: FontWeight.w700,
          )),
          const Divider(color: Colors.white12, height: 24),
          // Stats grid
          Row(children: [
            _statCell('ACCURACY', '${beat.beatAccuracyPct.toStringAsFixed(0)}%', '🎯'),
            Container(width: 1, height: 40, color: Colors.white12),
            _statCell('BEST ×', '${beat.bestMultiplierHit.toStringAsFixed(1)}×', '⚡'),
            Container(width: 1, height: 40, color: Colors.white12),
            _statCell('STREAK', '${beat.bestStreak}', '🔥'),
          ]),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).scale(
      begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 400.ms,
    );
  }

  Widget _statCell(String label, String value, String emoji) {
    return Expanded(
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary,
        )),
        Text(label, style: const TextStyle(
          fontSize: 9, color: AppColors.textSecondary, letterSpacing: 1,
        )),
      ]),
    );
  }

  Widget _buildButton({
    required String emoji, required String label,
    Gradient? gradient, Color? color, required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: gradient, color: color,
          borderRadius: BorderRadius.circular(16),
          border: color != null
              ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
          boxShadow: gradient != null
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 14, offset: const Offset(0, 5))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900, color: textColor,
            letterSpacing: 1,
          )),
        ]),
      ),
    );
  }
}
