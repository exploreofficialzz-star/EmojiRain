import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/emoji_item.dart';
import '../providers/game_provider.dart';
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

  void _checkLevelUp(int level) {
    if (level != _previousLevel) {
      _previousLevel = level;
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
    final game = context.read<GameProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Static background — painted once, never rebuilds
          const _GameBackground(),

          // Emoji canvas — repaints via frameTick, zero widget rebuilds per frame
          RepaintBoundary(
            child: _EmojiCanvas(game: game),
          ),

          // Tap interceptor
          _TapLayer(game: game),

          // Score popups
          ..._buildScorePopups(game),

          // HUD — Selector means only rebuilds when these values change
          SafeArea(
            child: Column(
              children: [
                Selector<GameProvider, (int, int, int, int)>(
                  selector: (_, g) =>
                      (g.score, g.combo, g.level, g.levelSecondsLeft),
                  builder: (_, __, ___) => ScoreHUD(game: game),
                ),
                const SizedBox(height: 8),
                Selector<GameProvider, int>(
                  selector: (_, g) => g.level,
                  builder: (_, level, ___) {
                    _checkLevelUp(level);
                    return RuleDisplay(
                      level:     game.currentLevel,
                      animateIn: _showLevelUp,
                    );
                  },
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Selector<GameProvider, int>(
                    selector: (_, g) => g.combo,
                    builder: (_, combo, ___) => ComboStreakBadge(combo: combo),
                  ),
                ),
              ],
            ),
          ),

          // Level Up banner
          if (_showLevelUp)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Selector<GameProvider, int>(
                    selector: (_, g) => g.level,
                    builder: (_, level, ___) => LevelUpBanner(level: level),
                  ),
                ),
              ),
            ),

          // Game over / pause — only rebuilds on state change
          Selector<GameProvider, GameState>(
            selector: (_, g) => g.state,
            builder: (_, state, ___) {
              if (state == GameState.gameOver) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
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
              if (state == GameState.paused) return _PauseOverlay(game: game);
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScorePopups(GameProvider game) {
    _handleScoreEvents(game);
    return _activeScoreEvents.map((d) => ScorePopup(
      key:     ValueKey(d.hashCode),
      points:  d.event.points,
      x:       d.event.x,
      y:       d.event.y,
      isCombo: d.event.isCombo,
    )).toList();
  }
}

// ─── Emoji Canvas ─────────────────────────────────────────────────────────────
class _EmojiCanvas extends StatelessWidget {
  final GameProvider game;
  const _EmojiCanvas({required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.frameTick,
      builder: (_, __, ___) => CustomPaint(
        size:    Size.infinite,
        painter: _EmojiPainter(emojis: game.emojis),
      ),
    );
  }
}

class _EmojiPainter extends CustomPainter {
  final List<EmojiItem> emojis;
  _EmojiPainter({required this.emojis});

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in emojis) {
      if (!e.isFalling) continue;
      final tp = TextPainter(
        text: TextSpan(
          text:  e.emoji,
          style: TextStyle(fontSize: e.size * 0.78, height: 1.0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(e.x, e.y);
      canvas.rotate(e.rotation);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EmojiPainter _) => true;
}

// ─── Tap Layer ────────────────────────────────────────────────────────────────
class _TapLayer extends StatelessWidget {
  final GameProvider game;
  const _TapLayer({required this.game});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) {
        final pos    = details.localPosition;
        final emojis = game.emojis.toList();
        for (final e in emojis.reversed) {
          if (e.isFalling && e.hitTest(pos.dx, pos.dy, r: e.size * 0.55)) {
            game.onEmojiTapped(e);
            break;
          }
        }
      },
      child: const SizedBox.expand(),
    );
  }
}

// ─── Static Background ────────────────────────────────────────────────────────
class _GameBackground extends StatelessWidget {
  const _GameBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [Color(0xFF0D0D2B), Color(0xFF08081A), Color(0xFF0A0A1F)],
          stops:  [0.0, 0.5, 1.0],
        ),
      ),
      child: const CustomPaint(
        size:    Size.infinite,
        painter: _StarfieldPainter(),
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.25);
    for (int i = 0; i < 40; i++) {
      final x = size.width  * ((i * 137) % 97) / 97;
      final y = size.height * ((i * 83)  % 89) / 89;
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.5 : 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter _) => false;
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

// ─── Score Popup ──────────────────────────────────────────────────────────────
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
      child: IgnorePointer(
        child: Text(
          isCombo ? '+$points 🔥' : '+$points',
          style: TextStyle(
            fontSize:   isCombo ? 22 : 18,
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

// ─── Internal helpers ─────────────────────────────────────────────────────────
class _ScoreEventDisplay {
  final ScoreEvent event;
  final DateTime   expiry;
  _ScoreEventDisplay({required this.event, required this.expiry});
}
