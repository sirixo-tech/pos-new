import 'dart:async';

import 'package:flutter/services.dart';

/// Query the saved queue directly; discovery and WMI are not connection checks.
class WindowsPrinterQueue {
  static const _channel = MethodChannel('pos_main/windows_printer');
  static Future<void> _printChain = Future<void>.value();

  static Future<({bool present, bool offline, bool paperOut})> lookup(
    String name,
  ) async {
    final status = await _channel.invokeMapMethod<String, Object?>(
      'getStatus',
      {'name': name},
    );
    if (status == null ||
        status['present'] is! bool ||
        status['offline'] is! bool ||
        status['paperOut'] is! bool) {
      throw StateError('Windows did not return a valid printer status.');
    }
    // Query errors propagate as errors, never as evidence of an unplugged USB.
    if (status['present'] == true && status['physicalUsbChecked'] != true) {
      throw StateError(
        'Printer connection is not verified. Fully close and restart the POS to load the USB connection check.',
      );
    }
    return (
      present: status['present'] == true,
      offline: status['offline'] == true,
      paperOut: status['paperOut'] == true,
    );
  }

  /// Serialize all slips, including test prints, scans, and offline receipts.
  /// Never retry after submission: a failed write may have printed part of it.
  static Future<void> send(String name, List<int> bytes) {
    final run = _printChain.then((_) async {
      try {
        final job = await _channel.invokeMethod<int>('printRaw', {
          'name': name,
          'bytes': Uint8List.fromList(bytes),
        });
        if (job == null || job <= 0) {
          throw StateError(
            'printer write failed: Windows returned no print job.',
          );
        }
      } on PlatformException catch (error) {
        final message = error.message ?? error.code;
        if (error.code == 'PRINTER_CONNECT') throw StateError(message);
        throw StateError('printer write failed: $message');
      }
    });
    _printChain = run.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return run;
  }
}
