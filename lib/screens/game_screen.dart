import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/network_service.dart';
import '../widgets/falling_emoji_widget.dart';
import '../widgets/network_banner.dart';
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
  int  _previousLevel    = 1;
  bool _showLevelUp      = false;
  bool _pausedByNetwork  = false; // tracks if WE paused due to network
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

  // ── Network-triggered pause/resume ─────────────────────────────────────────
  // Called from Consumer whenever NetworkService changes.
  void _handleNetworkChange(GameProvider game, NetworkService net) {
    if (net.isOffline && game.isPlaying) {
      // Connection dropped mid-game — pause automatically
      game.pauseGame();
      _pausedByNetwork = true;
    } else if (net.isOnline && _pausedByNetwork && game.isPaused) {
      // Connection restored — auto-resume
      _pausedByNetwork = false;
      game.resumeGame();
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

  // ── Slow Mo — watch rewarded ad ───────────────────────────────────────────
  Future<void> _activateSlowMo(GameProvider game) async {
    // Block if offline
    if (NetworkService.instance.isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connect to the internet to use Slow-Mo.'),
            backgroundColor: const Color(0xFFE65100),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (!AdService.instance.rewardedReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ad not ready yet. Try again in a moment.'),
            backgroundColor: AppColors.surfaceCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    game.pauseGame();

    await AdService.instance.showRewarded(
      onRewarded: () {
        game.activateSlowMo();
        game.resumeGame();
      },
      onSkipped:     () => game.resumeGame(),
      onUnavailable: () {
        game.resumeGame();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ad unavailable. Try again shortly.'),
              backgroundColor: AppColors.surfaceCard,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Consumer2<GameProvider, NetworkService>(
      builder: (context, game, net, _) {
        _checkLevelUp(game);
        _handleScoreEvents(game);

        // React to network changes in real time
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleNetworkChange(game, net),
        );

        // Navigate to GameOverScreen when game ends
        if (game.isGameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && game.isGameOver) {
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder:        (_, anim, __) => const GameOverScreen(),
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
                // ── Background ────────────────────────────────────────
                _GameBackground(level: game.level),

                // ── Falling emojis ────────────────────────────────────
                ..._buildEmojis(game, screenSize),

                // ── Score popups ──────────────────────────────────────
                ..._buildScorePopups(),

                // ── HUD ───────────────────────────────────────────────
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

                // ── Level Up Banner ───────────────────────────────────
                if (_showLevelUp)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(child: LevelUpBanner(level: game.level)),
                    ),
                  ),

                // ── Slow Mo Button ────────────────────────────────────
                if (game.isPlaying && !game.slowMoActive)
                  Positioned(
                    bottom: 88,
                    right:  16,
                    child:  _SlowMoButton(
                      usesLeft: game.slowMoUsesLeft,
                      onTap:    () => _activateSlowMo(game),
                    ),
                  ),

                // ── Manual Pause Overlay ──────────────────────────────
                if (game.isPaused && !_pausedByNetwork)
                  _PauseOverlay(game: game),

                // ── Network Offline Game Overlay ──────────────────────
                // Appears automatically when connection drops mid-game.
                // Disappears and resumes when connection restores.
                if (_pausedByNetwork || (net.isOffline && !game.isPlaying && !game.isGameOver))
                  _NetworkGameOverlay(
                    status: net.status,
                    onRetry: () => net.refresh(),
                  ),

                // ── Network Banner (home / game over screens only) ────
                // During gameplay, the full overlay above handles it.
                if (!game.isPlaying && !_pausedByNetwork)
                  const NetworkBanner(),
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
    return _activeScoreEvents
        .map((d) => ScorePopup(
              key:     ValueKey(d.hashCode),
              points:  d.event.points,
              x:       d.event.x,
              y:       d.event.y,
              isCombo: d.event.isCombo,
            ))
        .toList();
  }
}

// ── Network Offline Overlay (mid-game) ────────────────────────────────────────
// Locks the game screen when connection drops. Auto-dismissed when back online.
class _NetworkGameOverlay extends StatelessWidget {
  final NetworkStatus  status;
  final VoidCallback   onRetry;

  const _NetworkGameOverlay({
    required this.status,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isNoInternet = status == NetworkStatus.noInternet;
    final icon    = isNoInternet ? '📡' : '📶';
    final title   = isNoInternet ? 'No Internet' : 'No Data';
    final body    = isNoInternet
        ? 'Connect to the internet\nto continue playing.'
        : 'Connected but no data.\nCheck your mobile data\nor WiFi connection.';
    final color   = isNoInternet
        ? const Color(0xFFB71C1C)
        : const Color(0xFFE65100);
    final border  = isNoInternet
        ? const Color(0xFFEF5350)
        : const Color(0xFFFF9800);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.92),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing icon
                Text(icon, style: const TextStyle(fontSize: 72))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end:   const Offset(1.12, 1.12),
                      duration: 1000.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 24),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize:   28,
                    fontWeight: FontWeight.w900,
                    color:      Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),

                // Body
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 15,
                    color:    Color(0xFFB0BEC5),
                    height:   1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(color: border.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Game paused — will resume automatically',
                    style: TextStyle(
                      fontSize:   11,
                      color:      Color(0xFF90A4AE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Retry button
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:      const Color(0xFFFFD700).withOpacity(0.3),
                          blurRadius: 20,
                          offset:     const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.black, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Check Connection',
                          style: TextStyle(
                            fontSize:   16,
                            fontWeight: FontWeight.w900,
                            color:      Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 250.ms)
          .scale(
            begin: const Offset(0.96, 0.96),
            end:   const Offset(1.0, 1.0),
            duration: 300.ms,
            curve: Curves.easeOut,
          ),
    );
  }
}

// ── Slow Mo Button ────────────────────────────────────────────────────────────
class _SlowMoButton extends StatelessWidget {
  final int          usesLeft;
  final VoidCallback onTap;
  const _SlowMoButton({required this.usesLeft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (usesLeft <= 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color:  AppColors.slowMoBlue.withOpacity(0.15),
          shape:  BoxShape.circle,
          border: Border.all(color: AppColors.slowMoBlue.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color:      AppColors.slowMoBlue.withOpacity(0.25),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text('🐢', style: TextStyle(fontSize: 28)),
            Positioned(
              top: 4, right: 4,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color:  AppColors.slowMoBlue,
                  shape:  BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                child: Center(
                  child: Text(
                    '$usesLeft',
                    style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end:   const Offset(1.06, 1.06),
          duration: 1400.ms,
          curve: Curves.easeInOut,
        );
  }
}

// ── Game Background ───────────────────────────────────────────────────────────
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
      child: CustomPaint(size: Size.infinite, painter: _StarfieldPainter(seed: level)),
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

// ── Pause Overlay ─────────────────────────────────────────────────────────────
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
                color: AppColors.primary.withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏸️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary, letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text('Score: ${game.score}', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 28),
              _btn('RESUME', '▶️', AppColors.primaryBtnGradient, Colors.black,
                  () => game.resumeGame()),
              const SizedBox(height: 12),
              _btn(
                'QUIT', '🏠',
                const LinearGradient(colors: [Color(0xFF2A2A4A), Color(0xFF1A1A35)]),
                Colors.white,
                () {
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

  Widget _btn(String label, String icon, Gradient gradient, Color textColor,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: textColor, letterSpacing: 1,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────
class _ScoreEventDisplay {
  final ScoreEvent event;
  final DateTime   expiry;
  _ScoreEventDisplay({required this.event, required this.expiry});
}
