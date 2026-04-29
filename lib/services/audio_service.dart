import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect { correct, wrong, combo, gameover, levelup, tap }

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final Map<SoundEffect, AudioPlayer> _players = {};
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _soundEnabled = true;
  bool _bgmPlaying   = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;

    // Pre-load one player per effect for instant playback
    for (final effect in SoundEffect.values) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.9);
      _players[effect] = player;
    }

    // BGM player — looping, lower volume so SFX cut through
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.4);
  }

  // ── Background Music ──────────────────────────────────────────────────────

  Future<void> startBgm() async {
    if (!_soundEnabled || _bgmPlaying) return;
    try {
      await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'));
      _bgmPlaying = true;
    } catch (_) {}
  }

  Future<void> pauseBgm() async {
    if (!_bgmPlaying) return;
    try {
      await _bgmPlayer.pause();
      _bgmPlaying = false;
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    if (!_soundEnabled || _bgmPlaying) return;
    try {
      await _bgmPlayer.resume();
      _bgmPlaying = true;
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
      _bgmPlaying = false;
    } catch (_) {}
  }

  // ── Sound Effects ─────────────────────────────────────────────────────────

  Future<void> play(SoundEffect effect) async {
    if (!_soundEnabled) return;
    final player = _players[effect];
    if (player == null) return;
    try {
      await player.stop();
      await player.play(AssetSource(_assetPath(effect)));
    } catch (_) {}
  }

  String _assetPath(SoundEffect effect) {
    switch (effect) {
      case SoundEffect.correct:  return 'sounds/correct.wav';
      case SoundEffect.wrong:    return 'sounds/wrong.wav';
      case SoundEffect.combo:    return 'sounds/combo.wav';
      case SoundEffect.gameover: return 'sounds/gameover.wav';
      case SoundEffect.levelup:  return 'sounds/levelup.wav';
      case SoundEffect.tap:      return 'sounds/tap.wav';
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  bool get soundEnabled => _soundEnabled;

  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _soundEnabled);
    if (!_soundEnabled) {
      await stopBgm();
    }
  }

  void dispose() {
    for (final p in _players.values) p.dispose();
    _players.clear();
    _bgmPlayer.dispose();
  }
}

