import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'network_printer.dart';

const posUsbPrinterKey = 'pos_usb_printer';

/// How the receipt printer is connected.
enum PosPrinterConnection {
  usb,
  bluetooth,
  network,
  smartpos;

  static PosPrinterConnection fromStorage(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'bluetooth':
      case 'ble':
      case 'bt':
        return PosPrinterConnection.bluetooth;
      case 'network':
      case 'lan':
      case 'ethernet':
      case 'wifi':
      case 'tcp':
        return PosPrinterConnection.network;
      case 'smartpos':
      case 'builtin':
      case 'built-in':
      case 'built_in':
        return PosPrinterConnection.smartpos;
      default:
        return PosPrinterConnection.usb;
    }
  }

  String get storageValue => switch (this) {
        PosPrinterConnection.usb => 'usb',
        PosPrinterConnection.bluetooth => 'bluetooth',
        PosPrinterConnection.network => 'network',
        PosPrinterConnection.smartpos => 'smartpos',
      };

  String get label => switch (this) {
        PosPrinterConnection.usb => 'USB',
        PosPrinterConnection.bluetooth => 'Bluetooth',
        PosPrinterConnection.network => 'LAN',
        PosPrinterConnection.smartpos => 'Built-in',
      };
}

class UsbPrinterConfig {
  UsbPrinterConfig({
    required this.name,
    this.address = '',
    this.connection = PosPrinterConnection.usb,
    this.source = 'cups',
    this.host,
    this.port = NetworkPrinter.defaultPort,
  });

  final String name;
  final String address;
  final PosPrinterConnection connection;

  /// `cups` | `usb` | `bluetooth` | `network` — transport hint.
  final String source;

  /// LAN printer hostname or IP (network connection only).
  final String? host;

  /// LAN raw TCP port (default 9100).
  final int port;

  String get networkEndpoint {
    final h = (host ?? '').trim();
    if (h.isEmpty) return address;
    return '$h:$port';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'connection': connection.storageValue,
        'source': source,
        if (host != null && host!.trim().isNotEmpty) 'host': host!.trim(),
        'port': port,
      };

  factory UsbPrinterConfig.fromJson(Map<String, dynamic> json) {
    final connection = PosPrinterConnection.fromStorage(
      json['connection'] as String?,
    );
    var host = (json['host'] as String?)?.trim();
    var port = NetworkPrinter.defaultPort;
    final rawPort = json['port'];
    if (rawPort is int) {
      port = rawPort;
    } else if (rawPort != null) {
      port = int.tryParse('$rawPort') ?? NetworkPrinter.defaultPort;
    }

    // Back-compat: host:port stored only in address.
    if ((host == null || host.isEmpty) && connection == PosPrinterConnection.network) {
      final address = (json['address'] as String? ?? '').trim();
      final parts = address.split(':');
      if (parts.length >= 2) {
        host = parts.first.trim();
        port = int.tryParse(parts.last.trim()) ?? port;
      } else if (address.isNotEmpty) {
        host = address;
      }
    }

    return UsbPrinterConfig(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      connection: connection,
      source: json['source'] as String? ??
          (connection == PosPrinterConnection.network
              ? 'network'
              : connection == PosPrinterConnection.smartpos
                  ? 'smartpos'
                  : 'cups'),
      host: host,
      port: port.clamp(1, 65535),
    );
  }

  static UsbPrinterConfig network({
    required String host,
    int port = NetworkPrinter.defaultPort,
    String? name,
  }) {
    final h = host.trim();
    final p = port.clamp(1, 65535);
    final label = (name ?? '').trim().isNotEmpty
        ? name!.trim()
        : 'LAN printer ($h)';
    return UsbPrinterConfig(
      name: label,
      address: '$h:$p',
      connection: PosPrinterConnection.network,
      source: 'network',
      host: h,
      port: p,
    );
  }

  static UsbPrinterConfig smartpos({String? name}) {
    return UsbPrinterConfig(
      name: (name ?? '').trim().isNotEmpty ? name!.trim() : 'Built-in printer',
      address: 'smartpos',
      connection: PosPrinterConnection.smartpos,
      source: 'smartpos',
    );
  }
}

class UsbPrinterDevice {
  const UsbPrinterDevice({
    required this.name,
    this.address = '',
    this.connection = PosPrinterConnection.usb,
    this.printable = true,
    this.source = 'cups',
    this.cupsState,
    this.issues = const [],
    this.statusMessage,
    this.reachable = true,
  });

  final String name;
  final String address;
  final PosPrinterConnection connection;
  final bool printable;
  final String source;
  final String? cupsState;
  final List<String> issues;
  final String? statusMessage;

  /// False when the platform already knows this USB device is unplugged.
  final bool reachable;
}

class UsbPrinterStorage {
  static Future<UsbPrinterConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(posUsbPrinterKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UsbPrinterConfig.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(UsbPrinterConfig? config) async {
    final prefs = await SharedPreferences.getInstance();
    if (config == null) {
      await prefs.remove(posUsbPrinterKey);
      return;
    }
    await prefs.setString(posUsbPrinterKey, jsonEncode(config.toJson()));
  }
}
