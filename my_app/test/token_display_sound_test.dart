import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/customer_display/customer_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ready announcement uses the token number', () {
    expect(tokenReadyPhrase('4', 'en-IN'), 'Token number 4 ready');
    expect(tokenReadyPhrase('12', 'en-US'), 'Token number 12 ready');
    expect(tokenReadyPhrase('4', 'hi-IN'), 'टोकन नंबर 4 तैयार है');
  });

  test('token display sounds default on when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final voice = CustomerVoiceService.instance;
    await voice.loadSettings();
    expect(voice.newTokenSoundEnabled, isTrue);
    expect(voice.readyVoiceEnabled, isTrue);
    expect(voice.readyRepeats, 1);
    expect(voice.languageCode, 'en-IN');
    expect(voice.isEnabled, isTrue);
  });

  test('token display sound choices are stored on this device', () async {
    SharedPreferences.setMockInitialValues({});
    final voice = CustomerVoiceService.instance;
    await voice.setNewTokenSoundEnabled(false);
    await voice.setReadyRepeats(3);
    await voice.setLanguageCode('hi-IN');
    await voice.loadSettings();
    expect(voice.newTokenSoundEnabled, isFalse);
    expect(voice.readyVoiceEnabled, isTrue);
    expect(voice.readyRepeats, 3);
    expect(voice.languageCode, 'hi-IN');
  });
}
