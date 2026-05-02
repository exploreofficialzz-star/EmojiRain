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
  int  _previousLevel = 1;
  bool _showLevelUp   = false;
  final List<_ScoreEventDisplay> _activeScoreEvents = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initGame());
  }

  void _initGame() {
    if (widget.isContinue) return;
    final size = MediaQuery.sizeOf(context);
    context.read<GameProvider>().startGame(
      screenWidth:  size.width,
      screenHeight: size.height,
    );
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

  void _checkLevelUp(GameProvider game) {
    if (game.level != _previousLevel) {
      _previousLevel = game.level;
      setState(() => _showLevelUp = true);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _showLevelUp = false);
      });
    }
  }

  void _handleScoreEvents(GameProvider game) {
    for (final ev in game.scoreEvents) {
      _activeScoreEvents.add(_ScoreEventDisplay(
        event:  ev,
        expiry: DateTime.now().add(const Duration(milliseconds: 900)),
      ));
    }
    game.clearScoreEvents();
    _activeScoreEvents.removeWhere((e) => DateTime.now().isAfter(e.expiry));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Consumer<GameProvider>(
      builder: (context, game, _) {
        _checkLevelUp(game);
        _handleScoreEvents(game);

        if (game.isGameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && game.isGameOver) {
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, anim, __) => const GameOverScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              );
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                _GameBackground(level: game.level),
                ..._buildEmojis(game, screenSize),
                ..._buildScorePopups(),
                SafeArea(
                  child: Column(
                    children: [
                      ScoreHUD(game: game),
                      const SizedBox(height: 8),
                      RuleDisplay(
                        level:     game.currentLevel,
                        animateIn: _showLevelUp,
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: ComboStreakBadge(combo: game.combo),
                      ),
                    ],
                  ),
                ),
                if (_showLevelUp)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: LevelUpBanner(level: game.level),
                      ),
                    ),
                  ),
                if (game.state == GameState.paused)
                  _PauseOverlay(game: game),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildEmojis(GameProvider game, Size screenSize) {
    return game.emojis.map((e) {
      final left = (e.x - e.size / 2).clamp(0.0, screenSize.width  - e.size);
      final top  = (e.y - e.size / 2).clamp(-e.size, screenSize.height);
      return Positioned(
        key:  ValueKey(e.id),
        left: left,
        top:  top,
        child: FallingEmojiWidget(
          emoji: e,
          onTap: () => game.onEmojiTapped(e),
        ),
      );
    }).toList();
  }

  List<Widget> _buildScorePopups() {
    return _activeScoreEvents.map((display) => ScorePopup(
      key:     ValueKey(display.hashCode),
      points:  display.event.points,
      x:       display.event.x,
      y:       display.event.y,
      isCombo: display.event.isCombo,
    )).toList();
  }
}

// ─── Game Background ──────────────────────────────────────────────────────────
class _GameBackground extends StatelessWidget {
  final int level;
  const _GameBackground({required this.level});

  @override
  Widget build(BuildContext context) {
    final intensity = (level / 10).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF0D0D2B), const Color(0xFF1A0D2B), intensity)!,
            Color.lerp(const Color(0xFF08081A), const Color(0xFF0D0814), intensity)!,
          ],
        ),
      ),
      child: CustomPaint(
        size:    Size.infinite,
        painter: _StarfieldPainter(seed: level),
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final int seed;
  const _StarfieldPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.25);
    for (int i = 0; i < 40; i++) {
      final x = size.width  * ((i * 137 + seed * 11) % 97) / 97;
      final y = size.height * ((i * 83  + seed * 7)  % 89) / 89;
      canvas.drawCircle(Offset(x, y), (i % 3 == 0) ? 1.5 : 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.seed != seed;
}

// ─── Pause Overlay ────────────────────────────────────────────────────────────
class _PauseOverlay extends StatelessWidget {
  final GameProvider game;
  const _PauseOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Container(
          margin:  const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color:        AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.4), width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏸️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize:      28,
                  fontWeight:    FontWeight.w900,
                  color:         AppColors.textPrimary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text('Score: ${game.score}', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 28),
              _buildBtn(
                label: 'RESUME', icon: '▶️',
                gradient:  AppColors.primaryBtnGradient,
                textColor: Colors.black,
                onTap: () => game.resumeGame(),
              ),
              const SizedBox(height: 12),
              _buildBtn(
                label: 'QUIT', icon: '🏠',
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A4A), Color(0xFF1A1A35)],
                ),
                textColor: Colors.white,
                onTap: () {
                  game.goHome();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildBtn({
    required String       label,
    required String       icon,
    required Gradient     gradient,
    required Color        textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient:     gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize:      16,
                fontWeight:    FontWeight.w800,
                color:         textColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Internal helpers ─────────────────────────────────────────────────────────
class _ScoreEventDisplay {
  final ScoreEvent event;
  final DateTime   expiry;
  _ScoreEventDisplay({required this.event, required this.expiry});
}
