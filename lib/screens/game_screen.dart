import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/network_service.dart';
import '../services/purchase_service.dart';
import '../widgets/falling_emoji_widget.dart';
import '../widgets/powerup_hud.dart';
import '../widgets/rule_display.dart';
import '../widgets/score_hud.dart';
import '../widgets/tap_effect_widget.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  final bool isContinue;
  const GameScreen({super.key, this.isContinue = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  int  _previousLevel   = 1;
  bool _showLevelUp     = false;
  bool _pausedByNetwork = false;
  bool _bannerLoaded    = false;

  final List<_ScoreEventDisplay> _activeScoreEvents = [];
  final List<TapEffect>          _tapEffects        = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBanner();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initGame());
  }

  void _loadBanner() {
    if (PurchaseService.instance.adsRemoved) return;
    AdService.instance.loadBanner(
      size:     AdSize.banner,
      onLoaded: () {
        if (mounted) setState(() => _bannerLoaded = true);
      },
    );
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
    AdService.instance.disposeBanner();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      context.read<GameProvider>().pauseGame();
    }
  }

  void _handleNetworkChange(GameProvider game, NetworkService net) {
    if (net.isOffline && game.isPlaying) {
      game.pauseGame();
      _pausedByNetwork = true;
    } else if (net.isOnline && _pausedByNetwork && game.isPaused) {
      _pausedByNetwork = false;
      game.resumeGame();
    }
  }

  void _addTapEffect(double x, double y, bool isCorrect, String emoji) {
    final effect = TapEffect(
      x:     x,
      y:     y,
      type:  isCorrect ? TapEffectType.correct : TapEffectType.wrong,
      emoji: emoji,
    );
    setState(() => _tapEffects.add(effect));
  }

  void _removeTapEffect(String id) {
    if (mounted) setState(() => _tapEffects.removeWhere((e) => e.id == id));
  }

  void _checkLevelUp(GameProvider game) {
    if (game.level == _previousLevel) return;
    _previousLevel = game.level;
    setState(() => _showLevelUp = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showLevelUp = false);
    });
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
    final purchase   = context.watch<PurchaseService>();

    return Consumer2<GameProvider, NetworkService>(
      builder: (context, game, net, _) {
        _checkLevelUp(game);
        _handleScoreEvents(game);

        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleNetworkChange(game, net),
        );

        if (game.isGameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && game.isGameOver) {
              Navigator.of(context).pushReplacement(PageRouteBuilder(
                pageBuilder:        (_, anim, __) => const GameOverScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 400),
              ));
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // ── Game Area ────────────────────────────────────────────
              Expanded(
                child: SizedBox.expand(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // ── Background ─────────────────────────────────
                      _GameBackground(level: game.level),

                      // ── Slow-Mo tint overlay ───────────────────────
                      if (game.slowMoActive)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              color: Colors.cyan.withOpacity(0.06),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                             .custom(
                               duration: 800.ms,
                               builder: (_, v, child) => Opacity(
                                 opacity: 0.03 + v * 0.06,
                                 child: child,
                               ),
                             ),
                          ),
                        ),

                      // ── Shield glow on wrong-tap absorb ────────────
                      if (game.shieldActive)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.accent.withOpacity(0.4),
                                  width: 3,
                                ),
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                             .custom(
                               duration: 600.ms,
                               builder: (_, v, child) => Opacity(
                                 opacity: 0.2 + v * 0.5,
                                 child: child,
                               ),
                             ),
                          ),
                        ),

                      // ── Falling emojis ─────────────────────────────
                      ..._buildEmojis(game, screenSize),

                      // ── Score popups ───────────────────────────────
                      ..._buildScorePopups(),

                      // ── Tap effect animations ──────────────────────
                      ..._tapEffects.map((effect) => TapEffectWidget(
                            key:        ValueKey(effect.id),
                            effect:     effect,
                            onComplete: () => _removeTapEffect(effect.id),
                          )),

                      // ── HUD ────────────────────────────────────────
                      SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            ScoreHUD(game: game),
                            const SizedBox(height: 8),
                            RuleDisplay(
                              level:     game.currentLevel,
                              animateIn: _showLevelUp,
                            ),
                            const Spacer(),

                            // ── Feature 4: Power-Up HUD ───────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical:   10,
                              ),
                              child: PowerupHUD(game: game),
                            ),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ComboStreakBadge(combo: game.combo),
                            ),
                          ],
                        ),
                      ),

                      // ── Level Up Banner ────────────────────────────
                      if (_showLevelUp)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: LevelUpBanner(level: game.level),
                            ),
                          ),
                        ),

                      // ── Heart Loss Flash (red border, not full screen) ─
                      if (!game.isGameOver && game.hearts < GameConstants.maxHearts)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.error.withOpacity(0.5),
                                  width: 4,
                                ),
                              ),
                            )
                                .animate(key: ValueKey(game.hearts))
                                .fadeIn(duration: 60.ms)
                                .then()
                                .fadeOut(duration: 400.ms),
                          ),
                        ),

                      // ── Game Over flash ────────────────────────────
                      if (game.isGameOver)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(color: Colors.red.withOpacity(0.15))
                                .animate()
                                .fadeIn(duration: 80.ms)
                                .then()
                                .fadeOut(duration: 300.ms),
                          ),
                        ),

                      // ── Manual Pause Overlay ───────────────────────
                      if (game.isPaused && !_pausedByNetwork)
                        _PauseOverlay(game: game),

                      // ── Network Offline Overlay ────────────────────
                      if (_pausedByNetwork)
                        _NetworkGameOverlay(
                          status:  net.status,
                          onRetry: () => net.refresh(),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Banner Ad ─────────────────────────────────────────
              if (_bannerLoaded &&
                  AdService.instance.bannerAd != null &&
                  !purchase.adsRemoved)
                Container(
                  color:     AppColors.background,
                  alignment: Alignment.center,
                  width:  AdService.instance.bannerAd!.size.width.toDouble(),
                  height: AdService.instance.bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: AdService.instance.bannerAd!),
                ),
            ],
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
          onTap: () {
            _addTapEffect(e.x, e.y, e.isTarget, e.emoji);
            game.onEmojiTapped(e);
          },
        ),
      );
    }).toList();
  }

  List<Widget> _buildScorePopups() {
    return _activeScoreEvents.map((d) => ScorePopup(
      key:     ValueKey(d.hashCode),
      points:  d.event.points,
      x:       d.event.x,
      y:       d.event.y,
      isCombo: d.event.isCombo,
    )).toList();
  }
}

// ── Network Offline Overlay ───────────────────────────────────────────────────
class _NetworkGameOverlay extends StatelessWidget {
  final NetworkStatus status;
  final VoidCallback  onRetry;
  const _NetworkGameOverlay({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isNoInternet = status == NetworkStatus.noInternet;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.93),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isNoInternet ? '📡' : '📶',
                    style: const TextStyle(fontSize: 70))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end:   const Offset(1.1, 1.1),
                      duration: 1000.ms,
                    ),
                const SizedBox(height: 24),
                Text(
                  isNoInternet ? 'No Internet Connection' : 'No Data Available',
                  style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isNoInternet
                      ? 'Connect to Wi-Fi or enable\nmobile data to continue.'
                      : 'Connected but data isn\'t\nflowing. Check your mobile\ndata or Wi-Fi.',
                  style: const TextStyle(
                    fontSize: 15, color: Color(0xFFB0BEC5), height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    '⏸  Game paused — resumes automatically',
                    style: TextStyle(fontSize: 11, color: Color(0xFF78909C)),
                  ),
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                    decoration: BoxDecoration(
                      gradient:     AppColors.primaryBtnGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color:      AppColors.primary.withOpacity(0.3),
                        blurRadius: 20, offset: const Offset(0, 6),
                      )],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.black, size: 22),
                        SizedBox(width: 8),
                        Text('Check Connection', style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black,
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 250.ms),
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
              color: AppColors.primary.withOpacity(0.4), width: 1.5,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⏸️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('PAUSED', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary, letterSpacing: 3,
            )),
            const SizedBox(height: 8),
            Text('Score: ${game.score}', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 4),
            // Show hearts in pause overlay
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(GameConstants.maxHearts, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  i < game.hearts ? '❤️' : '🖤',
                  style: const TextStyle(fontSize: 18),
                ),
              )),
            ),
            const SizedBox(height: 28),
            _btn('RESUME', '▶️', AppColors.primaryBtnGradient, Colors.black,
                () => game.resumeGame()),
            const SizedBox(height: 12),
            _btn('QUIT', '🏠',
                const LinearGradient(colors: [Color(0xFF2A2A4A), Color(0xFF1A1A35)]),
                Colors.white, () {
              game.goHome();
              Navigator.of(context).popUntil((r) => r.isFirst);
            }),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _btn(String label, String icon, Gradient gradient,
      Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          gradient: gradient, borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800,
            color: textColor, letterSpacing: 1,
          )),
        ]),
      ),
    );
  }
}

class _ScoreEventDisplay {
  final ScoreEvent event;
  final DateTime   expiry;
  _ScoreEventDisplay({required this.event, required this.expiry});
}
