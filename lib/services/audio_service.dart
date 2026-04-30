import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect { correct, wrong, combo, gameover, levelup, tap }

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final Map<SoundEffect, AudioPlayer> _sfxPlayers = {};
  AudioPlayer? _bgmPlayer;
  bool _soundEnabled = true;
  bool _bgmPlaying   = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;

    // ── Configure global audio context for Android (enables background audio)
    if (Platform.isAndroid) {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            audioFocus: AndroidAudioFocus.gain,
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.music,
            isSpeakerphoneOn: false,
          ),
        ),
      );
    }

    // ── SFX players — one per effect, pre-warmed
    for (final effect in SoundEffect.values) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(0.85);
      _sfxPlayers[effect] = p;
    }

    // ── BGM player — created here (after engine ready), looping
    _bgmPlayer = AudioPlayer();
    await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer!.setVolume(0.4);
  }

  // ── Background Music ──────────────────────────────────────────────────────

  Future<void> startBgm() async {
    if (!_soundEnabled) return;
    final player = _bgmPlayer;
    if (player == null) return;
    try {
      _bgmPlaying = true;
      await player.play(AssetSource('sounds/bgm.mp3'));
    } catch (_) {
      _bgmPlaying = false;
    }
  }

  Future<void> pauseBgm() async {
    if (!_bgmPlaying) return;
    try {
      await _bgmPlayer?.pause();
      _bgmPlaying = false;
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    if (!_soundEnabled || _bgmPlaying) return;
    final player = _bgmPlayer;
    if (player == null) return;
    try {
      // resume() only works if still loaded; fall back to play() if not
      final state = player.state;
      if (state == PlayerState.paused) {
        await player.resume();
      } else {
        await player.play(AssetSource('sounds/bgm.mp3'));
      }
      _bgmPlaying = true;
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    _bgmPlaying = false;
    try {
      await _bgmPlayer?.stop();
    } catch (_) {}
  }

  // ── Sound Effects ─────────────────────────────────────────────────────────

  Future<void> play(SoundEffect effect) async {
    if (!_soundEnabled) return;
    final player = _sfxPlayers[effect];
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
    if (!_soundEnabled) await stopBgm();
  }

  void dispose() {
    for (final p in _sfxPlayers.values) p.dispose();
    _sfxPlayers.clear();
    _bgmPlayer?.dispose();
    _bgmPlayer = null;
  }
}

