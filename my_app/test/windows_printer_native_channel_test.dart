import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Build windows/tests first. This checks real C++ replies with Dart's codec,
// rather than mocking the native half of the method channel.
void main() {
  final exe = File(
    'build/native-printer-tests/Debug/windows_printer_channel_test.exe',
  );
  test(
    'native printer replies decode correctly in Dart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pos-native-channel-',
      );
      try {
        final result = await Process.run(exe.absolute.path, [
          directory.path,
          'TVSE RP3200 Lite',
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        const codec = StandardMethodCodec();
        final present = codec.decodeEnvelope(
          ByteData.sublistView(
            await File('${directory.path}/reply0.bin').readAsBytes(),
          ),
        );
        // The configured physical queue may be absent on another machine.
        expect(present, containsPair('present', isA<bool>()));
        expect(present, containsPair('offline', isA<bool>()));
        expect(present, containsPair('paperOut', isA<bool>()));
        final missing = codec.decodeEnvelope(
          ByteData.sublistView(
            await File('${directory.path}/reply1.bin').readAsBytes(),
          ),
        );
        expect(missing, {'present': false, 'offline': true, 'paperOut': false});
        final invalid = ByteData.sublistView(
          await File('${directory.path}/reply2.bin').readAsBytes(),
        );
        expect(
          () => codec.decodeEnvelope(invalid),
          throwsA(
            isA<PlatformException>()
                .having((error) => error.code, 'code', 'PRINTER_CONNECT')
                .having(
                  (error) => error.message,
                  'message',
                  'Select a Windows printer queue.',
                ),
          ),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows || !exe.existsSync(),
  );
}
