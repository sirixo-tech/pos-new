import 'dart:async';

import 'package:flutter/services.dart';

import 'printer_health.dart';

/// Query the saved queue directly. Presence is the plugged-in USB interface.
/// The spooler offline word is not a cable check, and this call does not open
/// the printer.
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

/// Keeps one empty USB sample from flipping a printer that was ready.
///
/// The first sample is shown as it arrived. After a ready sample, one missing
/// sample stays ready. The next missing sample is shown. A ready sample is
/// shown on the check that finds the printer again.
class WindowsUsbConnectionStability {
  static final WindowsUsbConnectionStability shared =
      WindowsUsbConnectionStability();

  String? _name;
  bool _wasReady = false;
  int _misses = 0;

  void reset() {
    _name = null;
    _wasReady = false;
    _misses = 0;
  }

  PrinterHealth apply(PrinterHealth raw) {
    final name = raw.config?.name ?? '';
    if (name != _name) {
      _name = name;
      _misses = 0;
      _wasReady = raw.state == PrinterHealthState.ready;
      return raw;
    }
    if (raw.state != PrinterHealthState.missing) {
      _misses = 0;
      _wasReady = raw.state == PrinterHealthState.ready;
      return raw;
    }
    if (!_wasReady) return raw;
    _misses += 1;
    if (_misses < 2) {
      return PrinterHealth(
        state: PrinterHealthState.ready,
        config: raw.config,
        message: 'Ready',
        lastCheckedAt: raw.lastCheckedAt,
      );
    }
    _wasReady = false;
    _misses = 0;
    return raw;
  }
}

/// Stops the printer-list timer after a scan without owning the plugin.
class PrinterScanRelease {
  static Future<void> Function({required bool stopBle, required bool stopUsb})?
  onStop;

  static Future<void> usbListing({
    required bool windows,
    required Future<void> Function() stopUsbOnly,
  }) async {
    if (!windows) return;
    final hook = onStop;
    if (hook != null) {
      await hook(stopBle: false, stopUsb: true);
      return;
    }
    await stopUsbOnly();
  }

  static Future<void> bluetooth({
    required Future<void> Function() stopBluetooth,
  }) async {
    final hook = onStop;
    if (hook != null) {
      await hook(stopBle: true, stopUsb: true);
      return;
    }
    await stopBluetooth();
  }
}
