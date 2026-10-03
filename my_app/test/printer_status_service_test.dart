import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/printing/pos_receipt_printer.dart';
import 'package:my_app/services/printing/printer_health.dart';
import 'package:my_app/services/printing/printer_status_service.dart';

void main() {
  testWidgets('periodic Bluetooth polls do not attempt reconnects', (
    tester,
  ) async {
    final attempts = <bool>[];
    final config = UsbPrinterConfig(
      name: 'Bluetooth',
      connection: PosPrinterConnection.bluetooth,
    );
    final service = PrinterStatusService(
      loadConfig: () async => config,
      probe: (reconnect) async {
        attempts.add(reconnect);
        return PrinterHealth(state: PrinterHealthState.ready, config: config);
      },
    );
    final started = service.start();
    await tester.pump();
    await started;
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    expect(attempts.first, isTrue);
    expect(attempts.skip(1), everyElement(isFalse));
    expect(attempts.length, greaterThan(6));
    service.dispose();
  });
  testWidgets('disposing during a check ignores its late result', (
    tester,
  ) async {
    final pending = Completer<PrinterHealth>();
    final service = PrinterStatusService(
      loadConfig: () async => UsbPrinterConfig.smartpos(),
      probe: (_) => pending.future,
    );
    final result = service.refresh();
    await tester.pump();
    service.dispose();
    pending.complete(const PrinterHealth(state: PrinterHealthState.ready));
    await result;
    expect(tester.takeException(), isNull);
  });
  for (final connection in [
    PosPrinterConnection.smartpos,
    PosPrinterConnection.bluetooth,
  ]) {
    testWidgets(
      '$connection hung background check finishes within six seconds',
      (tester) async {
        final pending = Completer<PrinterHealth>();
        final config = UsbPrinterConfig(
          name: 'Test printer',
          connection: connection,
        );
        final service = PrinterStatusService(
          loadConfig: () async => config,
          probe: (_) => pending.future,
        );
        final result = service.refresh();
        await tester.pump();
        expect(service.probing, isTrue);
        await tester.pump(const Duration(seconds: 7));
        await result;
        expect(service.probing, isFalse);
        expect(service.health.state, PrinterHealthState.error);
        expect(service.health.message, contains('did not respond'));
        pending.complete(
          PrinterHealth(state: PrinterHealthState.ready, config: config),
        );
        await tester.pump();
        expect(service.health.state, PrinterHealthState.error);
        service.dispose();
      },
    );
  }
  testWidgets('new connection result wins over an older failing probe', (
    tester,
  ) async {
    final pending = Completer<PrinterHealth>();
    final config = UsbPrinterConfig.smartpos(name: 'iMin NM2 Pro');
    final service = PrinterStatusService(
      loadConfig: () async => config,
      probe: (_) => pending.future,
    );
    final result = service.refresh();
    await tester.pump();
    service.applyHealth(
      PrinterHealth(state: PrinterHealthState.ready, config: config),
    );
    pending.complete(
      PrinterHealth(state: PrinterHealthState.missing, config: config),
    );
    await result;
    expect(service.health.state, PrinterHealthState.ready);
    service.dispose();
  });
  testWidgets(
    'Bluetooth reconnect is bounded and dispose ignores late results',
    (tester) async {
      final pending = Completer<PrinterHealth>();
      final config = UsbPrinterConfig(
        name: 'Bluetooth',
        connection: PosPrinterConnection.bluetooth,
      );
      bool? attemptedReconnect;
      final service = PrinterStatusService(
        loadConfig: () async => config,
        probe: (reconnect) {
          attemptedReconnect = reconnect;
          return pending.future;
        },
      );
      final result = service.refresh(allowBluetoothScan: true);
      await tester.pump();
      expect(attemptedReconnect, isTrue);
      await tester.pump(const Duration(seconds: 7));
      expect(service.probing, isTrue);
      await tester.pump(const Duration(seconds: 19));
      await result;
      expect(service.probing, isFalse);
      service.dispose();
      pending.complete(const PrinterHealth(state: PrinterHealthState.ready));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
