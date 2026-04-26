import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/emoji_data.dart';
import '../constants/app_constants.dart';
import '../models/emoji_item.dart';
import '../services/audio_service.dart';

// ─── Game States ──────────────────────────────────────────────────────────────
enum GameState { idle, playing, paused, gameOver }

// ─── Score Event (for combo popups) ──────────────────────────────────────────
class ScoreEvent {
  final int points;
  final double x;
  final double y;
  final bool isCombo;
  ScoreEvent({required this.points, required this.x, required this.y, this.isCombo = false});
}

// ─── GameProvider ─────────────────────────────────────────────────────────────
class GameProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  GameState _state    = GameState.idle;
  List<EmojiItem> _emojis = [];
  int  _score         = 0;
  int  _highScore     = 0;
  int  _lives         = GameConstants.maxLives;
  int  _combo         = 0;
  int  _maxCombo      = 0;
  int  _level         = 1;
  int  _failCount     = 0;   // for ad frequency
  int  _correctCount  = 0;   // correct taps this level
  bool _showInterstitial = false;
  bool _showRewarded     = false;
  String _failMessage    = '';
  String _tappedEmoji    = '';

  // Score popups
  List<ScoreEvent> _scoreEvents = [];

  // Timers
  Timer? _gameTimer;
  Timer? _spawnTimer;

  // Level config
  LevelConfig _currentLevel = LevelData.getLevel(1);

  // Screen dimensions (set when game starts)
  double _screenWidth  = 390;
  double _screenHeight = 844;

  double _spawnAccum   = 0.0;
  final Random _rng    = Random();

  // ── Getters ────────────────────────────────────────────────────────────────
  GameState get state         => _state;
  List<EmojiItem> get emojis  => List.unmodifiable(_emojis);
  int get score               => _score;
  int get highScore           => _highScore;
  int get lives               => _lives;
  int get combo               => _combo;
  int get maxCombo            => _maxCombo;
  int get level               => _level;
  int get failCount           => _failCount;
  bool get isPlaying          => _state == GameState.playing;
  bool get isGameOver         => _state == GameState.gameOver;
  bool get shouldShowInterstitial => _showInterstitial;
  bool get shouldShowRewarded     => _showRewarded;
  String get failMessage      => _failMessage;
  String get tappedEmoji      => _tappedEmoji;
  LevelConfig get currentLevel => _currentLevel;
  List<ScoreEvent> get scoreEvents => List.unmodifiable(_scoreEvents);

  int get comboMultiplier {
    if (_combo >= GameConstants.combo10x) return 10;
    if (_combo >= GameConstants.combo5x)  return 5;
    if (_combo >= GameConstants.combo3x)  return 3;
    if (_combo >= GameConstants.combo2x)  return 2;
    return 1;
  }

  // ── Initialisation ─────────────────────────────────────────────────────────
  GameProvider() {
    _loadHighScore();
  }

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

  // ── Game Lifecycle ─────────────────────────────────────────────────────────
  void startGame({double? screenWidth, double? screenHeight, int startLevel = 1}) {
    if (screenWidth  != null) _screenWidth  = screenWidth;
    if (screenHeight != null) _screenHeight = screenHeight;

    _state    = GameState.playing;
    _score    = 0;
    _lives    = GameConstants.maxLives;
    _combo    = 0;
    _maxCombo = 0;
    _level    = startLevel;
    _correctCount = 0;
    _emojis   = [];
    _scoreEvents  = [];
    _spawnAccum   = 0.0;
    _showInterstitial = false;
    _showRewarded     = false;
    _currentLevel = LevelData.getLevel(_level);

    _startGameLoop();
    notifyListeners();
  }

  void pauseGame() {
    if (_state != GameState.playing) return;
    _state = GameState.paused;
    _stopTimers();
    notifyListeners();
  }

  void resumeGame() {
    if (_state != GameState.paused) return;
    _state = GameState.playing;
    _startGameLoop();
    notifyListeners();
  }

  void retryGame() {
    _stopTimers();
    startGame(screenWidth: _screenWidth, screenHeight: _screenHeight);
  }

  void goHome() {
    _stopTimers();
    _state  = GameState.idle;
    _emojis = [];
    _scoreEvents = [];
    notifyListeners();
  }

  // Rewarded ad: continue with 1 life
  void continueWithRewardedAd() {
    _lives = 1;
    _combo = 0;
    _emojis.clear();
    _state = GameState.playing;
    _showRewarded = false;
    _startGameLoop();
    notifyListeners();
  }

  void consumeInterstitialFlag() {
    _showInterstitial = false;
    notifyListeners();
  }

  void consumeRewardedFlag() {
    _showRewarded = false;
  }

  // ── Game Loop ──────────────────────────────────────────────────────────────
  void _startGameLoop() {
    _stopTimers();
    // ~60fps update loop
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => _update(0.016));
    // Spawn timer fires frequently; actual spawn logic uses accumulator
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => _maybeSpawn());
  }

  void _stopTimers() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _gameTimer  = null;
    _spawnTimer = null;
  }

  void _update(double dt) {
    if (_state != GameState.playing) return;

    // Move emojis downward
    for (final e in _emojis) {
      if (e.isFalling) {
        e.y += e.speed * dt;
      }
    }

    // Detect missed emojis
    _checkMisses();

    // Remove dead emojis that have faded out
    _emojis.removeWhere((e) => e.y > _screenHeight + e.size * 2);

    // Cleanup old score events
    _scoreEvents.removeWhere((ev) => false); // cleared by UI after render

    notifyListeners();
  }

  void _maybeSpawn() {
    if (_state != GameState.playing) return;
    if (_emojis.where((e) => e.isFalling).length >= GameConstants.maxEmojisOnScreen) return;

    _spawnAccum += 0.05;
    if (_spawnAccum >= _currentLevel.spawnInterval) {
      _spawnAccum = 0.0;
      _spawnEmoji();
    }
  }

  void _spawnEmoji() {
    final lvl = _currentLevel;
    // Decide if next emoji is target or distractor
    final isTarget = _rng.nextInt(lvl.emojiMix + 1) == 0;

    String emoji;
    String category;

    if (isTarget) {
      switch (lvl.ruleType) {
        case RuleType.tapSpecific:
          emoji    = lvl.targetEmoji!;
          category = _categoryForEmoji(emoji);
        case RuleType.avoidSpecific:
          // Target = anything except the avoid emoji
          final pool = List<String>.from(EmojiPool.allEmojis)
            ..remove(lvl.targetEmoji);
          emoji    = pool[_rng.nextInt(pool.length)];
          category = _categoryForEmoji(emoji);
        case RuleType.tapCategory:
          final pool = EmojiPool.byCategory[lvl.targetCategory] ?? EmojiPool.allEmojis;
          emoji    = pool[_rng.nextInt(pool.length)];
          category = lvl.targetCategory!;
        case RuleType.avoidCategory:
          // Target = anything not in the avoid category
          final avoid = EmojiPool.byCategory[lvl.targetCategory] ?? [];
          final pool  = EmojiPool.allEmojis.where((e) => !avoid.contains(e)).toList();
          emoji    = pool.isEmpty ? '😊' : pool[_rng.nextInt(pool.length)];
          category = _categoryForEmoji(emoji);
      }
    } else {
      // Distractor
      switch (lvl.ruleType) {
        case RuleType.tapSpecific:
          final pool = List<String>.from(EmojiPool.allEmojis)
            ..remove(lvl.targetEmoji);
          emoji    = pool[_rng.nextInt(pool.length)];
          category = _categoryForEmoji(emoji);
        case RuleType.avoidSpecific:
          emoji    = lvl.targetEmoji!;    // the "avoid" emoji itself
          category = _categoryForEmoji(emoji);
        case RuleType.tapCategory:
          final avoid = EmojiPool.byCategory[lvl.targetCategory] ?? [];
          final pool  = EmojiPool.allEmojis.where((e) => !avoid.contains(e)).toList();
          emoji    = pool.isEmpty ? '💀' : pool[_rng.nextInt(pool.length)];
          category = _categoryForEmoji(emoji);
        case RuleType.avoidCategory:
          final pool = EmojiPool.byCategory[lvl.targetCategory] ?? EmojiPool.allEmojis;
          emoji    = pool[_rng.nextInt(pool.length)];
          category = lvl.targetCategory!;
      }
    }

    final size = GameConstants.emojiSizeBase * lvl.emojiSizeMultiplier;
    final speed = lvl.baseSpeed + (_level - 1) * GameConstants.speedIncrement;

    final item = EmojiItem.spawn(
      emoji: emoji,
      category: category,
      isTarget: isTarget,
      screenWidth: _screenWidth,
      emojiSize: size,
      speed: speed.clamp(GameConstants.speedBase, GameConstants.speedMax),
      rng: _rng,
    );

    _emojis.add(item);
  }

  String _categoryForEmoji(String emoji) {
    for (final entry in EmojiPool.byCategory.entries) {
      if (entry.value.contains(emoji)) return entry.key;
    }
    return 'misc';
  }

  void _checkMisses() {
    for (final e in _emojis) {
      if (!e.isFalling) continue;
      if (e.y > _screenHeight + e.size / 2) {
        if (e.isTarget) {
          // Missed a correct emoji = lose 1 life
          e.state = EmojiState.missed;
          _loseLife();
        } else {
          // Correctly avoided a distractor (fell off)
          e.state = EmojiState.missed;
        }
      }
    }
  }

  // ── Tap Handling ───────────────────────────────────────────────────────────
  void onEmojiTapped(EmojiItem emoji) {
    if (_state != GameState.playing) return;
    if (!emoji.isFalling) return;

    emoji.state = EmojiState.tapped;

    if (emoji.isTarget) {
      // ✅ Correct tap
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      final pts = 10 * comboMultiplier;
      _score += pts;
      _correctCount++;

      // Score popup
      _scoreEvents.add(ScoreEvent(
        points: pts,
        x: emoji.x,
        y: emoji.y,
        isCombo: _combo >= GameConstants.combo2x,
      ));

      // Audio
      if (_combo >= GameConstants.combo2x) {
        AudioService.instance.play(SoundEffect.combo);
      } else {
        AudioService.instance.play(SoundEffect.correct);
      }

      // Check level up
      if (_score >= _currentLevel.targetScore + (_level - 1) * GameConstants.scorePerLevel) {
        _levelUp();
      }
    } else {
      // ❌ Wrong tap — INSTANT GAME OVER
      _tappedEmoji = emoji.emoji;
      _failMessage = FailMessages.getForWrongTap(emoji.emoji);
      AudioService.instance.play(SoundEffect.wrong);
      _triggerGameOver();
    }
  }

  void _loseLife() {
    _lives--;
    _combo = 0;

    if (_lives <= 0) {
      _failMessage = FailMessages.getRandom();
      _tappedEmoji = '💔';
      AudioService.instance.play(SoundEffect.gameover);
      _triggerGameOver();
    } else {
      AudioService.instance.play(SoundEffect.wrong);
    }
  }

  void _levelUp() {
    _level++;
    _correctCount = 0;
    _currentLevel = LevelData.getLevel(_level);
    _spawnAccum   = 0.0;
    AudioService.instance.play(SoundEffect.levelup);

    // Bonus life every 3 levels (max 3)
    if (_level % 3 == 0 && _lives < GameConstants.maxLives) {
      _lives++;
    }
    notifyListeners();
  }

  void _triggerGameOver() {
    _stopTimers();
    _state = GameState.gameOver;
    _failCount++;
    _saveHighScore();

    // Show interstitial every N fails
    if (_failCount % GameConstants.adEveryNFails == 0) {
      _showInterstitial = true;
    }

    // Offer rewarded ad (continue) if player has some score
    if (_score >= 50) {
      _showRewarded = true;
    }

    notifyListeners();
  }

  // ── Stat Helpers ───────────────────────────────────────────────────────────
  String get fakeStat {
    // Fake global stat for engagement (common in casual games)
    final pct = max(1, 100 - (_level * 8 + _score ~/ 50)).clamp(1, 96);
    return 'Only $pct% of players reached level $_level';
  }

  void clearScoreEvents() {
    _scoreEvents.clear();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
