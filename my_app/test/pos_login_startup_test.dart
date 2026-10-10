import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/providers/pos_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'fresh unpaired device opens login without generating a pairing code',
    () async {
      final pos = PosController();
      addTearDown(pos.dispose);

      await pos.initialize();

      expect(pos.deviceBinding, isNull);
      expect(pos.session, isNull);
      expect(pos.phase, PosAppPhase.login);
      expect(pos.pairingCode, isNull);
      expect(pos.pairingDeviceUuid, isNull);
    },
  );

  test('changing server returns to login and clears pending pairing', () async {
    final pos = PosController();
    addTearDown(pos.dispose);
    await pos.initialize();
    pos.phase = PosAppPhase.pairDevice;
    pos.pairingCode = '123456';
    pos.pairingDeviceUuid = 'pending-device';

    await pos.saveServerUrl('https://example.com');

    expect(pos.phase, PosAppPhase.login);
    expect(pos.pairingCode, isNull);
    expect(pos.pairingDeviceUuid, isNull);
  });
}
