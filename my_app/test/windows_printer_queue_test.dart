import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/printing/pos_receipt_printer.dart';
import 'package:my_app/services/printing/printer_health.dart';
import 'package:my_app/services/printing/windows_printer_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pos_main/windows_printer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(WindowsUsbConnectionStability.shared.reset);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    PrinterScanRelease.onStop = null;
  });

  test(
    'legacy queue-only Ready cannot bypass physical USB verification',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'present': true, 'offline': false, 'paperOut': false},
      );
      await expectLater(
        WindowsPrinterQueue.lookup('TVSE RP3200 Lite'),
        throwsA(isA<StateError>()),
      );
    },
  );
  test('status errors are not reported as a disconnected queue', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'PRINTER_STATUS', message: 'Access denied');
    });
    await expectLater(
      WindowsPrinterQueue.lookup('TVSE RP3200 Lite'),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'printer setup receives error health when a native response is invalid',
    () async {
      SharedPreferences.setMockInitialValues({});
      await UsbPrinterStorage.save(UsbPrinterConfig(name: 'TVSE RP3200 Lite'));
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw const FormatException('Missing extension byte (at offset 1)');
      });
      final health = await PosReceiptPrinter.probe();
      expect(health.state, PrinterHealthState.error);
      expect(health.config?.name, 'TVSE RP3200 Lite');
      expect(health.message, contains('Could not check printer status'));
      expect(health.issues, isNot(contains('missing')));
    },
    skip: !Platform.isWindows,
  );

  test('missing queues and paper out remain visible', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'present': false, 'offline': true, 'paperOut': false},
    );
    expect(await WindowsPrinterQueue.lookup('TVSE RP3200 Lite'), (
      present: false,
      offline: true,
      paperOut: false,
    ));
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'present': true,
        'offline': false,
        'paperOut': true,
        'physicalUsbChecked': true,
      },
    );
    expect(
      (await WindowsPrinterQueue.lookup('TVSE RP3200 Lite')).paperOut,
      isTrue,
    );
  });

  test(
    'Windows polls use the saved queue without thermal discovery',
    () async {
      SharedPreferences.setMockInitialValues({});
      await UsbPrinterStorage.save(UsbPrinterConfig(name: 'TVSE RP3200 Lite'));
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getStatus');
        expect(call.arguments, {'name': 'TVSE RP3200 Lite'});
        return {
          'present': true,
          'offline': false,
          'paperOut': false,
          'physicalUsbChecked': true,
        };
      });
      expect((await PosReceiptPrinter.probe()).state, PrinterHealthState.ready);
    },
    skip: !Platform.isWindows,
  );

  test(
    'concurrent slips are serialized and write failures are not resent',
    () async {
      final first = Completer<int>();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        expect((call.arguments as Map)['bytes'], isA<Uint8List>());
        if (calls.length == 1) return first.future;
        return 2;
      });
      final one = WindowsPrinterQueue.send('TVSE RP3200 Lite', [1, 2]);
      final two = WindowsPrinterQueue.send('TVSE RP3200 Lite', [3, 4]);
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(1));
      first.completeError(
        PlatformException(code: 'PRINTER_WRITE', message: 'Partial write'),
      );
      await expectLater(
        one,
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('printer write failed'),
          ),
        ),
      );
      await two;
      expect(calls, hasLength(2));
      expect((calls.last.arguments as Map)['bytes'], [3, 4]);
    },
  );

  test(
    'connect failures can be retried but are not automatically resent',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        throw PlatformException(
          code: 'PRINTER_CONNECT',
          message: 'Queue offline',
        );
      });
      await expectLater(
        WindowsPrinterQueue.send('TVSE RP3200 Lite', [1]),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            isNot(contains('printer write failed')),
          ),
        ),
      );
      expect(calls, 1);
    },
  );

  test('one missed USB sample stays ready and the next is disconnected', () {
    final stability = WindowsUsbConnectionStability();
    PrinterHealth sample(PrinterHealthState state, {String name = 'USB'}) {
      return PrinterHealth(
        state: state,
        config: UsbPrinterConfig(name: name),
        issues: state == PrinterHealthState.missing
            ? const ['offline']
            : const [],
        message: state == PrinterHealthState.ready ? 'Ready' : 'Offline',
      );
    }

    expect(
      stability.apply(sample(PrinterHealthState.missing)).state,
      PrinterHealthState.missing,
    );
    stability.reset();
    expect(
      stability.apply(sample(PrinterHealthState.ready)).state,
      PrinterHealthState.ready,
    );
    expect(
      stability.apply(sample(PrinterHealthState.missing)).state,
      PrinterHealthState.ready,
    );
    expect(
      stability.apply(sample(PrinterHealthState.missing)).state,
      PrinterHealthState.missing,
    );
    expect(
      stability.apply(sample(PrinterHealthState.missing)).state,
      PrinterHealthState.missing,
    );
    expect(
      stability.apply(sample(PrinterHealthState.ready)).state,
      PrinterHealthState.ready,
    );
    expect(
      stability.apply(sample(PrinterHealthState.missing, name: 'Other')).state,
      PrinterHealthState.missing,
    );
  });

  test(
    'probe keeps a Windows USB queue ready through one offline sample',
    () async {
      SharedPreferences.setMockInitialValues({});
      await UsbPrinterStorage.save(UsbPrinterConfig(name: 'TVSE RP3200 Lite'));
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls += 1;
        return {
          'present': true,
          'offline': calls == 2 || calls == 3,
          'paperOut': false,
          'physicalUsbChecked': true,
        };
      });
      expect((await PosReceiptPrinter.probe()).state, PrinterHealthState.ready);
      expect((await PosReceiptPrinter.probe()).state, PrinterHealthState.ready);
      final disconnected = await PosReceiptPrinter.probe();
      expect(disconnected.state, PrinterHealthState.missing);
      expect(disconnected.issues, contains('offline'));
      expect((await PosReceiptPrinter.probe()).state, PrinterHealthState.ready);
    },
    skip: !Platform.isWindows,
  );

  test(
    'Windows USB listing stops USB discovery and leaves Bluetooth scanning',
    () async {
      final calls = <String>[];
      PrinterScanRelease.onStop =
          ({required bool stopBle, required bool stopUsb}) async {
            calls.add('$stopBle:$stopUsb');
          };
      await PrinterScanRelease.usbListing(
        windows: false,
        stopUsbOnly: () async => calls.add('usb-plugin'),
      );
      await PrinterScanRelease.usbListing(
        windows: true,
        stopUsbOnly: () async => calls.add('usb-plugin'),
      );
      await PrinterScanRelease.bluetooth(
        stopBluetooth: () async => calls.add('bluetooth-plugin'),
      );
      expect(calls, ['false:true', 'true:true']);
    },
  );
}
