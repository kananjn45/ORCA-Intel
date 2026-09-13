import 'package:flutter_test/flutter_test.dart';
import 'package:orca_mobile/core/utils/audio_player_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AudioPlayerHelper initializes without error', () {
    final helper = AudioPlayerHelper();
    expect(helper.isPlaying, false);
    expect(helper.isEmergencyBuzzerActive, false);
    helper.dispose();
  });

  test('AudioPlayerHelper generates siren wav bytes', () {
    final wav = AudioPlayerHelper.generateEmergencySirenWav(durationSeconds: 0.5);
    expect(wav.length, greaterThan(100));
    expect(wav[0], 0x52); // 'R'
    expect(wav[1], 0x49); // 'I'
    expect(wav[2], 0x46); // 'F'
    expect(wav[3], 0x46); // 'F'
  });
}
