import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Helper wrapper around audioplayers package for playing synthetic voice advisories
/// and TTS responses in the ORCA Mobile App.
class AudioPlayerHelper {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;
  AudioPlayer get player => _player;

  AudioPlayerHelper() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = (state == PlayerState.playing);
    });
  }

  /// Play audio from Base64-encoded WAV/PCM/MP3 string.
  Future<void> playBytesBase64(String base64Audio) async {
    try {
      final clean = base64Audio.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(clean);
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('[AudioPlayerHelper] playBytesBase64 error: $e');
    }
  }

  /// Play audio directly from Uint8List bytes.
  Future<void> playBytes(Uint8List bytes) async {
    try {
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('[AudioPlayerHelper] playBytes error: $e');
    }
  }

  /// Play audio from a remote or local URL.
  Future<void> playUrl(String url) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('[AudioPlayerHelper] playUrl error: $e');
    }
  }

  /// Stop current playback.
  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('[AudioPlayerHelper] stop error: $e');
    }
  }

  /// Free audio resources.
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('[AudioPlayerHelper] dispose error: $e');
    }
  }
}
