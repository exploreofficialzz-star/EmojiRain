import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/emoji_data.dart';
import '../constants/app_constants.dart';
import '../models/emoji_item.dart';
import '../services/audio_service.dart';
import 'dart:async';

// ── Game State Machine ────────────────────────────────────────────────────────
enum GameState {
  idle,
  playing,
  paused,
  wrongTap,   // wrong emoji tapped — game paused, rewarded ad offer shown
  gameOver,
}

// ── Score event (floating +pts popup) ────────────────────────────────────────
class ScoreEvent {
  final int    points;
  final double x;
  final double y;
  final bool   isCombo;
  ScoreEvent({
    required this.points,
    required this.x,
    required this.y,
    this.isCombo = false,
  });
}

// ── Provider ──────────────────────────────────────────────────────────────────
class GameProvider extends ChangeNotifier {
  // ── Core state ─────────────────────────────────────────────────────────────
  GameState       _state   = GameState.idle;
  List<EmojiItem> _emojis  = [];
  int    _score            = 0;
  int    _highScore        = 0;
  int    _combo            = 0;
  int    _maxCombo         = 0;
  int    _level            = 1;
  int    _failCount        = 0;
  bool   _showInterstitial = false;
  String _failMessage      = '';
  String _tappedEmoji      = '';

  List<ScoreEvent> _scoreEvents = [];

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _gameTimer;
  Timer? _spawnTimer;
  Timer? _levelTimer;
  int    _levelSecondsLeft = 60;

  LevelConfig _currentLevel = LevelData.getLevel(1);

  double _screenWidth  = 390;
  double _screenHeight = 844;
  double _spawnAccum   = 0.0;
  double _currentSpeed = GameConstants.speedBase;

  final Random _rng = Random();

  // ── Wrong Tap Lives ────────────────────────────────────────────────────────
  // Player gets 3 wrong taps per session.
  // Each wrong tap pauses game and offers a rewarded ad to continue.
  // Accepting → watch ad → game resumes (life consumed).
  // Declining or skipping → real game over.
  int _continuesLeft = GameConstants.maxWrongTaps;

  // ── Slow Mo Power-Up ──────────────────────────────────────────────────────
  // Activated by watching a rewarded ad during gameplay.
  // Slows all emojis to 30% speed for 10 seconds.
  bool   _slowMoActive    = false;
  int    _slowMoSecondsLeft = 0;
  int    _slowMoUsesLeft  = GameConstants.maxSlowMoPerSession;
  Timer? _slowMoTimer;

  // ── Getters ───────────────────────────────────────────────────────────────
  GameState        get state            => _state;
  List<EmojiItem>  get emojis           => List.unmodifiable(_emojis);
  int              get score            => _score;
  int              get highScore        => _highScore;
  int              get combo            => _combo;
  int              get maxCombo         => _maxCombo;
  int              get level            => _level;
  int              get levelSecondsLeft => _levelSecondsLeft;
  bool             get isPlaying        => _state == GameState.playing;
  bool             get isGameOver       => _state == GameState.gameOver;
  bool             get isWrongTap       => _state == GameState.wrongTap;
  bool             get shouldShowInterstitial => _showInterstitial;
  String           get failMessage      => _failMessage;
  String           get tappedEmoji      => _tappedEmoji;
  LevelConfig      get currentLevel     => _currentLevel;
  List<ScoreEvent> get scoreEvents      => List.unmodifiable(_scoreEvents);

  // Lives
  int  get continuesLeft  => _continuesLeft;
  int  get continuesUsed  => GameConstants.maxWrongTaps - _continuesLeft;

  // Slow Mo
  bool get slowMoActive       => _slowMoActive;
  int  get slowMoSecondsLeft  => _slowMoSecondsLeft;
  int  get slowMoUsesLeft     => _slowMoUsesLeft;
  bool get canActivateSlowMo  =>
      _slowMoUsesLeft > 0 && !_slowMoActive && _state == GameState.playing;

  int get comboMultiplier {
    if (_combo >= GameConstants.combo10x) return 10;
    if (_combo >= GameConstants.combo5x)  return 5;
    if (_combo >= GameConstants.combo3x)  return 3;
    if (_combo >= GameConstants.combo2x)  return 2;
    return 1;
  }

  GameProvider() { _loadHighScore(); }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('high_score') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (_score > _highScore) {
      _highScore = _score;
      await prefs.setInt('high_score', _highScore);
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  void startGame({double? screenWidth, double? screenHeight}) {
    if (screenWidth  != null) _screenWidth  = screenWidth;
    if (screenHeight != null) _screenHeight = screenHeight;

    _state            = GameState.playing;
    _score            = 0;
    _combo            = 0;
    _maxCombo         = 0;
    _level            = 1;
    _emojis           = [];
    _scoreEvents      = [];
    _spawnAccum       = 0.0;
    _currentSpeed     = GameConstants.speedBase;
    _levelSecondsLeft = 60;
    _showInterstitial = false;
    _currentLevel     = LevelData.getLevel(1);
    _failMessage      = '';
    _tappedEmoji      = '';

    // ── Reset lives & slow mo ──────────────────────────────────────────────
    _continuesLeft     = GameConstants.maxWrongTaps;
    _slowMoActive      = false;
    _slowMoSecondsLeft = 0;
    _slowMoUsesLeft    = GameConstants.maxSlowMoPerSession;
    _slowMoTimer?.cancel();
    _slowMoTimer = null;

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
    _slowMoTimer?.cancel();
    _slowMoTimer = null;
    AudioService.instance.stopBgm();
    startGame(screenWidth: _screenWidth, screenHeight: _screenHeight);
  }

  void goHome() {
    _stopTimers();
    _slowMoTimer?.cancel();
    _slowMoTimer = null;
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

  // ── Wrong Tap Lives ────────────────────────────────────────────────────────

  /// Called after player successfully watches the full rewarded ad.
  /// Consumes one continue, clears wrong emojis, and resumes.
  void continueAfterWrongTap() {
    if (_state != GameState.wrongTap) return;

    _continuesLeft--;

    // Remove any non-falling emojis (the one they tapped + any missed)
    _emojis.removeWhere((e) => !e.isFalling);

    _state = GameState.playing;
    _startLoop();
    AudioService.instance.resumeBgm();
    notifyListeners();
  }

  /// Called when player declines to watch the ad or ad isn't available.
  void declineWrongTapContinue() {
    if (_state != GameState.wrongTap) return;
    _triggerGameOver();
  }

  // ── Slow Mo Power-Up ──────────────────────────────────────────────────────

  /// Called after player successfully watches the rewarded ad for slow mo.
  void activateSlowMo() {
    if (!canActivateSlowMo) return;

    _slowMoUsesLeft--;
    _slowMoActive      = true;
    _slowMoSecondsLeft = GameConstants.slowMoSeconds;

    // Immediately slow all currently falling emojis
    final slowSpeed = _currentSpeed * GameConstants.slowMoFactor;
    for (final e in _emojis) {
      if (e.isFalling) e.speed = slowSpeed;
    }

    // Tick down the slow mo countdown every second
    _slowMoTimer?.cancel();
    _slowMoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_slowMoActive) {
        _slowMoTimer?.cancel();
        return;
      }
      _slowMoSecondsLeft--;
      if (_slowMoSecondsLeft <= 0) {
        _endSlowMo();
      } else {
        notifyListeners();
      }
    });

    AudioService.instance.play(SoundEffect.levelup); // re-use existing sfx
    notifyListeners();
  }

  void _endSlowMo() {
    _slowMoActive      = false;
    _slowMoSecondsLeft = 0;
    _slowMoTimer?.cancel();
    _slowMoTimer = null;

    // Restore emojis to current (un-slowed) speed
    for (final e in _emojis) {
      if (e.isFalling) e.speed = _currentSpeed;
    }
    notifyListeners();
  }

  // ── Game Loop ─────────────────────────────────────────────────────────────
  void _startLoop() {
    _stopTimers();
    _stopwatch
      ..reset()
      ..start();

    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final ms = _stopwatch.elapsedMilliseconds;
      _stopwatch.reset();
      _update((ms / 1000.0).clamp(0.005, 0.05));
    });

    _spawnTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => _maybeSpawn(),
    );

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

  void _stopTimers() {
    _stopwatch.stop();
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _levelTimer?.cancel();
    _gameTimer = _spawnTimer = _levelTimer = null;
  }

  void _update(double dt) {
    if (_state != GameState.playing) return;

    // Advance base speed (slow mo doesn't affect the base; it's a display layer)
    _currentSpeed = (_currentSpeed + GameConstants.speedGrowthRate * dt)
        .clamp(GameConstants.speedBase, GameConstants.speedMax);

    // Effective speed emojis should be moving at right now
    final effectiveSpeed = _slowMoActive
        ? _currentSpeed * GameConstants.slowMoFactor
        : _currentSpeed;

    for (final e in _emojis) {
      if (e.isFalling) {
        e.speed = effectiveSpeed;
        e.y    += e.speed * dt;
      }
    }

    _checkMisses();
    _emojis.removeWhere((e) => !e.isFalling && e.y > _screenHeight + e.size * 3);
    notifyListeners();
  }

  void _maybeSpawn() {
    if (_state != GameState.playing) return;

    final fallingCount = _emojis.where((e) => e.isFalling).length;
    if (fallingCount >= GameConstants.maxEmojisOnScreen) return;

    _spawnAccum += 0.04;
    if (_spawnAccum >= _currentLevel.spawnInterval) {
      _spawnAccum = 0.0;
      _spawnEmoji();
      if (_level >= 2  && _rng.nextBool())          _spawnEmoji();
      if (_level >= 4  && _rng.nextBool())          _spawnEmoji();
      if (_level >= 6  && _rng.nextDouble() < 0.6)  _spawnEmoji();
      if (_level >= 9  && _rng.nextDouble() < 0.5)  _spawnEmoji();
      if (_level >= 12 && _rng.nextDouble() < 0.4)  _spawnEmoji();
    }
  }

  void _spawnEmoji() {
    final lvl      = _currentLevel;
    final isTarget = _rng.nextInt(lvl.emojiMix + 1) == 0;

    String emoji;
    String category;

    if (isTarget) {
      switch (lvl.ruleType) {
        case RuleType.tapSpecific:
          emoji    = lvl.targetEmoji!;
          category = _catOf(emoji);
        case RuleType.avoidSpecific:
          final pool = List<String>.from(EmojiPool.allEmojis)..remove(lvl.targetEmoji);
          emoji    = pool[_rng.nextInt(pool.length)];
          category = _catOf(emoji);
        case RuleType.tapCategory:
          final pool = EmojiPool.byCategory[lvl.targetCategory] ?? EmojiPool.allEmojis;
          emoji    = pool[_rng.nextInt(pool.length)];
          category = lvl.targetCategory!;
        case RuleType.avoidCategory:
          final avoid = EmojiPool.byCategory[lvl.targetCategory] ?? [];
          final pool  = EmojiPool.allEmojis.where((e) => !avoid.contains(e)).toList();
          emoji    = pool.isEmpty ? '😊' : pool[_rng.nextInt(pool.length)];
          category = _catOf(emoji);
      }
    } else {
      switch (lvl.ruleType) {
        case RuleType.tapSpecific:
          final pool = List<String>.from(EmojiPool.allEmojis)..remove(lvl.targetEmoji);
          emoji    = pool[_rng.nextInt(pool.length)];
          category = _catOf(emoji);
        case RuleType.avoidSpecific:
          emoji    = lvl.targetEmoji!;
          category = _catOf(emoji);
        case RuleType.tapCategory:
          final avoid = EmojiPool.byCategory[lvl.targetCategory] ?? [];
          final pool  = EmojiPool.allEmojis.where((e) => !avoid.contains(e)).toList();
          emoji    = pool.isEmpty ? '💀' : pool[_rng.nextInt(pool.length)];
          category = _catOf(emoji);
        case RuleType.avoidCategory:
          final pool = EmojiPool.byCategory[lvl.targetCategory] ?? EmojiPool.allEmojis;
          emoji    = pool[_rng.nextInt(pool.length)];
          category = lvl.targetCategory!;
      }
    }

    final effectiveSpeed = _slowMoActive
        ? _currentSpeed * GameConstants.slowMoFactor
        : _currentSpeed;

    _emojis.add(EmojiItem.spawn(
      emoji:       emoji,
      category:    category,
      isTarget:    isTarget,
      screenWidth: _screenWidth,
      emojiSize:   GameConstants.emojiSizeBase * lvl.emojiSizeMultiplier,
      speed:       effectiveSpeed,
      rng:         _rng,
    ));
  }

  String _catOf(String emoji) {
    for (final e in EmojiPool.byCategory.entries) {
      if (e.value.contains(emoji)) return e.key;
    }
    return 'misc';
  }

  void _checkMisses() {
    for (final e in _emojis) {
      if (!e.isFalling) continue;
      if (e.y <= _screenHeight + e.size / 2) continue;

      e.state = EmojiState.missed;

      if (e.isTarget) {
        // Missing a target = instant game over (no lifeline)
        _failMessage = FailMessages.getForMissedTarget(e.emoji);
        _tappedEmoji = e.emoji;
        AudioService.instance.play(SoundEffect.gameover);
        _triggerGameOver();
        return;
      }
    }
  }

  // ── Tap Handler ───────────────────────────────────────────────────────────
  void onEmojiTapped(EmojiItem emoji) {
    if (_state != GameState.playing) return;
    if (!emoji.isFalling) return;

    emoji.state = EmojiState.tapped;

    if (emoji.isTarget) {
      // ── Correct tap ──────────────────────────────────────────────────────
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;

      final pts = 10 * comboMultiplier;
      _score += pts;

      _scoreEvents.add(ScoreEvent(
        points:  pts,
        x:       emoji.x,
        y:       emoji.y,
        isCombo: _combo >= GameConstants.combo2x,
      ));

      AudioService.instance.play(
        _combo >= GameConstants.combo2x ? SoundEffect.combo : SoundEffect.correct,
      );

    } else {
      // ── Wrong tap ─────────────────────────────────────────────────────────
      _tappedEmoji = emoji.emoji;
      _failMessage = FailMessages.getForWrongTap(emoji.emoji);
      _combo       = 0; // reset combo on wrong tap
      AudioService.instance.play(SoundEffect.wrong);

      if (_continuesLeft > 0) {
        // Pause game and offer rewarded ad continue
        _state = GameState.wrongTap;
        _stopTimers();
        // Pause slow mo timer too if active
        if (_slowMoActive) {
          _slowMoTimer?.cancel();
          _slowMoTimer = null;
        }
        AudioService.instance.pauseBgm();
        notifyListeners();
      } else {
        // All 3 continues exhausted — real game over
        _triggerGameOver();
      }
    }
  }

  void _levelUp() {
    _level++;
    _currentLevel     = LevelData.getLevel(_level);
    _spawnAccum       = 0.0;
    _levelSecondsLeft = 60;
    if (_currentSpeed < _currentLevel.baseSpeed) {
      _currentSpeed = _currentLevel.baseSpeed.clamp(
        GameConstants.speedBase,
        GameConstants.speedMax,
      );
    }
    AudioService.instance.play(SoundEffect.levelup);
    notifyListeners();
  }

  void _triggerGameOver() {
    _stopTimers();
    _slowMoTimer?.cancel();
    _slowMoTimer   = null;
    _slowMoActive  = false;
    _state         = GameState.gameOver;
    AudioService.instance.stopBgm();
    _failCount++;
    _saveHighScore();
    _showInterstitial = true;
    notifyListeners();
  }

  // ── Utility ───────────────────────────────────────────────────────────────
  String get fakeStat {
    final pct = max(1, 100 - (_level * 6 + _score ~/ 60)).clamp(1, 96);
    return 'Only $pct% of players survived level $_level';
  }

  bool get isNewHighScore => _score > 0 && _score >= _highScore;

  void clearScoreEvents() => _scoreEvents.clear();

  @override
  void dispose() {
    _stopTimers();
    _slowMoTimer?.cancel();
    super.dispose();
  }
}
