import 'package:flutter/services.dart';

const _channel = MethodChannel('selfx_pos/usb_customer_display');

Future<String?> findAndroidUsbCustomerDisplay(String device) async {
  final result = await _channel.invokeMapMethod<String, Object?>(
    'getStatus',
    <String, Object?>{'device': device},
  );
  if (result?['connected'] != true) return null;
  return result?['port']?.toString();
}

Future<void> writeAndroidDq11Frame(Uint8List frame) async {
  await _channel.invokeMethod<void>('writeDq11Frame', <String, Object?>{
    'frame': frame,
    'baudRate': 921600,
  });
}

Future<String> writeAndroidDqr222Commands(List<String> commands) async {
  return await _channel.invokeMethod<String>(
        'writeDqr222Commands',
        <String, Object?>{'commands': commands, 'baudRate': 230400},
      ) ??
      '';
}

Future<String> readAndroidDqr222FileInfo({bool audio = false}) async {
  return await _channel.invokeMethod<String>('readDqr222FileInfo', {
        'audio': audio,
      }) ??
      '';
}

Future<Map<String, Object?>> uploadAndroidDqr222Advertisement({
  required String fileName,
  required Uint8List bytes,
  required int chunkSize,
  bool audio = false,
}) async {
  final result = await _channel.invokeMapMethod<String, Object?>(
    'uploadDqr222Advertisement',
    <String, Object?>{
      'fileName': fileName,
      'bytes': bytes,
      'chunkSize': chunkSize,
      'audio': audio,
    },
  );
  if (result == null) {
    throw StateError('DQR-222 did not return an upload result.');
  }
  return result;
}
