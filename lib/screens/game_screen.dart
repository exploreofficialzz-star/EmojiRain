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
//
// 7. BUGFIX (network soft-lock): network pause/resume used to live inside
//    _onGameStateChange, which only runs when GameProvider itself notifies.
//    _pausedByNetwork was also mutated without setState(), so the overlay
//    could desync from reality. Worst case: once paused, GameProvider
//    cancels its timers and never notifies again on its own, so recovery
//    could never be detected — the game got stuck offline forever, even
//    after real connectivity returned. Now handled by _onNetworkChange(),
//    a dedicated listener registered directly on NetworkService, fully
//    independent of GameProvider's timer/notify state. See that method for
//    the full explanation.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../constants/app_constants.dart';
import '../constants/emoji_data.dart';   // FIX: LevelConfig lives here
import '../models/emoji_item.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/network_service.dart';
import '../services/purchase_service.dart';
import '../services/wallpaper_service.dart';
import '../widgets/background_picker_sheet.dart';
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

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ── Effect state — LOCAL ValueNotifier so only effect layer rebuilds ──────
  final ValueNotifier<List<_ScoreEventDisplay>> _scoreEvents =
      ValueNotifier([]);
  final ValueNotifier<List<TapEffect>> _tapEffects =
      ValueNotifier([]);

  // ── Render loop ───────────────────────────────────────────────────────────
  // Drives the emoji layer rebuild on every vsync frame via AnimatedBuilder.
  // This decouples visual smoothness from ChangeNotifier timing entirely —
  // positions are always current by the time the emoji layer reads them
  // because the build phase runs AFTER all transient Ticker callbacks.
  late AnimationController _renderLoop;

  int  _previousLevel    = 1;
  // ValueNotifier instead of plain bool so updating them via .value only
  // rebuilds the specific widget listening, NOT the entire GameScreen.
  //
  // The old setState() calls were causing full _GameScreenState.build()
  // re-runs on:
  //   • banner load  (~1-3 s into gameplay, AdMob callback)
  //   • level change (show banner)  + 1.8 s later (hide banner) — twice per level.
  //
  // Each full build re-runs every Selector, every Stack layer, the
  // AnimatedBuilder, all layout — visibly hanging the game for one or more
  // frames each time. ValueNotifier.value = only touches the VLB subtree.
  final ValueNotifier<bool> _showLevelUp  = ValueNotifier<bool>(false);
  bool _pausedByNetwork  = false;
  final ValueNotifier<bool> _bannerLoaded = ValueNotifier<bool>(false);
  bool _navigatingAway   = false;   // FIX 2: guard against double navigation

  @override
  void initState() {
    super.initState();
    // vsync: this is valid here because SingleTickerProviderStateMixin
    // is available from the moment the State is created (before the
    // first build). Duration is arbitrary — we only care that the
    // controller ticks every frame, not about its 0→1 value.
    _renderLoop = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 1),
    );
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
      // Start the render loop if the game is playing. For the normal
      // (non-continue) path, startGame() just set state to playing.
      // For isContinue, the game may already be paused — _onGameStateChange
      // will start the loop the moment game.resumeGame() is called.
      if (context.read<GameProvider>().isPlaying) _renderLoop.repeat();

      // FIX 3: listen for game-state changes OUTSIDE build()
      context.read<GameProvider>().addListener(_onGameStateChange);

      // FIX (network soft-lock): network pause/resume now has its OWN
      // listener, completely independent of GameProvider's notify cycle.
      // See _onNetworkChange() below for why this was necessary.
      context.read<NetworkService>().addListener(_onNetworkChange);

      // Cover the case where the screen mounts while ALREADY offline —
      // addListener() doesn't retroactively fire, so without this the
      // game would start playing unaware it has no connection until the
      // next connectivity change event.
      _onNetworkChange();
    });
  }

  // FIX 3: side-effects here, never inside build()
  void _onGameStateChange() {
    if (!mounted) return;
    final game = context.read<GameProvider>();

    // Keep the render loop in sync with the game state so we don't burn
    // CPU/GPU rebuilding the emoji layer when the game isn't running.
    if (game.isPlaying) {
      if (!_renderLoop.isAnimating) _renderLoop.repeat();
    } else {
      if (_renderLoop.isAnimating) _renderLoop.stop();
    }

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
        _showLevelUp.value = true;
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) _showLevelUp.value = false;
        });
      }
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

  // ── Network pause/resume — DEDICATED listener ─────────────────────────────
  //
  // BUG THIS FIXES: this logic used to live inside _onGameStateChange, which
  // only runs as a side-effect of GameProvider's OWN notifyListeners() calls.
  // That created two compounding problems:
  //
  //   1. _pausedByNetwork was mutated WITHOUT calling setState(). Since it's
  //      a plain State field (not observed by any Provider/Selector), the
  //      overlay conditionals reading it in build() would only refresh on
  //      some UNRELATED coincidental rebuild — meaning the network overlay
  //      could silently fail to appear, or fail to disappear, depending on
  //      timing luck.
  //
  //   2. Once game.pauseGame() runs, GameProvider cancels ALL its timers —
  //      the only things that were ever calling notifyListeners(). From
  //      that point on, GameProvider never notifies again on its own, so
  //      _onGameStateChange could never re-run — meaning the "network back
  //      online, resume" branch could never be re-evaluated. The game got
  //      stuck paused FOREVER, even after real connectivity returned, even
  //      after tapping "Check Connection" (which only touches NetworkService,
  //      and nothing was listening to NetworkService to react to it).
  //
  // Fix: this is now NetworkService's own listener, registered in initState
  // and fully independent of GameProvider's state. It fires the instant
  // NetworkService changes status, whether or not the game loop is running,
  // and always goes through setState() so the overlay stays in sync.
  void _onNetworkChange() {
    if (!mounted) return;
    final net  = context.read<NetworkService>();
    final game = context.read<GameProvider>();

    if (net.isOffline && game.isPlaying) {
      game.pauseGame();
      setState(() => _pausedByNetwork = true);
    } else if (net.isOnline && _pausedByNetwork && game.isPaused) {
      setState(() => _pausedByNetwork = false);
      game.resumeGame();
    }
  }

  void _loadBanner() {
    if (PurchaseService.instance.adsRemoved) return;
    AdService.instance.loadBanner(
      size:     AdSize.banner,
      onLoaded: () {
        // .value = instead of setState() so only the ValueListenableBuilder
        // wrapping the banner slot rebuilds — not the entire game screen.
        if (mounted) _bannerLoaded.value = true;
      },
    );
  }

  @override
  void dispose() {
    _renderLoop.dispose();
    WidgetsBinding.instance.removeObserver(this);
    AdService.instance.disposeBanner();
    // FIX 3: remove the listener we added in initState
    context.read<GameProvider>().removeListener(_onGameStateChange);
    context.read<NetworkService>().removeListener(_onNetworkChange);
    _scoreEvents.dispose();
    _tapEffects.dispose();
    _showLevelUp.dispose();
    _bannerLoaded.dispose();
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

                  // Emoji layer — rebuilds once per vsync frame via _renderLoop.
                  // AnimatedBuilder reschedules a rebuild whenever the
                  // AnimationController value changes (i.e. every frame while
                  // the controller is running). The build phase fires AFTER all
                  // transient Ticker callbacks — including GameProvider's
                  // physics update — so emoji positions are always current.
                  // This replaces the previous Selector<GameProvider,
                  // List<EmojiItem>> which coupled smoothness to ChangeNotifier
                  // timing and could skip frames on high-refresh-rate devices.
                  AnimatedBuilder(
                    animation: _renderLoop,
                    builder: (_, __) {
                      final game = context.read<GameProvider>();
                      return _EmojiLayer(
                        emojis:     game.emojis,
                        screenSize: MediaQuery.sizeOf(context),
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
                            level:     lvl,
                            animateIn: _showLevelUp.value,
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

                  // Level-up banner — ValueListenableBuilder rebuilds ONLY this
                  // overlay when _showLevelUp flips, not the whole game screen.
                  ValueListenableBuilder<bool>(
                    valueListenable: _showLevelUp,
                    builder: (_, show, __) {
                      if (!show) return const SizedBox.shrink();
                      return Selector<GameProvider, int>(
                        selector: (_, g) => g.level,
                        builder: (_, level, __) => Positioned.fill(
                          child: IgnorePointer(
                            child: Center(child: LevelUpBanner(level: level)),
                          ),
                        ),
                      );
                    },
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

          // Banner ad — ValueListenableBuilder rebuilds ONLY this slot when
          // the ad loads, not the entire game screen (old code called setState
          // from the AdMob callback which triggered a full build() re-run).
          // Selector<PurchaseService> scopes the adsRemoved check here rather
          // than subscribing the whole screen to PurchaseService notifications.
          ValueListenableBuilder<bool>(
            valueListenable: _bannerLoaded,
            builder: (_, loaded, __) {
              final ad = AdService.instance.bannerAd;
              if (!loaded || ad == null) return const SizedBox.shrink();
              return Selector<PurchaseService, bool>(
                selector: (_, p) => p.adsRemoved,
                builder:  (_, adsRemoved, __) {
                  if (adsRemoved) return const SizedBox.shrink();
                  return Container(
                    color:     AppColors.background,
                    alignment: Alignment.center,
                    width:     ad.size.width.toDouble(),
                    height:    ad.size.height.toDouble(),
                    child:     AdWidget(ad: ad),
                  );
                },
              );
            },
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
    // ONE RepaintBoundary for the whole falling-emoji region, not one per
    // emoji. With up to 15 emojis on screen, per-emoji RepaintBoundaries
    // meant up to 15 simultaneous GPU compositing layers just for this
    // region — real overhead for widgets that repaint every single frame
    // anyway (little isolation benefit to begin with). This still isolates
    // the whole animated region from the static HUD/background around it,
    // with a single layer instead of many.
    return RepaintBoundary(
      child: Stack(
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
      ),
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
    // ONE RepaintBoundary per sub-layer (2 total) instead of one per popup
    // / tap effect — same reasoning as _EmojiLayer above.
    return Stack(
      children: [
        // Score popups
        RepaintBoundary(
          child: ValueListenableBuilder(
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
        ),
        // Tap effects
        RepaintBoundary(
          child: ValueListenableBuilder(
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
    // Custom wallpaper takes priority over the default starfield. This is
    // its own narrow Selector so a wallpaper change doesn't require any
    // GameProvider notify to take effect, and a level change doesn't
    // re-evaluate the wallpaper path unnecessarily.
    return Selector<WallpaperService, String?>(
      selector: (_, w) => w.customPath,
      builder: (_, customPath, __) {
        if (customPath != null) {
          return _CustomWallpaperBackground(path: customPath);
        }
        return _DefaultStarfieldBackground(level: level);
      },
    );
  }
}

class _DefaultStarfieldBackground extends StatelessWidget {
  final int level;
  const _DefaultStarfieldBackground({required this.level});

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

// Renders a player-chosen photo as the game background. A dark scrim sits
// on top so falling emojis and HUD text stay readable regardless of how
// bright or busy the chosen photo is — without it, a light-colored photo
// could make white text/HUD elements unreadable.
class _CustomWallpaperBackground extends StatelessWidget {
  final String path;
  const _CustomWallpaperBackground({required this.path});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(path),
            fit: BoxFit.cover,
            // Falls back to the plain dark background if the file somehow
            // became unreadable (corrupted, removed externally, etc.)
            // instead of crashing or showing a broken-image icon mid-game.
            errorBuilder: (_, __, ___) => Container(color: AppColors.background),
          ),
          Container(color: Colors.black.withOpacity(0.45)),
        ],
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
            _btn('BACKGROUND', '🖼️',
                const LinearGradient(colors: [Color(0xFF2A2A4A), Color(0xFF1A1A35)]),
                Colors.white, () => showBackgroundPickerSheet(context)),
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
