import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../constants/emoji_data.dart';
import '../models/emoji_item.dart';
import '../services/audio_service.dart';

enum GameState { idle, playing, paused, gameOver }

class ScoreEvent {
  final int    points;
  final double x;
  final double y;
  final bool   isCombo;
  ScoreEvent({required this.points, required this.x, required this.y, this.isCombo = false});
}

class GameProvider extends ChangeNotifier {
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

  LevelConfig _currentLevel = LevelData.getLevel(1);
  double _screenWidth       = 390;
  double _screenHeight      = 844;
  double _spawnAccum        = 0.0;
  double _currentSpeed      = GameConstants.speedBase;
  final  Random _rng        = Random();

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _gameTimer;
  Timer? _spawnTimer;
  Timer? _levelTimer;

  // ── Getters ───────────────────────────────────────────────────────────────
  GameState        get state                  => _state;
  List<EmojiItem>  get emojis                 => List.unmodifiable(_emojis);
  List<ScoreEvent> get scoreEvents            => List.unmodifiable(_scoreEvents);
  int              get score                  => _score;
  int              get highScore              => _highScore;
  int              get combo                  => _combo;
  int              get maxCombo               => _maxCombo;
  int              get level                  => _level;
  int              get levelSecondsLeft       => _levelSecondsLeft;
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
  }

  // ── Public API ────────────────────────────────────────────────────────────
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
    _showRewarded     = false;
    _currentLevel     = LevelData.getLevel(1);
    _failMessage      = '';
    _tappedEmoji      = '';

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

  /// Keeps score and level — clears emojis and resumes play.
  /// Called after player watches full rewarded ad on game-over screen.
  void continueAfterRewardedAd() {
    _emojis.clear();
    _scoreEvents.clear();
    _spawnAccum       = 0;
    _showRewarded     = false;
    _showInterstitial = false;
    _state            = GameState.playing;
    _startLoop();
    AudioService.instance.startBgm();
    notifyListeners();
  }

  void clearScoreEvents() => _scoreEvents.clear();

  // ── Game Loop ─────────────────────────────────────────────────────────────
  void _startLoop() {
    _stopTimers();
    _stopwatch..reset()..start();

    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final ms = _stopwatch.elapsedMilliseconds;
      _stopwatch.reset();
      _update((ms / 1000.0).clamp(0.005, 0.05));
    });

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

  void _stopTimers() {
    _stopwatch.stop();
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _levelTimer?.cancel();
    _gameTimer = _spawnTimer = _levelTimer = null;
  }

  void _update(double dt) {
    if (_state != GameState.playing) return;

    _currentSpeed = (_currentSpeed + GameConstants.speedGrowthRate * dt)
        .clamp(GameConstants.speedBase, GameConstants.speedMax);

    for (final e in _emojis) {
      if (e.isFalling) { e.speed = _currentSpeed; e.y += _currentSpeed * dt; }
    }

    _checkMisses();
    _emojis.removeWhere((e) => !e.isFalling && e.y > _screenHeight + e.size * 3);
    notifyListeners();
  }

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
        _failMessage = FailMessages.getForMissedTarget(e.emoji);
        _tappedEmoji = e.emoji;
        AudioService.instance.play(SoundEffect.gameover);
        _triggerGameOver();
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
      _scoreEvents.add(ScoreEvent(
        points: pts, x: emoji.x, y: emoji.y,
        isCombo: _combo >= GameConstants.combo2x,
      ));
      AudioService.instance.play(
        _combo >= GameConstants.combo2x ? SoundEffect.combo : SoundEffect.correct,
      );
    } else {
      // Wrong tap — instant game over
      _tappedEmoji = emoji.emoji;
      _failMessage = FailMessages.getForWrongTap(emoji.emoji);
      _combo       = 0;
      AudioService.instance.play(SoundEffect.wrong);
      _triggerGameOver();
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
    AudioService.instance.play(SoundEffect.levelup);
    notifyListeners();
  }

  void _triggerGameOver() {
    _stopTimers();
    _state            = GameState.gameOver;
    _failCount++;
    AudioService.instance.stopBgm();
    _saveHighScore();
    _showInterstitial = true;          // always show interstitial
    _showRewarded     = _score > 0;    // offer continue if player scored anything
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
