import 'dart:io';

import 'package:flutter/services.dart';

import 'scale_port.dart';

export 'scale_port.dart';

ScaleTransport createScaleTransport() => _ChannelScaleTransport();

class _ChannelScaleTransport implements ScaleTransport {
  static const _channel = MethodChannel('pos_main/scale');

  @override
  bool get isSupported => Platform.isWindows || Platform.isAndroid;

  @override
  bool get promptsForPort => false;

  @override
  Future<ScalePortInfo> acquirePort() {
    throw UnsupportedError(
      'Choose the scale from the ports on this device.',
    );
  }

  @override
  Future<List<ScalePortInfo>> listPorts() async {
    if (!isSupported) return const [];
    final raw = await _channel.invokeMethod<List<dynamic>>('listPorts');
    return [
      for (final entry in raw ?? const [])
        if (entry is Map)
          ScalePortInfo(
            name: '${entry['name'] ?? ''}'.trim(),
            label: entry['label']?.toString(),
          ),
    ].where((port) => port.name.isNotEmpty).toList(growable: false);
  }

  @override
  Future<void> open({
    required String name,
    required int baud,
    required int dataBits,
    required String parity,
  }) {
    if (!isSupported) {
      throw UnsupportedError(
        'Scale connection is available in Chrome, Windows, and Android.',
      );
    }
    return _channel.invokeMethod<void>('open', {
      'name': name,
      'baud': baud,
      'dataBits': dataBits,
      'parity': parity,
    });
  }

  @override
  Future<void> write(List<int> bytes) {
    return _channel.invokeMethod<void>('write', {
      'bytes': Uint8List.fromList(bytes),
    });
  }

  @override
  Future<List<int>> read() async {
    final raw = await _channel.invokeMethod<Object?>('read');
    if (raw is Uint8List) return raw;
    if (raw is List) return raw.cast<int>();
    return const [];
  }

  @override
  Future<void> close() {
    return _channel.invokeMethod<void>('close');
  }
}
