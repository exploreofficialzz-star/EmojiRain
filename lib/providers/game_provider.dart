import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../constants/emoji_data.dart';
import '../models/emoji_item.dart';
import '../services/audio_service.dart';
import '../services/coin_service.dart';

enum GameState { idle, playing, paused, gameOver }

class ScoreEvent {
  final int    points;
  final double x;
  final double y;
  final bool   isCombo;
  ScoreEvent({required this.points, required this.x, required this.y, this.isCombo = false});
}

class GameProvider extends ChangeNotifier {
  // ── Core game state ───────────────────────────────────────────────────────
  GameState        _state        = GameState.idle;
  List<EmojiItem>  _emojis       = [];
  List<ScoreEvent> _scoreEvents  = [];
  int    _score             = 0;
  int    _highScore         = 0;
  int    _combo             = 0;
  int    _maxCombo          = 0;
  int    _level             = 1;
  int    _failCount         = 0;
  int    _levelSecondsLeft  = 60;
  bool   _showInterstitial  = false;
  bool   _showRewarded      = false;
  String _failMessage       = '';
  String _tappedEmoji       = '';

  // ── Feature 1: Hearts ────────────────────────────────────────────────────
  int  _hearts        = GameConstants.maxHearts;

  // ── Feature 2: Coins ─────────────────────────────────────────────────────
  int  _sessionCoins  = 0;
  bool _highScoreBonusAwarded = false;

  // ── Feature 4: Power-Ups ─────────────────────────────────────────────────
  bool   _shieldActive   = false;
  bool   _slowMoActive   = false;
  double _preSlowMoSpeed = GameConstants.speedBase;
  Timer? _slowMoTimer;

  // ── Internals ─────────────────────────────────────────────────────────────
  LevelConfig _currentLevel = LevelData.getLevel(1);
  double _screenWidth       = 390;
  double _screenHeight      = 844;
  double _spawnAccum        = 0.0;
  double _currentSpeed      = GameConstants.speedBase;
  final  Random _rng        = Random();

  // Game loop clock — driven by a Ticker (a per-frame, vsync-synced
  // callback), not Timer.periodic. Timer.periodic runs on the Dart
  // event-loop timer wheel, which has no fixed relationship to the
  // engine's actual frame schedule: its callbacks can land early, late,
  // or in bursts relative to what's actually being rendered. In practice
  // that shows up as emojis appearing to hitch and jump in small
  // increments ("stepping") instead of gliding — especially on 90/120Hz
  // screens, where a fixed 16ms period is out of phase with the true
  // per-frame interval. Ticker instead hooks directly into
  // SchedulerBinding's per-frame callback (the same mechanism
  // AnimationController itself uses), so _onTick fires exactly once per
  // rendered frame with an accurate elapsed-time delta — the correct way
  // to drive continuous motion in Flutter.
  Ticker?  _ticker;
  Duration _lastTick = Duration.zero;
  Timer?   _spawnTimer;
  Timer?   _levelTimer;

  // ── Getters ───────────────────────────────────────────────────────────────
  GameState        get state                  => _state;
  // NOTE: must allocate a NEW List.unmodifiable(...) on every call, not a
  // cached/stable reference. EmojiItem fields (x/y/etc.) are mutated in
  // place each tick rather than the list being rebuilt, so GameScreen's
  // Selector<GameProvider, List<EmojiItem>> relies on getting a
  // different object identity each notify to know it must rebuild and
  // repaint the new positions. An "optimized" cached/identical reference
  // here would make the Selector stop rebuilding and freeze the falling
  // animation in place.
  List<EmojiItem>  get emojis                 => List.unmodifiable(_emojis);
  List<ScoreEvent> get scoreEvents            => List.unmodifiable(_scoreEvents);
  int              get score                  => _score;
  int              get highScore              => _highScore;
  int              get combo                  => _combo;
  int              get maxCombo               => _maxCombo;
  int              get level                  => _level;
  int              get levelSecondsLeft       => _levelSecondsLeft;
  int              get hearts                 => _hearts;
  int              get maxHearts              => GameConstants.maxHearts;
  int              get sessionCoins           => _sessionCoins;
  bool             get shieldActive           => _shieldActive;
  bool             get slowMoActive           => _slowMoActive;
  bool             get isPlaying              => _state == GameState.playing;
  bool             get isPaused               => _state == GameState.paused;
  bool             get isGameOver             => _state == GameState.gameOver;
  bool             get shouldShowInterstitial => _showInterstitial;
  bool             get shouldShowRewarded     => _showRewarded;
  String           get failMessage            => _failMessage;
  String           get tappedEmoji            => _tappedEmoji;
  LevelConfig      get currentLevel           => _currentLevel;
  bool             get isNewHighScore         => _score > 0 && _score >= _highScore;

  int get comboMultiplier {
    if (_combo >= GameConstants.combo10x) return 10;
    if (_combo >= GameConstants.combo5x)  return 5;
    if (_combo >= GameConstants.combo3x)  return 3;
    if (_combo >= GameConstants.combo2x)  return 2;
    return 1;
  }

  String get fakeStat {
    final pct = max(1, 100 - (_level * 6 + _score ~/ 60)).clamp(1, 96);
    return 'Only $pct% of players survived level $_level';
  }

  GameProvider() { _loadHighScore(); }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore  = prefs.getInt('high_score') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    if (_score <= _highScore) return;
    _highScore = _score;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('high_score', _highScore);
    if (!_highScoreBonusAwarded) {
      _highScoreBonusAwarded = true;
      _sessionCoins += GameConstants.coinsNewHighScore;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────
  void startGame({double? screenWidth, double? screenHeight}) {
    if (screenWidth  != null) _screenWidth  = screenWidth;
    if (screenHeight != null) _screenHeight = screenHeight;

    _state                 = GameState.playing;
    _score                 = 0;
    _combo                 = 0;
    _maxCombo              = 0;
    _level                 = 1;
    _emojis                = [];
    _scoreEvents           = [];
    _spawnAccum            = 0.0;
    _currentSpeed          = GameConstants.speedBase;
    _levelSecondsLeft      = 60;
    _showInterstitial      = false;
    _showRewarded          = false;
    _currentLevel          = LevelData.getLevel(1);
    _failMessage           = '';
    _tappedEmoji           = '';
    _hearts                = GameConstants.maxHearts;
    _sessionCoins          = 0;
    _highScoreBonusAwarded = false;
    _shieldActive          = false;
    _slowMoActive          = false;
    _slowMoTimer?.cancel();
    _slowMoTimer           = null;

    _startLoop();
    AudioService.instance.startBgm();
    notifyListeners();
  }

  void pauseGame() {
    if (_state != GameState.playing) return;
    _state = GameState.paused;
    _stopTimers();
    AudioService.instance.pauseBgm();
    notifyListeners();
  }

  void resumeGame() {
    if (_state != GameState.paused) return;
    _state = GameState.playing;
    _startLoop();
    AudioService.instance.resumeBgm();
    notifyListeners();
  }

  void retryGame() {
    _stopTimers();
    AudioService.instance.stopBgm();
    startGame(screenWidth: _screenWidth, screenHeight: _screenHeight);
  }

  void goHome() {
    _stopTimers();
    AudioService.instance.stopBgm();
    _state       = GameState.idle;
    _emojis      = [];
    _scoreEvents = [];
    notifyListeners();
  }

  void consumeInterstitialFlag() {
    _showInterstitial = false;
    notifyListeners();
  }

  void continueAfterRewardedAd() {
    _emojis.clear();
    _scoreEvents.clear();
    _spawnAccum       = 0;
    _showRewarded     = false;
    _showInterstitial = false;
    _hearts           = GameConstants.maxHearts;
    _shieldActive     = false;
    _slowMoActive     = false;
    _state            = GameState.playing;
    _startLoop();
    AudioService.instance.startBgm();
    notifyListeners();
  }

  void clearScoreEvents() => _scoreEvents.clear();

  // ── Feature 4: Power-Up Activation ───────────────────────────────────────
  Future<bool> activateSlowMo() async {
    if (_state != GameState.playing || _slowMoActive) return false;
    final spent = await CoinService.instance.spendCoins(GameConstants.slowMoCost);
    if (!spent) return false;

    _preSlowMoSpeed = _currentSpeed;
    _currentSpeed   = _currentSpeed * GameConstants.slowMoFactor;
    _slowMoActive   = true;
    _slowMoTimer?.cancel();
    _slowMoTimer = Timer(GameConstants.slowMoDuration, () {
      if (_state == GameState.playing) {
        _currentSpeed = _preSlowMoSpeed;
        _slowMoActive = false;
        notifyListeners();
      }
    });
    notifyListeners();
    return true;
  }

  Future<bool> activateShield() async {
    if (_state != GameState.playing || _shieldActive) return false;
    final spent = await CoinService.instance.spendCoins(GameConstants.shieldCost);
    if (!spent) return false;
    _shieldActive = true;
    notifyListeners();
    return true;
  }

  Future<bool> activateClearWave() async {
    if (_state != GameState.playing) return false;
    final spent = await CoinService.instance.spendCoins(GameConstants.clearWaveCost);
    if (!spent) return false;
    _emojis.removeWhere((e) => e.isFalling && !e.isTarget);
    notifyListeners();
    return true;
  }

  // ── Game Loop — physics on a Ticker (vsync), spawn/level on Timer ─────────
  // Spawning a new emoji and ticking the 1-second level countdown are
  // discrete periodic events, not continuous motion — Timer.periodic
  // remains the right tool for those. Only the per-frame position update
  // needed to move from Timer to Ticker.
  void _startLoop() {
    _stopTimers();

    _lastTick = Duration.zero;
    _ticker   = Ticker(_onTick, debugLabel: 'GameProvider physics')..start();

    _spawnTimer = Timer.periodic(
        const Duration(milliseconds: 40), (_) => _maybeSpawn());

    _levelTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state != GameState.playing) return;
      _levelSecondsLeft--;
      if (_levelSecondsLeft <= 0) {
        _levelSecondsLeft = 60;
        _levelUp();
      } else {
        notifyListeners();
      }
    });
  }

  // Fires once per rendered frame, timestamped by the engine itself, so
  // dt is always the real elapsed time since the previous frame — motion
  // stays smooth and correct regardless of the device's actual refresh rate.
  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    // Cap dt so a stall (a slow frame, a brief hiccup) can't make physics
    // leap forward in one huge jump. No floor is needed — a genuine
    // per-frame delta from the engine is never negative or artificially
    // tiny the way a jittery wall-clock timer's could be.
    _update(dt.clamp(0.0, 0.05));
  }

  void _stopTimers() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _spawnTimer?.cancel();
    _levelTimer?.cancel();
    _slowMoTimer?.cancel();
    _spawnTimer = _levelTimer = null;
  }

  // ── _update — per-frame physics step, unchanged other than its caller ─────
  // (formula itself is dt-scaled and was already correct; only the timing
  // source that supplies dt changed — see _onTick above)
  void _update(double dt) {
    if (_state != GameState.playing) return;

    if (!_slowMoActive) {
      _currentSpeed = (_currentSpeed + GameConstants.speedGrowthRate * dt)
          .clamp(GameConstants.speedBase, GameConstants.speedMax);
    }

    for (final e in _emojis) {
      if (e.isFalling) { e.speed = _currentSpeed; e.y += _currentSpeed * dt; }
    }

    _checkMisses();
    _emojis.removeWhere((e) => !e.isFalling && e.y > _screenHeight + e.size * 3);
    notifyListeners();
  }

  // ── Spawn — original, unchanged ───────────────────────────────────────────
  void _maybeSpawn() {
    if (_state != GameState.playing) return;
    if (_emojis.where((e) => e.isFalling).length >= GameConstants.maxEmojisOnScreen) return;

    _spawnAccum += 0.04;
    if (_spawnAccum < _currentLevel.spawnInterval) return;
    _spawnAccum = 0.0;

    _spawnEmoji();
    if (_level >= 2  && _rng.nextBool())         _spawnEmoji();
    if (_level >= 4  && _rng.nextBool())         _spawnEmoji();
    if (_level >= 6  && _rng.nextDouble() < 0.6) _spawnEmoji();
    if (_level >= 9  && _rng.nextDouble() < 0.5) _spawnEmoji();
    if (_level >= 12 && _rng.nextDouble() < 0.4) _spawnEmoji();
  }

  void _spawnEmoji() {
    final lvl      = _currentLevel;
    final isTarget = _rng.nextInt(lvl.emojiMix + 1) == 0;
    String emoji; String category;

    if (isTarget) {
      switch (lvl.ruleType) {
        case RuleType.tapSpecific:
          emoji = lvl.targetEmoji!; category = _catOf(emoji);
        case RuleType.avoidSpecific:
          final p = List<String>.from(EmojiPool.allEmojis)..remove(lvl.targetEmoji);
          emoji = p[_rng.nextInt(p.length)]; category = _catOf(emoji);
        case RuleType.tapCategory:
          final p = EmojiPool.byCategory[lvl.targetCategory] ?? EmojiPool.allEmojis;
          emoji = p[_rng.nextInt(p.length)]; category = lvl.targetCategory!;
        case RuleType.avoidCategory:
          final av = EmojiPool.byCategory[lvl.targetCategory] ?? [];
          final p  = EmojiPool.allEmojis.where((e) => !av.contains(e)).toList();
          emoji = p.isEmpty ? '😊' : p[_rng.nextInt(p.length)]; category = _catOf(emoji);
      }
    } else {
      switch (lvl.ruleType) {
        case RuleType.tapSpecific:
          final p = List<String>.from(EmojiPool.allEmojis)..remove(lvl.targetEmoji);
          emoji = p[_rng.nextInt(p.length)]; category = _catOf(emoji);
        case RuleType.avoidSpecific:
          emoji = lvl.targetEmoji!; category = _catOf(emoji);
        case RuleType.tapCategory:
          final av = EmojiPool.byCategory[lvl.targetCategory] ?? [];
          final p  = EmojiPool.allEmojis.where((e) => !av.contains(e)).toList();
          emoji = p.isEmpty ? '💀' : p[_rng.nextInt(p.length)]; category = _catOf(emoji);
        case RuleType.avoidCategory:
          final p = EmojiPool.byCategory[lvl.targetCategory] ?? EmojiPool.allEmojis;
          emoji = p[_rng.nextInt(p.length)]; category = lvl.targetCategory!;
      }
    }

    _emojis.add(EmojiItem.spawn(
      emoji: emoji, category: category, isTarget: isTarget,
      screenWidth: _screenWidth,
      emojiSize:   GameConstants.emojiSizeBase * lvl.emojiSizeMultiplier,
      speed: _currentSpeed, rng: _rng,
    ));
  }

  String _catOf(String e) {
    for (final entry in EmojiPool.byCategory.entries) {
      if (entry.value.contains(e)) return entry.key;
    }
    return 'misc';
  }

  void _checkMisses() {
    for (final e in _emojis) {
      if (!e.isFalling || e.y <= _screenHeight + e.size / 2) continue;
      e.state = EmojiState.missed;
      if (e.isTarget) {
        if (_shieldActive) {
          _shieldActive = false;
          notifyListeners();
          return;
        }
        _hearts--;
        _combo       = 0;
        _failMessage = FailMessages.getForMissedTarget(e.emoji);
        _tappedEmoji = e.emoji;
        if (_hearts <= 0) {
          AudioService.instance.play(SoundEffect.gameover);
          _triggerGameOver();
        } else {
          AudioService.instance.play(SoundEffect.wrong);
          notifyListeners();
        }
        return;
      }
    }
  }

  void onEmojiTapped(EmojiItem emoji) {
    if (_state != GameState.playing || !emoji.isFalling) return;
    emoji.state = EmojiState.tapped;

    if (emoji.isTarget) {
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;

      final pts = 10 * comboMultiplier;
      _score += pts;
      _sessionCoins += GameConstants.coinsPerTap * comboMultiplier;

      _scoreEvents.add(ScoreEvent(
        points: pts, x: emoji.x, y: emoji.y,
        isCombo: _combo >= GameConstants.combo2x,
      ));
      AudioService.instance.play(
        _combo >= GameConstants.combo2x ? SoundEffect.combo : SoundEffect.correct,
      );
    } else {
      if (_shieldActive) {
        _shieldActive = false;
        notifyListeners();
        return;
      }
      _hearts--;
      _combo       = 0;
      _tappedEmoji = emoji.emoji;
      _failMessage = FailMessages.getForWrongTap(emoji.emoji);

      if (_hearts <= 0) {
        AudioService.instance.play(SoundEffect.wrong);
        _triggerGameOver();
      } else {
        AudioService.instance.play(SoundEffect.wrong);
        notifyListeners();
      }
    }
  }

  void _levelUp() {
    _level++;
    _currentLevel     = LevelData.getLevel(_level);
    _spawnAccum       = 0.0;
    _levelSecondsLeft = 60;
    if (_currentSpeed < _currentLevel.baseSpeed) {
      _currentSpeed = _currentLevel.baseSpeed
          .clamp(GameConstants.speedBase, GameConstants.speedMax);
    }
    _sessionCoins += GameConstants.coinsPerLevelUp * _level;
    AudioService.instance.play(SoundEffect.levelup);
    notifyListeners();
  }

  void _triggerGameOver() {
    _stopTimers();
    _state     = GameState.gameOver;
    _failCount++;
    _slowMoTimer?.cancel();
    AudioService.instance.stopBgm();
    _saveHighScore();

    if (_sessionCoins > 0) {
      CoinService.instance.addCoins(_sessionCoins);
    }

    _showInterstitial = true;
    _showRewarded     = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
