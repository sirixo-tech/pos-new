import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/printing/bluetooth_paper_sensor.dart';
import 'package:my_app/services/printing/printer_paper_sensor.dart';

void main() {
  for (final entry in {
    0x12: PrinterPaperSensor.present,
    0x72: PrinterPaperSensor.empty,
    0x1e: PrinterPaperSensor.present,
  }.entries) {
    test('decodes Bluetooth sensor ${entry.key}', () async {
      final replies = StreamController<List<int>>(sync: true);
      final sensor = await queryBluetoothPaperSensor(
        replies: replies.stream,
        subscribe: () async {},
        request: () async => replies.add([entry.key]),
      );
      expect(sensor, entry.value);
      expect(replies.hasListener, false);
      await replies.close();
    });
  }
  test(
    'ignores stale, invalid and multi-byte replies; timeout is unknown',
    () async {
      final replies = StreamController<List<int>>(sync: true);
      final sensor = await queryBluetoothPaperSensor(
        replies: replies.stream,
        subscribe: () async => replies.add([0x72]),
        request: () async {
          replies.add([0x72, 0x12]);
          replies.add([0]);
        },
        timeout: const Duration(milliseconds: 10),
      );
      expect(sensor, PrinterPaperSensor.unknown);
      expect(replies.hasListener, false);
      await replies.close();
    },
  );
  test('unsupported notifications return unknown and clean up', () async {
    final replies = StreamController<List<int>>();
    var requested = false;
    expect(
      await queryBluetoothPaperSensor(
        replies: replies.stream,
        subscribe: () async => throw StateError('Unsupported'),
        request: () async {
          requested = true;
        },
      ),
      PrinterPaperSensor.unknown,
    );
    expect(requested, false);
    expect(replies.hasListener, false);
    await replies.close();
  });
}
