import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/scanner_connection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pos_main/scanner_status');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'unplugging overrides recent scan activity even with another keyboard',
    () async {
      var attached = true;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'connected': attached,
          'deviceCount': attached ? 1 : 0,
          'hasHardwareKeyboard': true,
        },
      );
      final scanner = ScannerConnectionService();
      addTearDown(scanner.dispose);
      await scanner.refresh();
      scanner.markInput();
      expect(scanner.connected, isTrue);
      attached = false;
      await scanner.refresh();
      expect(scanner.connected, isFalse);
      expect(scanner.detail, 'Scanner is not connected.');
      expect(scanner.lastInputAt, isNotNull);
      scanner.markInput();
      expect(scanner.connected, isFalse);
      attached = true;
      await scanner.refresh();
      expect(scanner.connected, isTrue);
    },
  );
}
