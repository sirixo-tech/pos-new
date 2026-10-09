import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/printing/bluetooth_print_transport.dart';

void main() {
  test(
    'paper-out stays retryable without becoming a partial write error',
    () async {
      final error = StateError('Printer paper out.');
      await expectLater(
        sendBluetoothPrint(
          isConnected: () async => true,
          connect: () async => true,
          write: () async => throw error,
          connectionError: 'disconnected',
        ),
        throwsA(same(error)),
      );
    },
  );
  test('idle disconnect reconnects before sending the next ticket', () async {
    final calls = <String>[];
    await sendBluetoothPrint(
      isConnected: () async => false,
      connect: () async {
        calls.add('connect');
        return true;
      },
      write: () async {
        calls.add('write');
      },
      connectionError: 'disconnected',
    );
    expect(calls, ['connect', 'write']);
  });
  test('a live link is not disconnected or reconnected for printing', () async {
    var writes = 0;
    await sendBluetoothPrint(
      isConnected: () async => true,
      connect: () async => throw StateError('unexpected reconnect'),
      write: () async {
        writes++;
      },
      connectionError: 'disconnected',
    );
    expect(writes, 1);
  });
  test('failed connection sends no bytes', () async {
    await expectLater(
      sendBluetoothPrint(
        isConnected: () async => false,
        connect: () async => false,
        write: () async => fail('must not write'),
        connectionError: 'disconnected',
      ),
      throwsStateError,
    );
  });
  test('partial write fails without replaying a duplicate ticket', () async {
    var writes = 0;
    await expectLater(
      sendBluetoothPrint(
        isConnected: () async => true,
        connect: () async => true,
        write: () async {
          writes++;
          throw StateError('link lost mid-ticket');
        },
        connectionError: 'disconnected',
      ),
      throwsA(
        predicate((error) => error.toString().contains('printer write failed')),
      ),
    );
    expect(writes, 1);
  });
}
