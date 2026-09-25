import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'printer_paper_sensor.dart';

/// Raw ESC/POS over TCP (JetDirect / port 9100).
class NetworkPrinter {
  NetworkPrinter._();

  static const int defaultPort = 9100;

  static Future<void> sendBytes(
    String host,
    int port,
    List<int> bytes, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    try {
      socket.add(Uint8List.fromList(bytes));
      await socket.flush();
    } catch (error) {
      throw StateError('printer write failed: $error');
    } finally {
      await socket.close();
    }
  }

  /// ESC/POS `DLE EOT 4`. Unreadable replies stay unknown — never “empty”.
  static Future<PrinterPaperSensor> readPaperSensor(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    final reply = Completer<int?>();
    final subscription = socket.listen(
      (bytes) {
        if (reply.isCompleted) return;
        reply.complete(bytes.isEmpty ? null : bytes.first);
      },
      onError: (Object _) {
        if (!reply.isCompleted) reply.complete(null);
      },
      onDone: () {
        if (!reply.isCompleted) reply.complete(null);
      },
    );
    try {
      socket.add(const [0x10, 0x04, 0x04]);
      await socket.flush();
      final byte = await reply.future.timeout(
        const Duration(milliseconds: 700),
        onTimeout: () => null,
      );
      if (byte == null) return PrinterPaperSensor.unknown;
      return decodeEscPosPaperSensor(byte);
    } on Object {
      return PrinterPaperSensor.unknown;
    } finally {
      await subscription.cancel();
      socket.destroy();
    }
  }

  /// Soft reachability check (open + close). Does not send print data.
  static Future<void> probe(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    await socket.close();
  }
}
