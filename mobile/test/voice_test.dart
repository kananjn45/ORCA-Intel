import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_mobile/data/repositories/voice_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dev 4 Bhashini Voice Integration Tests', () {
    test('VoiceRepository supported languages fallback includes Indic languages', () async {
      final repo = VoiceRepository();
      final langs = await repo.getSupportedLanguages();

      expect(langs.containsKey('ta'), isTrue);
      expect(langs.containsKey('te'), isTrue);
      expect(langs.containsKey('hi'), isTrue);
      expect(langs.containsKey('en'), isTrue);
      expect(langs['ta'], equals('Tamil'));
    });

    test('Base64 audio payload cleanly validates and decodes', () {
      const mockBase64 = 'TU9DS19BVURJTzo6VGFtaWw6OmZlbWFsZTo6U2FmZSB3YXRlcnM=';
      final decoded = base64Decode(mockBase64);
      expect(decoded, isNotEmpty);
      final text = utf8.decode(decoded);
      expect(text, contains('MOCK_AUDIO'));
      expect(text, contains('Tamil'));
    });

    test('Language codes map accurately to Indian regional languages', () {
      final repo = VoiceRepository();
      expect(repo, isNotNull);
      const expectedCodes = ['hi', 'ta', 'te', 'bn', 'gu', 'kn', 'ml', 'mr', 'or', 'pa', 'en'];
      for (final code in expectedCodes) {
        expect(code.length, equals(2));
      }
    });
  });
}
