import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/emoji_data.dart';
import '../constants/app_constants.dart';
import '../models/emoji_item.dart';
import '../services/audio_service.dart';

// ─── Game State ───────────────────────────────────────────────────────────────
enum GameState { idle, playing, paused, gameOver }

// ─── Score Popup Event ────────────────────────────────────────────────────────
class ScoreEvent {
  final int    points;
  final double x, y;
  final bool   isCombo;
  ScoreEvent({required this.points, required this.x, required this.y, this.isCombo = false});
}

// ─── GameProvider ─────────────────────────────────────────────────────────────
class GameProvider extends ChangeNotifier {
  // ── Core ──────────────────────────────────────────────────────────────────
  GameState        _state        = GameState.idle;
  List<EmojiItem>  _emojis       = [];
  List<ScoreEvent> _scoreEvents  = [];

  int    _score         = 0;
  int    _highScore     = 0;
  int    _combo         = 0;
  int    _maxCombo      = 0;
  int    _level         = 1;
  int    _failCount     = 0;
  bool   _showInterstitial = false;
  bool   _showRewarded     = false;
  String _failMessage   = '';
  String _tappedEmoji   = '';

  // ── Time-based level tracking ─────────────────────────────────────────────
  int    _levelSecsRemaining = GameConstants.levelDurationSecs;
  int    _levelSecsElapsed   = 0;
  int    _speedStage         = 0;   // 0–3, advances every 15s

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _gameTimer;
  Timer? _spawnTimer;
  Timer? _secondTimer;   // fires every 1s → countdown + speed ramp

  // ── Level / spawn ─────────────────────────────────────────────────────────
  LevelConfig _currentLevel = LevelData.getLevel(1);
  double _screenWidth  = 390;
  double _screenHeight = 844;
  double _spawnAccum   = 0.0;

  final Random _rng = Random();

  // ── Getters ───────────────────────────────────────────────────────────────
  GameState        get state              => _state;
  List<EmojiItem>  get emojis             => List.unmodifiable(_emojis);
  List<ScoreEvent> get scoreEvents        => List.unmodifiable(_scoreEvents);
  int get score              => _score;
  int get highScore          => _highScore;
  int get combo              => _combo;
  int get maxCombo           => _maxCombo;
  int get level              => _level;
  int get levelSecsRemaining => _levelSecsRemaining;
  int get speedStage         => _speedStage;
  bool get isPlaying         => _state == GameState.playing;
  bool get isGameOver        => _state == GameState.gameOver;
  bool get shouldShowInterstitial => _showInterstitial;
  bool get shouldShowRewarded     => _showRewarded;
  String get failMessage     => _failMessage;
  String get tappedEmoji     => _tappedEmoji;
  LevelConfig get currentLevel => _currentLevel;

  /// Current speed multiplier based on stage (1.0 → 1.25 → 1.55 → 1.90)
  double get speedMultiplier =>
      GameConstants.speedRampMultipliers[_speedStage.clamp(0, 3)];

  /// Current spawn interval (decreases as stage increases)
  double get spawnInterval =>
      GameConstants.spawnIntervalByStage[_speedStage.clamp(0, 3)];

  /// Current music rate (1.0 → 1.6 mapped from speed stages)
  // Music rate is fixed — no speed changes

  int get comboMultiplier {
    if (_combo >= GameConstants.combo10x) return 10;
    if (_combo >= GameConstants.combo5x)  return 5;
    if (_combo >= GameConstants.combo3x)  return 3;
    if (_combo >= GameConstants.combo2x)  return 2;
    return 1;
  }

  /// Emoji cap grows with level: 9 at L1 → 28 at L15+
  /// Formula: 9 + (level-1) * 1.3, clamped to maxEmojisOnScreen
  int get _maxEmojisThisLevel {
    final computed = (9 + (_level - 1) * 1.3).round();
    return computed.clamp(9, GameConstants.maxEmojisOnScreen);
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

    _state               = GameState.playing;
    _score               = 0;
    _combo               = 0;
    _maxCombo            = 0;
    _level               = 1;
    _failCount           = 0;
    _emojis              = [];
    _scoreEvents         = [];
    _spawnAccum          = 0.0;
    _showInterstitial    = false;
    _showRewarded        = false;
    _currentLevel        = LevelData.getLevel(1);
    _levelSecsRemaining  = GameConstants.levelDurationSecs;
    _levelSecsElapsed    = 0;
    _speedStage          = 0;

    _startLoop();
    AudioService.instance.startBgMusic();
    notifyListeners();
  }

  void pauseGame() {
    if (_state != GameState.playing) return;
    _state = GameState.paused;
    _stopTimers();
    AudioService.instance.pauseBgMusic();
    notifyListeners();
  }

  void resumeGame() {
    if (_state != GameState.paused) return;
    _state = GameState.playing;
    _startLoop();
    AudioService.instance.resumeBgMusic();
    notifyListeners();
  }

  void retryGame() {
    _stopTimers();
    AudioService.instance.stopBgMusic();
    startGame(screenWidth: _screenWidth, screenHeight: _screenHeight);
  }

  void goHome() {
    _stopTimers();
    AudioService.instance.stopBgMusic();
    _state   = GameState.idle;
    _emojis  = [];
    _scoreEvents = [];
    notifyListeners();
  }

  /// Continue from exact state after watching rewarded ad
  void continueAfterRewardedAd() {
    _emojis       = [];
    _spawnAccum   = 0.0;
    _state        = GameState.playing;
    _showRewarded = false;
    _startLoop();
    AudioService.instance.startBgMusic();
    notifyListeners();
  }

  void consumeInterstitialFlag() {
    _showInterstitial = false;
    notifyListeners();
  }

  // ── Loop ──────────────────────────────────────────────────────────────────
  void _startLoop() {
    _stopTimers();
    // 60fps physics update
    _gameTimer  = Timer.periodic(const Duration(milliseconds: 16), (_) => _update(0.016));
    // Spawn check at 40ms intervals
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 40), (_) => _maybeSpawn());
    // 1-second tick for countdown + speed ramp
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onSecondTick());
  }

  void _stopTimers() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _secondTimer?.cancel();
    _gameTimer = _spawnTimer = _secondTimer = null;
  }

  // ── Second Tick — countdown, speed ramp, music rate ───────────────────────
  void _onSecondTick() {
    if (_state != GameState.playing) return;

    _levelSecsRemaining--;
    _levelSecsElapsed++;

    // ── Speed ramp every 15 seconds ────────────────────────────────────────
    final newStage = (_levelSecsElapsed ~/ GameConstants.speedRampInterval)
        .clamp(0, GameConstants.speedRampMultipliers.length - 1);
    if (newStage != _speedStage) {
      _speedStage = newStage;
      // Music stays constant — no rate changes
    }

    // ── Level time expired → LEVEL UP ──────────────────────────────────────
    if (_levelSecsRemaining <= 0) {
      _levelUp();
    }

    notifyListeners();
  }

  // ── Physics Update ────────────────────────────────────────────────────────
  void _update(double dt) {
    if (_state != GameState.playing) return;

    for (final e in _emojis) {
      if (e.isFalling) e.y += e.speed * dt;
    }

    _checkMisses();
    _emojis.removeWhere((e) => !e.isFalling && e.y > _screenHeight + e.size * 3);
    notifyListeners();
  }

  // ── Spawn ─────────────────────────────────────────────────────────────────
  void _maybeSpawn() {
    if (_state != GameState.playing) return;
    // Use level-based cap — starts small, grows as levels increase
    if (_emojis.where((e) => e.isFalling).length >= _maxEmojisThisLevel) return;

    _spawnAccum += 0.04;
    if (_spawnAccum >= spawnInterval) {
      _spawnAccum = 0.0;
      _spawnEmoji();
      // Multi-spawn only unlocks gradually:
      //   Stage 1+ AND level 4+: occasional double spawn
      //   Stage 2+ AND level 7+: more frequent
      //   Stage 3+ AND level 10+: triple burst
      if (_speedStage >= 1 && _level >= 4  && _rng.nextBool())           _spawnEmoji();
      if (_speedStage >= 2 && _level >= 7  && _rng.nextDouble() < 0.55)  _spawnEmoji();
      if (_speedStage >= 3 && _level >= 10 && _rng.nextDouble() < 0.40)  _spawnEmoji();
    }
  }

  void _spawnEmoji() {
    final lvl = _currentLevel;

    // ── Decide target vs distractor ─────────────────────────────────────────
    // distractorRatio controls how many wrong emojis per correct
    // e.g. ratio=4 → 1 in 5 spawns is a target
    final isTarget = _rng.nextInt(lvl.distractorRatio + 1) == 0;

    String emoji;
    String category;

    if (isTarget) {
      (emoji, category) = _pickTargetEmoji(lvl);
    } else {
      (emoji, category) = _pickDistractorEmoji(lvl);
    }

    // ── Speed: base × ramp stage multiplier × level progression ─────────────
    final levelBonus = (_level - 1) * 10.0;
    final rawSpeed   = (lvl.baseSpeed + levelBonus) * speedMultiplier;
    final speed      = rawSpeed.clamp(GameConstants.speedBase, GameConstants.speedMax);

    final size = GameConstants.emojiSizeBase * lvl.emojiSizeMultiplier;

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

  // ── Target emoji selection ────────────────────────────────────────────────
  (String, String) _pickTargetEmoji(LevelConfig lvl) {
    switch (lvl.ruleType) {
      case RuleType.tapSpecific:
        return (lvl.targetEmoji!, _catOf(lvl.targetEmoji!));
      case RuleType.avoidSpecific:
        final pool = List<String>.from(EmojiPool.allEmojis)..remove(lvl.targetEmoji);
        final e = pool[_rng.nextInt(pool.length)];
        return (e, _catOf(e));
      case RuleType.tapCategory:
        final pool = EmojiPool.byCategory[lvl.targetCategory] ?? EmojiPool.allEmojis;
        final e = pool[_rng.nextInt(pool.length)];
        return (e, lvl.targetCategory!);
      case RuleType.avoidCategory:
        final avoid = EmojiPool.byCategory[lvl.targetCategory] ?? [];
        final pool  = EmojiPool.allEmojis.where((e) => !avoid.contains(e)).toList();
        final e = pool.isEmpty ? '😊' : pool[_rng.nextInt(pool.length)];
        return (e, _catOf(e));
    }
  }

  // ── Distractor emoji selection — uses lookalikes when level supports it ───
  (String, String) _pickDistractorEmoji(LevelConfig lvl) {
    // When useLookalikes is true and the target has a confusing lookalike pool,
    // 70% of distractors are chosen from the lookalike list to maximise confusion
    if (lvl.useLookalikes) {
      List<String>? lookalikes;

      if (lvl.ruleType == RuleType.tapSpecific && lvl.targetEmoji != null) {
        lookalikes = EmojiPool.confusingLookalikes[lvl.targetEmoji!];
      } else if (lvl.ruleType == RuleType.tapCategory && lvl.targetCategory != null) {
        // Mix in emojis from OTHER similar-looking categories
        final targetPool = EmojiPool.byCategory[lvl.targetCategory] ?? [];
        if (_rng.nextDouble() < 0.6) {
          // Pick a non-target emoji that looks like it could belong
          final fakePool = EmojiPool.allEmojis
              .where((e) => !targetPool.contains(e))
              .toList();
          if (fakePool.isNotEmpty) {
            final e = fakePool[_rng.nextInt(fakePool.length)];
            return (e, _catOf(e));
          }
        }
      }

      if (lookalikes != null && lookalikes.isNotEmpty && _rng.nextDouble() < 0.70) {
        final e = lookalikes[_rng.nextInt(lookalikes.length)];
        return (e, _catOf(e));
      }
    }

    // Default distractor
    switch (lvl.ruleType) {
      case RuleType.tapSpecific:
        final pool = List<String>.from(EmojiPool.allEmojis)..remove(lvl.targetEmoji);
        final e = pool[_rng.nextInt(pool.length)];
        return (e, _catOf(e));
      case RuleType.avoidSpecific:
        return (lvl.targetEmoji!, _catOf(lvl.targetEmoji!));
      case RuleType.tapCategory:
        final avoid = EmojiPool.byCategory[lvl.targetCategory] ?? [];
        final pool  = EmojiPool.allEmojis.where((e) => !avoid.contains(e)).toList();
        final e = pool.isEmpty ? '💀' : pool[_rng.nextInt(pool.length)];
        return (e, _catOf(e));
      case RuleType.avoidCategory:
        final pool = EmojiPool.byCategory[lvl.targetCategory] ?? EmojiPool.allEmojis;
        final e = pool[_rng.nextInt(pool.length)];
        return (e, lvl.targetCategory!);
    }
  }

  String _catOf(String emoji) {
    for (final e in EmojiPool.byCategory.entries) {
      if (e.value.contains(emoji)) return e.key;
    }
    return 'misc';
  }

  // ── Miss Check — INSTANT GAME OVER if target escapes ─────────────────────
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
    } else {
      _tappedEmoji = emoji.emoji;
      _failMessage = FailMessages.getForWrongTap(emoji.emoji);
      AudioService.instance.play(SoundEffect.wrong);
      _triggerGameOver();
    }
  }

  // ── Level Up ──────────────────────────────────────────────────────────────
  void _levelUp() {
    _level++;
    _currentLevel       = LevelData.getLevel(_level);
    _levelSecsRemaining = GameConstants.levelDurationSecs;
    _spawnAccum         = 0.0;
    _emojis.clear();

    // ── Carry speed stage forward — game never slows down between levels ─────
    // _speedStage stays at whatever it was. We resync _levelSecsElapsed
    // so the 1-second ticker doesn't immediately drop us back to stage 0.
    _levelSecsElapsed = _speedStage * GameConstants.speedRampInterval;

    // Each new level also gets a minimum stage boost so speed always increases
    // Level 1→2: at least stage 0, Level 3+: at least stage 1,
    // Level 6+: at least stage 2, Level 10+: always stage 3
    final minStage = switch (_level) {
      >= 10 => 3,
      >= 6  => 2,
      >= 3  => 1,
      _     => 0,
    };
    if (_speedStage < minStage) {
      _speedStage   = minStage;
      _levelSecsElapsed = minStage * GameConstants.speedRampInterval;
    }

    AudioService.instance.play(SoundEffect.levelup);
    notifyListeners();
  }

  // ── Game Over ─────────────────────────────────────────────────────────────
  void _triggerGameOver() {
    _stopTimers();
    _state = GameState.gameOver;
    _failCount++;
    _saveHighScore();
    AudioService.instance.stopBgMusic();

    _showInterstitial = true;
    _showRewarded     = _score >= 20;
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
