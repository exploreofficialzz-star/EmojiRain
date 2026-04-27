import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../widgets/falling_emoji_widget.dart';
import '../widgets/rule_display.dart';
import '../widgets/score_hud.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  final bool isContinue;
  const GameScreen({super.key, this.isContinue = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  int  _prevLevel      = 1;
  int  _prevStage      = 0;
  bool _showLevelUp    = false;
  bool _showSpeedBanner = false;
  int  _displayStage   = 0;

  final List<_ScoreDisplay> _scoreDisplays = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isContinue) {
        final size = MediaQuery.sizeOf(context);
        context.read<GameProvider>().startGame(
          screenWidth: size.width,
          screenHeight: size.height,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      context.read<GameProvider>().pauseGame();
    }
  }

  void _checkEvents(GameProvider game) {
    // Level up
    if (game.level != _prevLevel) {
      _prevLevel = game.level;
      setState(() => _showLevelUp = true);
      Future.delayed(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() => _showLevelUp = false);
      });
    }

    // Speed stage ramp
    if (game.speedStage != _prevStage && game.speedStage > 0) {
      _prevStage    = game.speedStage;
      _displayStage = game.speedStage;
      setState(() => _showSpeedBanner = true);
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _showSpeedBanner = false);
      });
    }
  }

  void _handleScoreEvents(GameProvider game) {
    final now = DateTime.now();
    for (final ev in game.scoreEvents) {
      _scoreDisplays.add(_ScoreDisplay(
        event: ev,
        expiry: now.add(const Duration(milliseconds: 900)),
      ));
    }
    game.clearScoreEvents();
    _scoreDisplays.removeWhere((d) => now.isAfter(d.expiry));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        _checkEvents(game);
        _handleScoreEvents(game);

        // Navigate to game over
        if (game.isGameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && game.isGameOver) {
              Navigator.of(context).pushReplacement(PageRouteBuilder(
                pageBuilder: (_, anim, __) => const GameOverScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 400),
              ));
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // ── Background ───────────────────────────────────────────────
              _GameBackground(level: game.level, stage: game.speedStage),

              // ── Falling emojis ───────────────────────────────────────────
              ..._buildEmojis(game),

              // ── Score popups ─────────────────────────────────────────────
              ..._scoreDisplays.map((d) => ScorePopup(
                key: ValueKey('${d.hashCode}'),
                points: d.event.points,
                x: d.event.x,
                y: d.event.y,
                isCombo: d.event.isCombo,
              )),

              // ── HUD ───────────────────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    ScoreHUD(game: game),
                    const SizedBox(height: 6),
                    RuleDisplay(level: game.currentLevel, animateIn: _showLevelUp),
                    // Speed stage pill
                    if (game.speedStage > 0) ...[
                      const SizedBox(height: 6),
                      SpeedStageIndicator(stage: game.speedStage),
                    ],
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: ComboStreakBadge(combo: game.combo),
                    ),
                  ],
                ),
              ),

              // ── Level Up overlay ─────────────────────────────────────────
              if (_showLevelUp)
                Positioned.fill(
                  child: IgnorePointer(
                    child: LevelUpBanner(
                      level: game.level,
                      title: game.currentLevel.title,
                    ),
                  ),
                ),

              // ── Speed Up overlay ─────────────────────────────────────────
              if (_showSpeedBanner)
                Positioned(
                  top: MediaQuery.sizeOf(context).height * 0.35,
                  left: 0, right: 0,
                  child: IgnorePointer(
                    child: SpeedUpBanner(stage: _displayStage),
                  ),
                ),

              // ── Pause overlay ─────────────────────────────────────────────
              if (game.state == GameState.paused)
                _PauseOverlay(game: game),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildEmojis(GameProvider game) => game.emojis.map((e) =>
      FallingEmojiWidget(
        key: ValueKey(e.id),
        emoji: e,
        onTap: () => game.onEmojiTapped(e),
      )).toList();
}

// ─── Animated background tints with speed stage ───────────────────────────────
class _GameBackground extends StatelessWidget {
  final int level;
  final int stage;
  const _GameBackground({required this.level, required this.stage});

  @override
  Widget build(BuildContext context) {
    // Background gets slightly more intense as speed increases
    final tint = stage / 3.0;
    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF0D0D2B), const Color(0xFF1A0509), tint)!,
            Color.lerp(const Color(0xFF08081A), const Color(0xFF100508), tint)!,
          ],
        ),
      ),
      child: CustomPaint(size: Size.infinite, painter: _StarPainter(seed: level)),
    );
  }
}

class _StarPainter extends CustomPainter {
  final int seed;
  const _StarPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.22);
    for (int i = 0; i < 48; i++) {
      final x = size.width  * ((i * 137 + seed * 11) % 97) / 97;
      final y = size.height * ((i * 83  + seed * 7)  % 89) / 89;
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.5 : 1.0, p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.seed != seed;
}

// ─── Pause Overlay ────────────────────────────────────────────────────────────
class _PauseOverlay extends StatelessWidget {
  final GameProvider game;
  const _PauseOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.78),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏸️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('PAUSED', style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary, letterSpacing: 3,
              )),
              const SizedBox(height: 6),
              Text('Score: ${game.score}  •  Level ${game.level}',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 28),
              _btn('▶️', 'RESUME', AppColors.primaryBtnGradient, Colors.black,
                  () => game.resumeGame()),
              const SizedBox(height: 12),
              _btn('🏠', 'QUIT',
                  const LinearGradient(colors: [Color(0xFF2A2A4A), Color(0xFF1A1A35)]),
                  Colors.white, () {
                game.goHome();
                Navigator.of(context).popUntil((r) => r.isFirst);
              }),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _btn(String icon, String label, Gradient gradient, Color textColor, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: textColor, letterSpacing: 1,
              )),
            ],
          ),
        ),
      );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _ScoreDisplay {
  final ScoreEvent event;
  final DateTime   expiry;
  _ScoreDisplay({required this.event, required this.expiry});
}
