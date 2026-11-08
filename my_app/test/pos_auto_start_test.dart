import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/pos_auto_start.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PosAutoStart defaults to enabled (true) on first launch', () async {
    await PosAutoStart.initialize();
    expect(PosAutoStart.isEnabled, isTrue);
    expect(PosAutoStart.notifier.value, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PosAutoStart.prefsKey), isTrue);
  });

  test('PosAutoStart can be toggled and disabled', () async {
    await PosAutoStart.initialize();
    expect(PosAutoStart.isEnabled, isTrue);

    // Disable
    final disabled = await PosAutoStart.setEnabled(false);
    expect(disabled, isFalse);
    expect(PosAutoStart.isEnabled, isFalse);
    expect(PosAutoStart.notifier.value, isFalse);

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PosAutoStart.prefsKey), isFalse);

    // Toggle back to enabled
    final toggled = await PosAutoStart.toggle();
    expect(toggled, isTrue);
    expect(PosAutoStart.isEnabled, isTrue);
    expect(PosAutoStart.notifier.value, isTrue);

    prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PosAutoStart.prefsKey), isTrue);
  });

  test('PosAutoStart restores existing false preference upon initialize', () async {
    SharedPreferences.setMockInitialValues({
      PosAutoStart.prefsKey: false,
    });

    await PosAutoStart.initialize();
    expect(PosAutoStart.isEnabled, isFalse);
    expect(PosAutoStart.notifier.value, isFalse);
  });
}
