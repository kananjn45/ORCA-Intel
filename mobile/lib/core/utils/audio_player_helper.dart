import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Helper wrapper around audioplayers package for playing synthetic voice advisories,
/// TTS responses, and in-memory synthesized emergency sirens in the ORCA Mobile App.
class AudioPlayerHelper {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isEmergencyBuzzerActive = false;

  bool get isPlaying => _isPlaying;
  bool get isEmergencyBuzzerActive => _isEmergencyBuzzerActive;
  AudioPlayer get player => _player;

  AudioPlayerHelper() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = (state == PlayerState.playing);
    });
  }

  /// Synthesize an authentic marine emergency siren / buzzer waveform in memory
  /// Generates a two-tone 880Hz / 1240Hz pulsing alert horn encoded into a standard RIFF WAV.
  static Uint8List generateEmergencySirenWav({
    double durationSeconds = 1.2,
    int sampleRate = 16000,
  }) {
    final numSamples = (durationSeconds * sampleRate).toInt();
    final dataSize = numSamples * 2; // 16-bit mono
    final fileSize = 44 + dataSize;
    final buffer = ByteData(fileSize);

    // RIFF chunk descriptor
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, fileSize - 8, Endian.little);
    buffer.setUint8(8, 0x57);  // 'W'
    buffer.setUint8(9, 0x41);  // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // 16 for PCM
    buffer.setUint16(20, 1, Endian.little);  // AudioFormat: 1 = PCM
    buffer.setUint16(22, 1, Endian.little);  // Mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // ByteRate = sampleRate * 1 * 2
    buffer.setUint16(32, 2, Endian.little);  // BlockAlign = 2
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample = 16

    // data subchunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataSize, Endian.little);

    // Two-tone high-urgency naval siren: alternates 880Hz and 1240Hz every 300ms
    final halfPeriod = sampleRate * 0.3;
    for (int i = 0; i < numSamples; i++) {
      final tonePhase = ((i / halfPeriod).toInt()) % 2;
      final freq = (tonePhase == 0) ? 880.0 : 1240.0;
      final t = i / sampleRate;
      final sample = (math.sin(2 * math.pi * freq * t) * 26000).toInt();
      buffer.setInt16(44 + (i * 2), sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  /// Sounds the high-priority auditory emergency buzzer siren in a loop
  Future<void> playEmergencyBuzzer() async {
    if (_isEmergencyBuzzerActive) return;
    try {
      _isEmergencyBuzzerActive = true;
      final sirenBytes = generateEmergencySirenWav();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.stop();
      await _player.play(BytesSource(sirenBytes));
    } catch (e) {
      debugPrint('[AudioPlayerHelper] playEmergencyBuzzer error: $e');
    }
  }

  /// Halts the auditory emergency buzzer siren immediately
  Future<void> stopEmergencyBuzzer() async {
    _isEmergencyBuzzerActive = false;
    try {
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.stop();
    } catch (e) {
      debugPrint('[AudioPlayerHelper] stopEmergencyBuzzer error: $e');
    }
  }

  /// Play audio from Base64-encoded WAV/PCM/MP3 string.
  Future<void> playBytesBase64(String base64Audio) async {
    try {
      final clean = base64Audio.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(clean);
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('[AudioPlayerHelper] playBytesBase64 error: $e');
    }
  }

  /// Play audio directly from Uint8List bytes.
  Future<void> playBytes(Uint8List bytes) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('[AudioPlayerHelper] playBytes error: $e');
    }
  }

  /// Play audio from a remote or local URL.
  Future<void> playUrl(String url) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
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
      _isEmergencyBuzzerActive = false;
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
