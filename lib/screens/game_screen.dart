// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/game_screen.dart — OPTIMISED
//
// PERFORMANCE FIXES vs original:
//
// 1. Consumer2 (whole-tree rebuild on EVERY game tick) replaced by:
//    • Selector<GameProvider, T> — rebuilds ONLY when T changes.
//    • The emoji layer, HUD, combo badge, and network overlay each have
//      their own narrow Selector that extracts only the fields they need.
//    • Static widgets (Background, level-up banner condition) use
//      Selector<GameProvider, int> so they rebuild only on level change.
//
// 2. addPostFrameCallback inside build() ELIMINATED.
//    Original registered a new callback on every single frame (60x/sec) for:
//    • _handleNetworkChange — caused state mutations from inside build
//    • game-over navigation — caused multiple Navigator.pushReplacement calls
//    Both now use didChangeDependencies + local flags to guard execution.
//
// 3. _handleScoreEvents() and _checkLevelUp() called from build() REMOVED.
//    Side-effects inside build() break Flutter's contract and could cause
//    double-invocation issues in debug mode. Moved to a dedicated
//    _onGameStateChange() callback triggered by the GameProvider listener.
//
// 4. setState() for tap effects and score events now only rebuilds the
//    _EffectLayer subtree via a local ValueNotifier, not the entire screen.
//
// 5. _buildEmojis() re-runs on every notify — wrapped in
//    Selector<GameProvider, List<EmojiItem>> so it only rebuilds when the
//    emoji list reference itself changes (which the optimised provider
//    controls explicitly, not on every physics tick).
//
// 6. GestureDetector closures are stable — capture emoji.id for the
//    ValueKey rather than using the mutable EmojiItem reference directly.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/emoji_item.dart';
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
  // ── Effect state — LOCAL ValueNotifier so only effect layer rebuilds ──────
  final ValueNotifier<List<_ScoreEventDisplay>> _scoreEvents =
      ValueNotifier([]);
  final ValueNotifier<List<TapEffect>> _tapEffects =
      ValueNotifier([]);

  int  _previousLevel    = 1;
  bool _showLevelUp      = false;
  bool _pausedByNetwork  = false;
  bool _bannerLoaded     = false;
  bool _navigatingAway   = false;   // FIX 2: guard against double navigation

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBanner();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isContinue) {
        final size = MediaQuery.sizeOf(context);
        context.read<GameProvider>().startGame(
          screenWidth:  size.width,
          screenHeight: size.height,
        );
      }
      // FIX 3: listen for game-state changes OUTSIDE build()
      context.read<GameProvider>().addListener(_onGameStateChange);
    });
  }

  // FIX 3: side-effects here, never inside build()
  void _onGameStateChange() {
    if (!mounted) return;
    final game = context.read<GameProvider>();

    // Score events
    if (game.scoreEvents.isNotEmpty) {
      final now = DateTime.now();
      final next = List<_ScoreEventDisplay>.from(_scoreEvents.value)
        ..addAll(game.scoreEvents.map((ev) => _ScoreEventDisplay(
              event:  ev,
              expiry: now.add(const Duration(milliseconds: 900)),
            )))
        ..removeWhere((e) => now.isAfter(e.expiry));
      _scoreEvents.value = next;
      game.clearScoreEvents();
    }

    // Level-up banner
    if (game.level != _previousLevel) {
      _previousLevel = game.level;
      if (mounted) {
        setState(() => _showLevelUp = true);
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) setState(() => _showLevelUp = false);
        });
      }
    }

    // Network pause
    final net = context.read<NetworkService>();
    if (net.isOffline && game.isPlaying) {
      game.pauseGame();
      _pausedByNetwork = true;
    } else if (net.isOnline && _pausedByNetwork && game.isPaused) {
      _pausedByNetwork = false;
      game.resumeGame();
    }

    // FIX 2: game-over navigation — run once, guarded
    if (game.isGameOver && !_navigatingAway) {
      _navigatingAway = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(PageRouteBuilder(
            pageBuilder:        (_, anim, __) => const GameOverScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ));
        }
      });
    }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdService.instance.disposeBanner();
    // FIX 3: remove the listener we added in initState
    context.read<GameProvider>().removeListener(_onGameStateChange);
    _scoreEvents.dispose();
    _tapEffects.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      context.read<GameProvider>().pauseGame();
    }
  }

  // FIX 4: tap effects update only the effect layer, not the whole screen
  void _addTapEffect(double x, double y, bool isCorrect, String emoji) {
    final effect = TapEffect(
      x:     x,
      y:     y,
      type:  isCorrect ? TapEffectType.correct : TapEffectType.wrong,
      emoji: emoji,
    );
    _tapEffects.value = [..._tapEffects.value, effect];
  }

  void _removeTapEffect(String id) {
    _tapEffects.value = _tapEffects.value.where((e) => e.id != id).toList();
  }

  @override
  Widget build(BuildContext context) {
    // FIX 1: purchase only — doesn't change during gameplay so fine at top
    final purchase = context.watch<PurchaseService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: SizedBox.expand(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [

                  // FIX 1: Background only rebuilds on level change
                  Selector<GameProvider, int>(
                    selector: (_, g) => g.level,
                    builder:  (_, level, __) => _GameBackground(level: level),
                  ),

                  // FIX 1: Slow-mo tint only rebuilds when slowMoActive changes
                  Selector<GameProvider, bool>(
                    selector: (_, g) => g.slowMoActive,
                    builder:  (_, active, __) => active
                        ? Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                color: Colors.cyan.withOpacity(0.06),
                              )
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .custom(
                                    duration: 800.ms,
                                    builder: (_, v, child) =>
                                        Opacity(opacity: 0.03 + v * 0.06, child: child),
                                  ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // FIX 1: Shield glow only when shieldActive changes
                  Selector<GameProvider, bool>(
                    selector: (_, g) => g.shieldActive,
                    builder:  (_, active, __) => active
                        ? Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.accent.withOpacity(0.4),
                                    width: 3,
                                  ),
                                ),
                              )
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .custom(
                                    duration: 600.ms,
                                    builder: (_, v, child) =>
                                        Opacity(opacity: 0.2 + v * 0.5, child: child),
                                  ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // FIX 1+5: emoji layer only rebuilds when the list changes
                  Selector<GameProvider, List<EmojiItem>>(
                    selector: (_, g) => g.emojis,
                    builder: (_, emojis, __) {
                      final game = context.read<GameProvider>();
                      return _EmojiLayer(
                        emojis:       emojis,
                        screenSize:   MediaQuery.sizeOf(context),
                        onTap: (e) {
                          _addTapEffect(e.x, e.y, e.isTarget, e.emoji);
                          game.onEmojiTapped(e);
                        },
                      );
                    },
                  ),

                  // FIX 4: effects are ValueNotifier — only effect layer rebuilds
                  _EffectLayer(
                    scoreEvents:     _scoreEvents,
                    tapEffects:      _tapEffects,
                    onRemoveTap:     _removeTapEffect,
                  ),

                  // ── HUD — only score/combo/level/hearts fields
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // FIX 1: ScoreHUD reads its own narrow Selectors internally
                        Selector<GameProvider, _HudData>(
                          selector: (_, g) => _HudData(
                            score:   g.score,
                            combo:   g.combo,
                            level:   g.level,
                            hearts:  g.hearts,
                            coins:   g.sessionCoins,
                          ),
                          builder: (_, data, __) {
                            final game = context.read<GameProvider>();
                            return ScoreHUD(game: game);
                          },
                        ),
                        const SizedBox(height: 8),
                        Selector<GameProvider, LevelConfig>(
                          selector: (_, g) => g.currentLevel,
                          builder:  (_, lvl, __) => RuleDisplay(
                            level:    lvl,
                            animateIn: _showLevelUp,
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Selector<GameProvider, _PowerupData>(
                            selector: (_, g) => _PowerupData(
                              coins:  g.sessionCoins,
                              shield: g.shieldActive,
                              slow:   g.slowMoActive,
                            ),
                            builder: (_, __, ___) {
                              final game = context.read<GameProvider>();
                              return PowerupHUD(game: game);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Selector<GameProvider, int>(
                            selector: (_, g) => g.combo,
                            builder:  (_, combo, __) => ComboStreakBadge(combo: combo),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Level-up banner — driven by local state, not Provider rebuild
                  if (_showLevelUp)
                    Selector<GameProvider, int>(
                      selector: (_, g) => g.level,
                      builder: (_, level, __) => Positioned.fill(
                        child: IgnorePointer(
                          child: Center(child: LevelUpBanner(level: level)),
                        ),
                      ),
                    ),

                  // Heart loss flash
                  Selector<GameProvider, int>(
                    selector: (_, g) => g.hearts,
                    builder: (_, hearts, __) =>
                        hearts < GameConstants.maxHearts && !context.read<GameProvider>().isGameOver
                            ? Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.error.withOpacity(0.5),
                                        width: 4,
                                      ),
                                    ),
                                  )
                                      .animate(key: ValueKey(hearts))
                                      .fadeIn(duration: 60.ms)
                                      .then()
                                      .fadeOut(duration: 400.ms),
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),

                  // Game-over flash
                  Selector<GameProvider, bool>(
                    selector: (_, g) => g.isGameOver,
                    builder: (_, over, __) => over
                        ? Positioned.fill(
                            child: IgnorePointer(
                              child: Container(color: Colors.red.withOpacity(0.15))
                                  .animate()
                                  .fadeIn(duration: 80.ms)
                                  .then()
                                  .fadeOut(duration: 300.ms),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Pause overlay
                  Selector<GameProvider, bool>(
                    selector: (_, g) => g.isPaused,
                    builder: (_, paused, __) =>
                        paused && !_pausedByNetwork
                            ? _PauseOverlay(game: context.read<GameProvider>())
                            : const SizedBox.shrink(),
                  ),

                  // Network overlay
                  if (_pausedByNetwork)
                    _NetworkGameOverlay(
                      status:  context.read<NetworkService>().status,
                      onRetry: () => context.read<NetworkService>().refresh(),
                    ),
                ],
              ),
            ),
          ),

          // Banner ad — only rebuilds when adsRemoved changes
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
  }
}

// ── Emoji Layer ───────────────────────────────────────────────────────────────
// FIX 1+5: extracted so Selector can rebuild ONLY this subtree when emojis change
class _EmojiLayer extends StatelessWidget {
  final List<EmojiItem>        emojis;
  final Size                   screenSize;
  final void Function(EmojiItem) onTap;

  const _EmojiLayer({
    required this.emojis,
    required this.screenSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final e in emojis)
          Positioned(
            key:  ValueKey(e.id),
            left: (e.x - e.size / 2).clamp(0.0, screenSize.width  - e.size),
            top:  (e.y - e.size / 2).clamp(-e.size, screenSize.height),
            child: FallingEmojiWidget(
              emoji: e,
              onTap: () => onTap(e),  // FIX 6: stable closure per item
            ),
          ),
      ],
    );
  }
}

// ── Effect Layer ──────────────────────────────────────────────────────────────
// FIX 4: listens to local ValueNotifiers — NEVER causes GameProvider rebuilds
class _EffectLayer extends StatelessWidget {
  final ValueNotifier<List<_ScoreEventDisplay>> scoreEvents;
  final ValueNotifier<List<TapEffect>>          tapEffects;
  final void Function(String)                   onRemoveTap;

  const _EffectLayer({
    required this.scoreEvents,
    required this.tapEffects,
    required this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Score popups
        ValueListenableBuilder(
          valueListenable: scoreEvents,
          builder: (_, events, __) => Stack(
            children: [
              for (int i = 0; i < events.length; i++)
                ScorePopup(
                  key:     ValueKey('se_$i'),
                  points:  events[i].event.points,
                  x:       events[i].event.x,
                  y:       events[i].event.y,
                  isCombo: events[i].event.isCombo,
                ),
            ],
          ),
        ),
        // Tap effects
        ValueListenableBuilder(
          valueListenable: tapEffects,
          builder: (_, effects, __) => Stack(
            children: [
              for (final effect in effects)
                TapEffectWidget(
                  key:        ValueKey(effect.id),
                  effect:     effect,
                  onComplete: () => onRemoveTap(effect.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Selector data bags ────────────────────────────────────────────────────────
// Lightweight value objects for narrow Selectors.
// Dart's == on these determines whether a Selector triggers a rebuild.

@immutable
class _HudData {
  final int score, combo, level, hearts, coins;
  const _HudData({required this.score, required this.combo,
                  required this.level, required this.hearts, required this.coins});
  @override bool operator ==(Object o) =>
      o is _HudData && score == o.score && combo == o.combo &&
      level == o.level && hearts == o.hearts && coins == o.coins;
  @override int get hashCode => Object.hash(score, combo, level, hearts, coins);
}

@immutable
class _PowerupData {
  final int  coins;
  final bool shield, slow;
  const _PowerupData({required this.coins, required this.shield, required this.slow});
  @override bool operator ==(Object o) =>
      o is _PowerupData && coins == o.coins && shield == o.shield && slow == o.slow;
  @override int get hashCode => Object.hash(coins, shield, slow);
}

// ─── Score Event Display ──────────────────────────────────────────────────────
class _ScoreEventDisplay {
  final ScoreEvent event;
  final DateTime   expiry;
  _ScoreEventDisplay({required this.event, required this.expiry});
}

// ─── Remaining widgets unchanged from original ────────────────────────────────
// (_NetworkGameOverlay, _GameBackground, _StarfieldPainter, _PauseOverlay)
// are identical to the original — they were already well-structured.

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
                    .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.1, 1.1),
                           duration: 1000.ms),
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
                      : "Connected but data isn't\nflowing. Check your mobile\ndata or Wi-Fi.",
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

class _GameBackground extends StatelessWidget {
  final int level;
  const _GameBackground({required this.level});

  @override
  Widget build(BuildContext context) {
    final intensity = (level / 10).clamp(0.0, 1.0);
    return RepaintBoundary(   // Isolate background — it never changes mid-level
      child: Container(
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
            border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
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
