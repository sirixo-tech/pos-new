import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'scale_port.dart';

export 'scale_port.dart';

ScaleTransport createScaleTransport() => _WebSerialScaleTransport();

@JS('navigator.serial')
external JSObject? get _navigatorSerial;

extension type _Serial._(JSObject _) implements JSObject {
  external JSPromise<JSObject> requestPort();
}

extension type _SerialPort._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> open(_SerialOptions options);
  external JSPromise<JSAny?> close();
  external _ReadableStream? get readable;
  external _WritableStream? get writable;
}

extension type _SerialOptions._(JSObject _) implements JSObject {
  external factory _SerialOptions({
    required int baudRate,
    required int dataBits,
    required int stopBits,
    required String parity,
  });
}

extension type _ReadableStream._(JSObject _) implements JSObject {
  external _StreamReader getReader();
}

extension type _StreamReader._(JSObject _) implements JSObject {
  external JSPromise<JSObject> read();
  external JSPromise<JSAny?> cancel();
}

extension type _ReadResult._(JSObject _) implements JSObject {
  external JSAny? get value;
  external bool get done;
}

extension type _WritableStream._(JSObject _) implements JSObject {
  external _StreamWriter getWriter();
}

extension type _StreamWriter._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> write(JSUint8Array chunk);
  external JSPromise<JSAny?> close();
}

class _WebSerialScaleTransport implements ScaleTransport {
  _SerialPort? _port;
  _StreamReader? _reader;
  _StreamWriter? _writer;
  final List<int> _pending = [];
  bool _reading = false;
  Object? _fault;

  @override
  bool get isSupported => _navigatorSerial != null;

  @override
  bool get promptsForPort => isSupported;

  @override
  Future<List<ScalePortInfo>> listPorts() async => const [];

  @override
  Future<ScalePortInfo> acquirePort() async {
    final serial = _navigatorSerial;
    if (serial == null) {
      throw UnsupportedError(
        'Open this register in Chrome or Edge to connect a scale.',
      );
    }
    try {
      final granted = await _Serial._(serial).requestPort().toDart;
      _port = _SerialPort._(granted);
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('abort') ||
          text.contains('cancel') ||
          text.contains('not found') ||
          text.contains('no port')) {
        throw StateError('No scale was selected.');
      }
      rethrow;
    }
    return const ScalePortInfo(name: 'browser', label: 'USB scale');
  }

  @override
  Future<void> open({
    required String name,
    required int baud,
    required int dataBits,
    required String parity,
  }) async {
    final port = _port;
    if (port == null) {
      throw StateError('Choose a scale before connecting.');
    }
    _fault = null;
    await port
        .open(
          _SerialOptions(
            baudRate: baud,
            dataBits: dataBits == 7 ? 7 : 8,
            stopBits: 1,
            parity: parity == 'even' || parity == 'odd' ? parity : 'none',
          ),
        )
        .toDart;
    final readable = port.readable;
    final writable = port.writable;
    if (readable == null || writable == null) {
      throw StateError('The browser did not open the scale port.');
    }
    _reader = readable.getReader();
    _writer = writable.getWriter();
    _reading = true;
    unawaited(_pump());
  }

  Future<void> _pump() async {
    final reader = _reader;
    if (reader == null) return;
    try {
      while (_reading) {
        final raw = await reader.read().toDart;
        final result = _ReadResult._(raw);
        if (result.done) break;
        final value = result.value;
        if (value == null) continue;
        final bytes = (value as JSUint8Array).toDart;
        _pending.addAll(bytes);
        if (_pending.length > 8192) {
          _pending.removeRange(0, _pending.length - 4096);
        }
      }
    } catch (error) {
      _fault = error;
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    final writer = _writer;
    if (writer == null || bytes.isEmpty) return;
    final data = Uint8List.fromList(bytes);
    await writer.write(data.toJS).toDart;
  }

  @override
  Future<List<int>> read() async {
    final fault = _fault;
    if (fault != null) throw fault;
    if (_pending.isEmpty) return const [];
    final bytes = List<int>.from(_pending);
    _pending.clear();
    return bytes;
  }

  @override
  Future<void> close() async {
    _reading = false;
    final reader = _reader;
    final writer = _writer;
    final port = _port;
    _reader = null;
    _writer = null;
    _port = null;
    _pending.clear();
    try {
      await reader?.cancel().toDart;
    } catch (_) {}
    try {
      await writer?.close().toDart;
    } catch (_) {}
    try {
      await port?.close().toDart;
    } catch (_) {}
  }
}
