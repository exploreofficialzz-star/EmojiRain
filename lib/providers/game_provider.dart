import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/emoji_data.dart';
import '../constants/app_constants.dart';
import '../models/emoji_item.dart';
import '../services/audio_service.dart';
import 'dart:async';

// ─── Game States ──────────────────────────────────────────────────────────────
enum GameState { idle, playing, paused, gameOver }

// ─── Score Event (popup) ──────────────────────────────────────────────────────
class ScoreEvent {
  final int    points;
  final double x;
  final double y;
  final bool   isCombo;
  ScoreEvent({required this.points, required this.x, required this.y, this.isCombo = false});
}

// ─── GameProvider ─────────────────────────────────────────────────────────────
class GameProvider extends ChangeNotifier {
  // ── Core state ────────────────────────────────────────────────────────────
  GameState _state    = GameState.idle;
  List<EmojiItem> _emojis = [];
  int    _score       = 0;
  int    _highScore   = 0;
  int    _combo       = 0;
  int    _maxCombo    = 0;
  int    _level       = 1;
  int    _failCount   = 0;
  bool   _showInterstitial = false;
  bool   _showRewarded     = false;
  String _failMessage = '';
  String _tappedEmoji = '';

  List<ScoreEvent> _scoreEvents = [];

  Timer? _gameTimer;
  Timer? _spawnTimer;

  LevelConfig _currentLevel = LevelData.getLevel(1);

  double _screenWidth   = 390;
  double _screenHeight  = 844;
  double _spawnAccum    = 0.0;
  double _currentSpeed  = GameConstants.speedBase;

  final Random _rng = Random();

  // ── Getters ───────────────────────────────────────────────────────────────
  GameState        get state        => _state;
  List<EmojiItem>  get emojis       => List.unmodifiable(_emojis);
  int              get score        => _score;
  int              get highScore    => _highScore;
  int              get combo        => _combo;
  int              get maxCombo     => _maxCombo;
  int              get level        => _level;
  bool             get isPlaying    => _state == GameState.playing;
  bool             get isGameOver   => _state == GameState.gameOver;
  bool             get shouldShowInterstitial => _showInterstitial;
  bool             get shouldShowRewarded     => _showRewarded;
  String           get failMessage  => _failMessage;
  String           get tappedEmoji  => _tappedEmoji;
  LevelConfig      get currentLevel => _currentLevel;
  List<ScoreEvent> get scoreEvents  => List.unmodifiable(_scoreEvents);

  int get comboMultiplier {
    if (_combo >= GameConstants.combo10x) return 10;
    if (_combo >= GameConstants.combo5x)  return 5;
    if (_combo >= GameConstants.combo3x)  return 3;
    if (_combo >= GameConstants.combo2x)  return 2;
    return 1;
  }

  // ── Init ──────────────────────────────────────────────────────────────────
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

    _state          = GameState.playing;
    _score          = 0;
    _combo          = 0;
    _maxCombo       = 0;
    _level          = 1;
    _emojis         = [];
    _scoreEvents    = [];
    _spawnAccum     = 0.0;
    _currentSpeed   = GameConstants.speedBase;
    _showInterstitial = false;
    _showRewarded   = false;
    _currentLevel   = LevelData.getLevel(1);

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
    _state   = GameState.idle;
    _emojis  = [];
    _scoreEvents = [];
    notifyListeners();
  }

  /// ── Rewarded Ad: CONTINUE from exact game state ──────────────────────────
  /// Score, level, combo are all preserved. Only emojis on screen are cleared
  /// (they were mid-fall when the ad started) and the loop restarts.
  void continueAfterRewardedAd() {
    _emojis       = [];
    _spawnAccum   = 0.0;
    _state        = GameState.playing;
    _showRewarded = false;
    _startLoop();
    AudioService.instance.resumeBgm();
    notifyListeners();
  }

  void consumeInterstitialFlag() {
    _showInterstitial = false;
    notifyListeners();
  }

  // ── Game Loop ─────────────────────────────────────────────────────────────
  void _startLoop() {
    _stopTimers();
    _gameTimer  = Timer.periodic(const Duration(milliseconds: 16), (_) => _update(0.016));
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 40), (_) => _maybeSpawn());
  }

  void _stopTimers() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _gameTimer = _spawnTimer = null;
  }

  void _update(double dt) {
    if (_state != GameState.playing) return;

    // ── Continuously grow speed every frame — never resets, never decreases
    _currentSpeed = (_currentSpeed + GameConstants.speedGrowthRate * dt)
        .clamp(GameConstants.speedBase, GameConstants.speedMax);

    for (final e in _emojis) {
      if (e.isFalling) e.y += e.speed * dt;
    }

    _checkMisses();

    // Remove emojis that have scrolled far off screen
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
      if (_level >= 5 && _rng.nextBool()) _spawnEmoji();
      if (_level >= 10 && _rng.nextDouble() < 0.5) _spawnEmoji();
    }
  }

  void _spawnEmoji() {
    final lvl = _currentLevel;
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

    final size  = GameConstants.emojiSizeBase * lvl.emojiSizeMultiplier;
    final speed = _currentSpeed;

    _emojis.add(EmojiItem.spawn(
      emoji: emoji,
      category: category,
      isTarget: isTarget,
      screenWidth: _screenWidth,
      emojiSize: size,
      speed: speed,
      rng: _rng,
    ));
  }

  String _catOf(String emoji) {
    for (final e in EmojiPool.byCategory.entries) {
      if (e.value.contains(emoji)) return e.key;
    }
    return 'misc';
  }

  // ── Miss Detection ────────────────────────────────────────────────────────
  void _checkMisses() {
    for (final e in _emojis) {
      if (!e.isFalling) continue;
      if (e.y <= _screenHeight + e.size / 2) continue;

      e.state = EmojiState.missed;

      if (e.isTarget) {
        _failMessage = FailMessages.getForMissedTarget(e.emoji);
        _tappedEmoji = e.emoji;
        AudioService.instance.play(SoundEffect.gameover);
        _triggerGameOver();
        return;
      }
    }
  }

  // ── Tap Handling ──────────────────────────────────────────────────────────
  void onEmojiTapped(EmojiItem emoji) {
    if (_state != GameState.playing) return;
    if (!emoji.isFalling) return;

    emoji.state = EmojiState.tapped;

    if (emoji.isTarget) {
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      final pts = 10 * comboMultiplier;
      _score += pts;

      _scoreEvents.add(ScoreEvent(
        points: pts, x: emoji.x, y: emoji.y,
        isCombo: _combo >= GameConstants.combo2x,
      ));

      AudioService.instance.play(
        _combo >= GameConstants.combo2x ? SoundEffect.combo : SoundEffect.correct,
      );

      if (_score >= _levelUpThreshold) _levelUp();

    } else {
      _tappedEmoji = emoji.emoji;
      _failMessage = FailMessages.getForWrongTap(emoji.emoji);
      AudioService.instance.play(SoundEffect.wrong);
      _triggerGameOver();
    }
  }

  int get _levelUpThreshold => _currentLevel.targetScore + (_level - 1) * GameConstants.scorePerLevel;

  void _levelUp() {
    _level++;
    _currentLevel = LevelData.getLevel(_level);
    _spawnAccum   = 0.0;
    if (_currentSpeed < _currentLevel.baseSpeed) {
      _currentSpeed = _currentLevel.baseSpeed.clamp(
        GameConstants.speedBase, GameConstants.speedMax,
      );
    }
    AudioService.instance.play(SoundEffect.levelup);
    notifyListeners();
  }

  void _triggerGameOver() {
    _stopTimers();
    _state = GameState.gameOver;
    AudioService.instance.stopBgm();
    _failCount++;
    _saveHighScore();

    _showInterstitial = true;
    _showRewarded = _score >= 20;

    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get fakeStat {
    final pct = max(1, 100 - (_level * 6 + _score ~/ 60)).clamp(1, 96);
    return 'Only $pct% of players survived level $_level';
  }

  bool get isNewHighScore => _score > 0 && _score >= _highScore;

  void clearScoreEvents() => _scoreEvents.clear();

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
