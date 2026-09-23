import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'usb_printer_config.dart';

/// macOS CUPS + USB discovery via native [UsbDiscoveryPlugin].
class MacosUsbDiscovery {
  MacosUsbDiscovery._();

  static const _channel = MethodChannel('serveai_pos/usb');

  static Future<List<UsbPrinterDevice>> listDevices() async {
    if (!Platform.isMacOS) {
      return [];
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('listDevices');
      if (result == null) {
        return [];
      }

      return result.map((entry) {
        final map = Map<String, dynamic>.from(entry as Map);
        return _deviceFromMap(map);
      }).toList();
    } catch (e, st) {
      debugPrint('macOS USB discovery failed: $e\n$st');
      return [];
    }
  }

  /// CUPS queue state (paper out / offline / paused) for a saved printer.
  static Future<Map<String, dynamic>?> getPrinterStatus(String queueName) async {
    if (!Platform.isMacOS) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod<dynamic>('getPrinterStatus', {
        'name': queueName,
      });
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e, st) {
      debugPrint('macOS printer status failed: $e\n$st');
      return null;
    }
  }

  static UsbPrinterDevice _deviceFromMap(Map<String, dynamic> map) {
    final issues = (map['issues'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return UsbPrinterDevice(
      name: map['name']?.toString() ?? 'USB device',
      address: map['address']?.toString() ?? '',
      connection: PosPrinterConnection.usb,
      printable: map['printable'] == true,
      source: map['source']?.toString() ?? 'cups',
      cupsState: map['state']?.toString(),
      issues: issues,
      statusMessage: map['message']?.toString(),
    );
  }

  /// Raw ESC/POS to a macOS CUPS queue via native libcups (sandbox-safe).
  static Future<void> printRawBytes({
    required String queueName,
    required List<int> bytes,
  }) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('CUPS raw print is only supported on macOS');
    }

    if (bytes.isEmpty) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('printRaw', {
        'name': queueName,
        'data': Uint8List.fromList(bytes),
      });
    } on PlatformException catch (e) {
      throw StateError(e.message ?? 'CUPS raw print failed for "$queueName".');
    }
  }
}
