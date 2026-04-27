import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect { correct, wrong, combo, gameover, levelup, tap }

// ─── AudioService ─────────────────────────────────────────────────────────────
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  // ── SFX players (one per effect for instant playback) ─────────────────────
  final Map<SoundEffect, AudioPlayer> _sfx = {};

  // ── Background music player ────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  bool _bgPlaying   = false;
  double _bgRate    = 1.0;

  bool _soundEnabled = true;
  bool _musicEnabled = true;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _musicEnabled = prefs.getBool('music_enabled') ?? true;

    // Pre-create SFX players
    for (final effect in SoundEffect.values) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(0.9);
      _sfx[effect] = p;
    }

    // Configure BG player for infinite loop
    await _bgPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgPlayer.setVolume(0.45);
  }

  // ── SFX ───────────────────────────────────────────────────────────────────
  Future<void> play(SoundEffect effect) async {
    if (!_soundEnabled) return;
    final p = _sfx[effect];
    if (p == null) return;
    try {
      await p.stop();
      await p.play(AssetSource(_sfxPath(effect)));
    } catch (_) {}
  }

  String _sfxPath(SoundEffect e) => switch (e) {
    SoundEffect.correct  => 'sounds/correct.wav',
    SoundEffect.wrong    => 'sounds/wrong.wav',
    SoundEffect.combo    => 'sounds/combo.wav',
    SoundEffect.gameover => 'sounds/gameover.wav',
    SoundEffect.levelup  => 'sounds/levelup.wav',
    SoundEffect.tap      => 'sounds/tap.wav',
  };

  // ── Background Music ───────────────────────────────────────────────────────
  Future<void> startBgMusic() async {
    if (!_musicEnabled) return;
    if (_bgPlaying) return;
    try {
      await _bgPlayer.setPlaybackRate(_bgRate);
      await _bgPlayer.play(AssetSource('sounds/bg_music.mp3'));
      _bgPlaying = true;
    } catch (_) {}
  }

  Future<void> stopBgMusic() async {
    if (!_bgPlaying) return;
    try {
      await _bgPlayer.stop();
      _bgPlaying = false;
    } catch (_) {}
  }

  Future<void> pauseBgMusic() async {
    if (!_bgPlaying) return;
    try { await _bgPlayer.pause(); } catch (_) {}
  }

  Future<void> resumeBgMusic() async {
    if (!_musicEnabled || !_bgPlaying) return;
    try { await _bgPlayer.resume(); } catch (_) {}
  }

  /// Set background music playback rate — range [1.0 … 1.6]
  /// Called by GameProvider every 15 seconds as speed ramps up.
  Future<void> setBgMusicRate(double rate) async {
    _bgRate = rate.clamp(0.5, 2.0);
    if (_bgPlaying) {
      try { await _bgPlayer.setPlaybackRate(_bgRate); } catch (_) {}
    }
  }

  // ── Settings toggles ──────────────────────────────────────────────────────
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _soundEnabled);
  }

  Future<void> toggleMusic() async {
    _musicEnabled = !_musicEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', _musicEnabled);
    if (_musicEnabled) {
      await startBgMusic();
    } else {
      await stopBgMusic();
    }
  }

  void dispose() {
    for (final p in _sfx.values) { p.dispose(); }
    _bgPlayer.dispose();
    _sfx.clear();
  }
}
