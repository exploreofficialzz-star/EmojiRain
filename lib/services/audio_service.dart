import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect { correct, wrong, combo, gameover, levelup, tap }

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final Map<SoundEffect, AudioPlayer> _players = {};
  bool _soundEnabled = true;

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
  }

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

  bool get soundEnabled => _soundEnabled;

  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _soundEnabled);
  }

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    _players.clear();
  }
}
