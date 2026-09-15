import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:record/record.dart';

/// A single beat detection event emitted by [BeatDetectorService].
class BeatEvent {
  final DateTime timestamp;
  final double   bpm;
  final double   confidence; // 0.0–1.0

  const BeatEvent({
    required this.timestamp,
    required this.bpm,
    required this.confidence,
  });
}

/// Listens to the device microphone and extracts BPM in real time via
/// amplitude-envelope onset detection.
///
/// Usage:
/// ```dart
/// final det = BeatDetectorService.instance;
/// await det.startDetecting();
/// det.beatStream.listen((event) { ... });
/// await det.stopDetecting();
/// ```
///
/// If [confidence] < 0.6 on the emitted event, the caller should fall back
/// to a built-in track BPM via [BuiltInTracks.closestBpm].
class BeatDetectorService {
  BeatDetectorService._();
  static final BeatDetectorService instance = BeatDetectorService._();

  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _streamSub;
  StreamController<BeatEvent>?   _beatCtrl;

  // ── Onset detection state ─────────────────────────────────────────────────
  final List<double>   _rmsWindow      = []; // sliding ~1-s window of RMS values
  final List<DateTime> _onsets         = []; // timestamps of detected onsets
  double               _adaptiveThresh = 0.02;
  DateTime?            _lastOnset;

  bool get isDetecting => _streamSub != null;

  /// Broadcast stream of [BeatEvent]s. Listen before calling [startDetecting].
  Stream<BeatEvent> get beatStream =>
      _beatCtrl?.stream ?? const Stream.empty();

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> hasPermission() => _recorder.hasPermission();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<bool> startDetecting() async {
    if (isDetecting) return true;

    if (!await _recorder.hasPermission()) return false;

    _reset();
    _beatCtrl = StreamController<BeatEvent>.broadcast();

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder:    AudioEncoder.pcm16bits,
          sampleRate: 22050,
          numChannels: 1,
        ),
      );
      _streamSub = stream.listen(
        _processChunk,
        onError: (_) => stopDetecting(),
        cancelOnError: true,
      );
      return true;
    } catch (_) {
      await _beatCtrl?.close();
      _beatCtrl = null;
      return false;
    }
  }

  Future<void> stopDetecting() async {
    await _streamSub?.cancel();
    _streamSub = null;
    try { await _recorder.stop(); } catch (_) {}
    await _beatCtrl?.close();
    _beatCtrl = null;
    _reset();
  }

  // ── Audio processing ──────────────────────────────────────────────────────

  void _reset() {
    _rmsWindow.clear();
    _onsets.clear();
    _adaptiveThresh = 0.02;
    _lastOnset      = null;
  }

  /// Process one chunk of raw 16-bit signed PCM samples (little-endian).
  void _processChunk(Uint8List data) {
    if (data.length < 2) return;

    // Parse as 16-bit signed integers
    final samples = Int16List.view(data.buffer);

    // ── 1. RMS of this chunk ──────────────────────────────────────────────
    double sumSq = 0;
    for (final s in samples) {
      final norm = s / 32768.0;
      sumSq += norm * norm;
    }
    final rms = sqrt(sumSq / samples.length);

    // Sliding ~1-second window (≈43 chunks/s at 22050 Hz, 512-sample chunks)
    _rmsWindow.add(rms);
    if (_rmsWindow.length > 43) _rmsWindow.removeAt(0);

    // ── 2. Adaptive threshold: mean × 1.5 + noise floor ──────────────────
    if (_rmsWindow.isNotEmpty) {
      final mean = _rmsWindow.reduce((a, b) => a + b) / _rmsWindow.length;
      _adaptiveThresh = mean * 1.5 + 0.008;
    }

    // ── 3. Onset detection ─────────────────────────────────────────────────
    if (rms > _adaptiveThresh && _rmsWindow.length > 5) {
      final now = DateTime.now();
      // Minimum 200 ms between onsets (prevents double-detects within a beat)
      final msGap = _lastOnset == null
          ? 9999
          : now.difference(_lastOnset!).inMilliseconds;

      if (msGap > 200) {
        _lastOnset = now;
        _onsets.add(now);
        if (_onsets.length > 24) _onsets.removeAt(0);

        if (_onsets.length >= 4) _emitBpm();
      }
    }
  }

  /// Compute BPM from onset intervals and emit if reliable.
  void _emitBpm() {
    final intervals = <double>[];
    for (int i = 1; i < _onsets.length; i++) {
      final ms = _onsets[i].difference(_onsets[i - 1]).inMilliseconds.toDouble();
      if (ms > 200 && ms < 2000) intervals.add(ms); // valid musical range
    }
    if (intervals.length < 3) return;

    // Median interval — robust against outliers
    final sorted   = List<double>.from(intervals)..sort();
    final medianMs = sorted[sorted.length ~/ 2];
    final rawBpm   = 60000.0 / medianMs;

    // Harmonic correction: if raw is >150 bpm it may be detecting 8th notes
    final bpm = rawBpm > 150 ? rawBpm / 2.0 : rawBpm;
    final clamped = bpm.clamp(55.0, 200.0);

    // Confidence: inverse coefficient of variation (lower spread = higher confidence)
    double confidence = 0.3;
    if (intervals.length >= 4) {
      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      final variance = intervals
          .map((v) => (v - mean) * (v - mean))
          .reduce((a, b) => a + b) / intervals.length;
      final cv = sqrt(variance) / mean; // coefficient of variation
      confidence = (1.0 - cv.clamp(0.0, 1.0)).clamp(0.0, 1.0);
    }

    _beatCtrl?.add(BeatEvent(
      timestamp:  DateTime.now(),
      bpm:        clamped,
      confidence: confidence,
    ));
  }

  void dispose() {
    stopDetecting();
    _recorder.dispose();
  }
}
