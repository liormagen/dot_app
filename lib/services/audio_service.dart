import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioService {
  final AudioPlayer _voiceoverPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();

  bool _musicEnabled = true;
  bool _sfxEnabled = true;

  Future<void> init() async {
    await _musicPlayer.setVolume(0.3);
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      _musicPlayer.stop().catchError((_) {});
    }
  }

  void setSfxEnabled(bool enabled) {
    _sfxEnabled = enabled;
  }

  Future<void> playVoiceover(String assetPath) async {
    try {
      await _voiceoverPlayer.stop();
      await _voiceoverPlayer.play(AssetSource(assetPath));
    } catch (_) {}
  }

  Future<void> playSfx(String assetPath) async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource(assetPath));
    } catch (_) {}
  }

  Future<void> playMusic(String assetPath) async {
    if (!_musicEnabled) return;
    try {
      await _musicPlayer.stop();
      await _musicPlayer.play(AssetSource(assetPath));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  Future<void> playNumber(String lang, int number) async {
    try {
      await _voiceoverPlayer.stop();
      await _voiceoverPlayer
          .play(AssetSource('audio/$lang/numbers/$number.mp3'));
    } catch (_) {}
  }

  Future<void> playDrawingName(String lang, String drawingId) async {
    try {
      await _voiceoverPlayer.stop();
      await _voiceoverPlayer
          .play(AssetSource('audio/$lang/${drawingId}_name.mp3'));
    } catch (_) {}
  }

  Future<void> playChapterNarration(
      String lang, String storyId, int chapter) async {
    try {
      await _voiceoverPlayer.stop();
      await _voiceoverPlayer.play(
          AssetSource('audio/$lang/${storyId}_chapter$chapter.mp3'));
    } catch (_) {}
  }

  Future<void> playEncouragement(String lang) async {
    final rand = Random();
    final index = rand.nextInt(6) + 1;
    try {
      await _voiceoverPlayer.stop();
      await _voiceoverPlayer
          .play(AssetSource('audio/$lang/encouragement_$index.mp3'));
    } catch (_) {}
  }

  Future<void> playDotConnect() async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/sfx/dot_connect.mp3'));
    } catch (_) {}
  }

  Future<void> playDrawingComplete() async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/sfx/drawing_complete.mp3'));
    } catch (_) {}
  }

  Future<void> playConfetti() async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/sfx/confetti.mp3'));
    } catch (_) {}
  }

  AudioPlayer get voiceoverPlayer => _voiceoverPlayer;

  Future<void> dispose() async {
    await _voiceoverPlayer.dispose();
    await _sfxPlayer.dispose();
    await _musicPlayer.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final audioServiceProvider = Provider<AudioService>(
  (_) => throw UnimplementedError('Override audioServiceProvider'),
);
