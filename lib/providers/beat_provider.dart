import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/beat_tracks.dart';
import '../models/beat_track.dart';
import '../models/emoji_item.dart';
import '../providers/game_provider.dart';
import '../services/beat_detector_service.dart';

/// Beat timing quality labels shown on-screen after each tap.
enum BeatLabel { none, close, onBeat }

/// Beat Mode game logic layered on top of the existing [GameProvider].
///
/// Beat Mode is NOT a replacement of the game engine — it wraps it:
///   • [GameProvider] still handles collision, combo, hearts, level-up.
///   • [BeatProvider] adds beat-sync scoring, overlay labels, and track playback.
///
/// Score formula per correct tap:
///   beatScore += gamePts × beatMultiplier
///
/// Where beatMultiplier is:
///   PERFECT (±80 ms)  → 3.0   "🔥 ON BEAT"
///   GOOD    (±150 ms) → 1.5   "✨ CLOSE"
///   MISS             → 1.0   (no label)
class BeatProvider extends ChangeNotifier {
  BeatProvider(this._game);

  final GameProvider _game;

  // ── Track / BPM ───────────────────────────────────────────────────────────
  BeatTrack? _selectedTrack;
  bool       _usingDeviceSync = false;
  double     _currentBpm      = 0;
  double     _confidence      = 0;

  // ── Beat pulse timing ─────────────────────────────────────────────────────
  /// Timestamps of each beat pulse, derived from current BPM.
  /// Updated every time BPM changes.
  final List<DateTime> _beatPulses = [];
  DateTime?            _beatSessionStart;
  Timer?               _beatTimer;
  StreamSubscription<BeatEvent>? _detectorSub;

  // ── Scoring ───────────────────────────────────────────────────────────────
  double _beatBonusScore    = 0; // extra pts accumulated from beat multipliers
  double _beatMultiplier    = 1.0;
  BeatLabel _lastBeatLabel  = BeatLabel.none;
  int    _beatStreak        = 0; // consecutive ON BEAT taps
  int    _bestStreak        = 0;
  int    _totalTaps         = 0;
  int    _onBeatTaps        = 0;
  int    _closeTaps         = 0;
  double _bestMultiplierHit = 1.0;

  // ── Audio (track preview + playback) ─────────────────────────────────────
  final AudioPlayer _trackPlayer = AudioPlayer();
  bool _trackPlaying = false;

  // ── Calibration ───────────────────────────────────────────────────────────
  bool _calibrating      = false;
  double _calibratedBpm  = 0;

  // ── Getters ───────────────────────────────────────────────────────────────
  BeatTrack? get selectedTrack    => _selectedTrack;
  bool       get usingDeviceSync  => _usingDeviceSync;
  double     get currentBpm       => _currentBpm;
  double     get confidence       => _confidence;
  double     get beatMultiplier   => _beatMultiplier;
  BeatLabel  get lastBeatLabel    => _lastBeatLabel;
  int        get beatStreak       => _beatStreak;
  int        get bestStreak       => _bestStreak;
  bool       get calibrating      => _calibrating;
  double     get calibratedBpm    => _calibratedBpm;

  /// Total beat-enhanced score (GameProvider base score + accumulated beat bonus).
  int  get beatScore      => (_game.score + _beatBonusScore).round();

  /// Beat accuracy: (perfect + good taps) / total correct taps %.
  double get beatAccuracyPct {
    if (_totalTaps == 0) return 0;
    return ((_onBeatTaps + _closeTaps) / _totalTaps * 100).clamp(0, 100);
  }

  double get bestMultiplierHit => _bestMultiplierHit;

  // ── Track Selection ───────────────────────────────────────────────────────

  Future<void> selectBuiltInTrack(BeatTrack track) async {
    _stopDeviceSync();
    _selectedTrack   = track;
    _usingDeviceSync = false;
    _currentBpm      = track.bpm.toDouble();
    notifyListeners();
  }

  Future<void> selectDeviceSync() async {
    _selectedTrack   = null;
    _usingDeviceSync = true;
    notifyListeners();
  }

  // ── Track Preview ──────────────────────────────────────────────────────────

  Future<void> previewTrack(BeatTrack track) async {
    try {
      await _trackPlayer.setAsset(track.assetPath);
      await _trackPlayer.play();
      _trackPlaying = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> stopPreview() async {
    try {
      await _trackPlayer.stop();
      _trackPlaying = false;
      notifyListeners();
    } catch (_) {}
  }

  // ── Calibration ───────────────────────────────────────────────────────────

  /// 3-second calibration phase. Returns detected BPM (or closest built-in
  /// BPM if confidence < 0.6).
  Future<double> calibrate() async {
    _calibrating     = true;
    _calibratedBpm   = 0;
    _confidence      = 0;
    notifyListeners();

    if (_usingDeviceSync) {
      final started = await BeatDetectorService.instance.startDetecting();
      if (started) {
        // Collect detections for 3 seconds
        final completer    = Completer<void>();
        final detectedBpms = <double>[];

        final sub = BeatDetectorService.instance.beatStream.listen((event) {
          detectedBpms.add(event.bpm);
          _confidence    = event.confidence;
          _calibratedBpm = event.bpm;
          notifyListeners();
        });

        await Future.delayed(const Duration(seconds: 3));
        await sub.cancel();

        if (detectedBpms.isNotEmpty && _confidence >= 0.6) {
          // Use the last stable BPM reading
          _calibratedBpm = detectedBpms.last;
        } else {
          // Fall back to closest built-in BPM
          final fallback = _calibratedBpm > 0
              ? _calibratedBpm
              : 110.0; // default Afropop
          _calibratedBpm = BuiltInTracks.closestBpm(fallback).toDouble();
          _confidence    = 0.0; // signal fallback used
        }
        completer.complete();
        await completer.future;
        await BeatDetectorService.instance.stopDetecting();
      } else {
        // No mic permission → fall back to Afropop 110 bpm
        _calibratedBpm = 110;
        _confidence    = 0;
      }
    } else {
      // Built-in track: simulate calibration delay
      await Future.delayed(const Duration(seconds: 1, milliseconds: 500));
      _calibratedBpm = (_selectedTrack?.bpm ?? 110).toDouble();
      _confidence    = 1.0;
    }

    _calibrating = false;
    _currentBpm  = _calibratedBpm;
    notifyListeners();
    return _calibratedBpm;
  }

  // ── Gameplay Start / Stop ─────────────────────────────────────────────────

  Future<void> startBeatMode() async {
    _beatBonusScore    = 0;
    _beatMultiplier    = 1.0;
    _lastBeatLabel     = BeatLabel.none;
    _beatStreak        = 0;
    _bestStreak        = 0;
    _totalTaps         = 0;
    _onBeatTaps        = 0;
    _closeTaps         = 0;
    _bestMultiplierHit = 1.0;
    _beatPulses.clear();
    _beatSessionStart  = DateTime.now();

    // Start device sync stream if using mic
    if (_usingDeviceSync) {
      final started = await BeatDetectorService.instance.startDetecting();
      if (started) {
        _detectorSub = BeatDetectorService.instance.beatStream.listen((event) {
          if (event.confidence >= 0.5) {
            _currentBpm = event.bpm;
          }
          _scheduleBeatTimer();
          notifyListeners();
        });
      }
    }

    // Start track audio if using built-in
    if (!_usingDeviceSync && _selectedTrack != null) {
      try {
        await _trackPlayer.setAsset(_selectedTrack!.assetPath);
        await _trackPlayer.setLoopMode(LoopMode.one);
        await _trackPlayer.play();
        _trackPlaying = true;
      } catch (_) {}
    }

    _scheduleBeatTimer();
    notifyListeners();
  }

  void stopBeatMode() {
    _beatTimer?.cancel();
    _beatTimer = null;
    _detectorSub?.cancel();
    _detectorSub = null;
    BeatDetectorService.instance.stopDetecting();
    _trackPlayer.stop();
    _trackPlaying = false;
    _stopDeviceSync();
  }

  // ── Beat Pulse Timer ──────────────────────────────────────────────────────

  void _scheduleBeatTimer() {
    _beatTimer?.cancel();
    if (_currentBpm <= 0) return;

    final intervalMs = (60000.0 / _currentBpm).round();
    _beatTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _onBeatPulse(),
    );
  }

  void _onBeatPulse() {
    _beatPulses.add(DateTime.now());
    if (_beatPulses.length > 8) _beatPulses.removeAt(0);
    notifyListeners();
  }

  // ── Tap Handling ──────────────────────────────────────────────────────────

  /// Called in place of [GameProvider.onEmojiTapped] during Beat Mode.
  /// Applies beat timing multiplier on top of the base score.
  void onBeatTap(EmojiItem emoji) {
    if (!_game.isPlaying) return;

    final priorScore = _game.score;
    _game.onEmojiTapped(emoji);

    final delta = _game.score - priorScore;
    if (delta <= 0) return; // wrong tap or not a target — no beat bonus

    // ── Beat timing evaluation ──────────────────────────────────────────
    _totalTaps++;
    final tapTime = DateTime.now();
    final nearestBeatMs = _nearestBeatDeltaMs(tapTime);

    if (nearestBeatMs <= 80) {
      _beatMultiplier  = 3.0;
      _lastBeatLabel   = BeatLabel.onBeat;
      _beatStreak++;
      _onBeatTaps++;
    } else if (nearestBeatMs <= 150) {
      _beatMultiplier  = 1.5;
      _lastBeatLabel   = BeatLabel.close;
      _beatStreak = max(0, _beatStreak - 0); // keep streak for CLOSE
      _closeTaps++;
    } else {
      _beatMultiplier  = 1.0;
      _lastBeatLabel   = BeatLabel.none;
      _beatStreak      = 0;
    }

    if (_beatStreak > _bestStreak) _bestStreak = _beatStreak;
    if (_beatMultiplier > _bestMultiplierHit) _bestMultiplierHit = _beatMultiplier;

    // Extra points from beat multiplier (beyond the base game score)
    _beatBonusScore += delta * (_beatMultiplier - 1.0);

    notifyListeners();
  }

  /// ms from [tapTime] to the nearest recorded beat pulse.
  int _nearestBeatDeltaMs(DateTime tapTime) {
    if (_beatPulses.isEmpty) return 9999;
    int minMs = 9999;
    for (final pulse in _beatPulses) {
      final ms = tapTime.difference(pulse).inMilliseconds.abs();
      if (ms < minMs) minMs = ms;
    }
    return minMs;
  }

  void clearBeatLabel() {
    _lastBeatLabel  = BeatLabel.none;
    _beatMultiplier = 1.0;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _stopDeviceSync() {
    _detectorSub?.cancel();
    _detectorSub = null;
    BeatDetectorService.instance.stopDetecting();
  }

  @override
  void dispose() {
    stopBeatMode();
    _trackPlayer.dispose();
    super.dispose();
  }
}
