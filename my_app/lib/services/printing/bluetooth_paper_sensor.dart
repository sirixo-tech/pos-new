import 'dart:async';

import 'printer_paper_sensor.dart';

/// Listen before requesting ESC/POS paper status. Unsupported printers return
/// unknown; missing replies must never be treated as paper present or empty.
Future<PrinterPaperSensor> queryBluetoothPaperSensor({
  required Stream<List<int>> replies,
  required Future<void> Function() subscribe,
  required Future<void> Function() request,
  Duration timeout = const Duration(milliseconds: 800),
}) async {
  final result = Completer<PrinterPaperSensor>();
  var requested = false;
  final listener = replies.listen(
    (bytes) {
      if (!requested || bytes.length != 1 || result.isCompleted) return;
      final sensor = decodeEscPosPaperSensor(bytes.single);
      if (sensor != PrinterPaperSensor.unknown) result.complete(sensor);
    },
    onError: (Object error) {
      if (!result.isCompleted) result.complete(PrinterPaperSensor.unknown);
    },
  );
  try {
    await subscribe().timeout(timeout);
    requested = true;
    await request().timeout(timeout);
    return await result.future.timeout(
      timeout,
      onTimeout: () => PrinterPaperSensor.unknown,
    );
  } on Object {
    return PrinterPaperSensor.unknown;
  } finally {
    await listener.cancel();
  }
}
