import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/printing/scan_to_print_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing KOT failure popup preference stays on', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await KotFailurePopupSettings.enabled(), isTrue);
  });

  test('KOT failure popup preference is stored on this device', () async {
    SharedPreferences.setMockInitialValues({});
    await KotFailurePopupSettings.setEnabled(false);
    expect(await KotFailurePopupSettings.enabled(), isFalse);
    await KotFailurePopupSettings.setEnabled(true);
    expect(await KotFailurePopupSettings.enabled(), isTrue);
  });
}
