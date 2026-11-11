import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/weighed_barcode.dart';
import 'scale_line_settings.dart';
import 'scale_reading_session.dart';
import 'scale_transport.dart';

/// Live link to one weighing scale on this register.
class ScaleLink extends ChangeNotifier {
  ScaleLink._() : _transport = createScaleTransport();

  static final ScaleLink instance = ScaleLink._();

  static const _baudKey = 'pos_scale_baud';
  static const _parityKey = 'pos_scale_parity';
  static const _dataBitsKey = 'pos_scale_data_bits';
  static const _unitKey = 'pos_scale_unit';
  static const _commandKey = 'pos_scale_command';

  final ScaleTransport _transport;
  final ScaleFrameBuffer _frames = ScaleFrameBuffer();
  final ScaleReadingSession session = ScaleReadingSession();

  ScaleLineSettings settings = const ScaleLineSettings();
  String? portName;
  String? portLabel;
  String? error;
  bool connecting = false;
  bool connected = false;

  Timer? _readTimer;
  Timer? _pollTimer;
  bool _loaded = false;
  int _readFailures = 0;
  double? _shownKg;
  bool _shownStable = false;

  bool get isSupported => _transport.isSupported;

  double? get netKg => session.netKg;

  bool get stable => session.isStable(DateTime.now());

  String get statusLabel {
    if (connecting) return 'Connecting…';
    if (connected) {
      final port = portLabel ?? portName;
      return port == null || port.isEmpty
          ? 'Scale connected'
          : 'Scale connected · $port';
    }
    if (error != null && error!.isNotEmpty) return error!;
    return 'Scale not connected';
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final baud = prefs.getInt(_baudKey);
      final parity = prefs.getString(_parityKey);
      final bits = prefs.getInt(_dataBitsKey);
      final unit = prefs.getString(_unitKey);
      settings = ScaleLineSettings(
        baud: ScaleLineSettings.baudRates.contains(baud) ? baud! : 9600,
        parity: ScaleLineSettings.parities.contains(parity) ? parity! : 'none',
        dataBits: ScaleLineSettings.dataBitChoices.contains(bits) ? bits! : 8,
        unit: ScaleLineSettings.units.contains(unit) ? unit! : 'auto',
        command: prefs.getString(_commandKey) ?? '',
      );
      notifyListeners();
    } catch (_) {
      _loaded = false;
    }
  }

  Future<void> updateSettings(ScaleLineSettings next) async {
    settings = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_baudKey, next.baud);
      await prefs.setString(_parityKey, next.parity);
      await prefs.setInt(_dataBitsKey, next.dataBits);
      await prefs.setString(_unitKey, next.unit);
      await prefs.setString(_commandKey, next.command);
    } catch (_) {}
  }

  bool get promptsForPort => _transport.promptsForPort;

  Future<List<ScalePortInfo>> listPorts() => _transport.listPorts();

  /// Chrome shows the browser port picker. Call this directly from the button.
  Future<void> connectFromBrowser() async {
    error = null;
    connecting = true;
    connected = false;
    notifyListeners();
    try {
      final port = await _transport.acquirePort();
      await _open(port, keepAcquired: true);
    } catch (caught) {
      connecting = false;
      connected = false;
      portName = null;
      portLabel = null;
      error = _message(caught);
      notifyListeners();
    }
  }

  Future<void> connect(ScalePortInfo port) => _open(port);

  Future<void> _open(ScalePortInfo port, {bool keepAcquired = false}) async {
    await load();
    error = null;
    connecting = true;
    connected = false;
    notifyListeners();
    if (!keepAcquired) {
      try {
        await _transport.close();
      } catch (_) {}
    }
    try {
      await _transport.open(
        name: port.name,
        baud: settings.baud,
        dataBits: settings.dataBits,
        parity: settings.parity,
      );
      _frames.clear();
      session.clear();
      portName = port.name;
      portLabel = port.title;
      connected = true;
      connecting = false;
      _readFailures = 0;
      _shownKg = null;
      _shownStable = false;
      _startLoops();
      notifyListeners();
    } catch (caught) {
      connecting = false;
      connected = false;
      portName = null;
      portLabel = null;
      error = _message(caught);
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _stopLoops();
    connected = false;
    connecting = false;
    portName = null;
    portLabel = null;
    session.clear();
    _frames.clear();
    _shownKg = null;
    _shownStable = false;
    try {
      await _transport.close();
    } catch (_) {}
    notifyListeners();
  }

  void tare() {
    if (!connected) return;
    session.tare();
    _publish(force: true);
  }

  void _startLoops() {
    _stopLoops();
    _readTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      unawaited(_pull());
    });
    final command = settings.commandBytes;
    if (command.isEmpty) return;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      unawaited(_sendPoll(command));
    });
  }

  Future<void> _sendPoll(List<int> command) async {
    if (!connected || command.isEmpty) return;
    try {
      await _transport.write(command);
    } catch (_) {}
  }

  void _stopLoops() {
    _readTimer?.cancel();
    _pollTimer?.cancel();
    _readTimer = null;
    _pollTimer = null;
  }

  Future<void> _pull() async {
    if (!connected) return;
    try {
      final bytes = await _transport.read();
      _readFailures = 0;
      if (bytes.isNotEmpty) {
        final text = utf8.decode(bytes, allowMalformed: true);
        for (final frame in _frames.push(text)) {
          final reading = ScaleFrame.parse(
            frame,
            assumeGrams: settings.assumeGrams,
          );
          if (reading != null) session.add(reading, DateTime.now());
        }
      }
      _publish();
    } catch (caught) {
      _readFailures += 1;
      if (_readFailures < 3) return;
      error = _message(caught);
      await disconnect();
    }
  }

  void _publish({bool force = false}) {
    final kg = session.netKg;
    final isStable = session.isStable(DateTime.now());
    if (!force && kg == _shownKg && isStable == _shownStable) return;
    _shownKg = kg;
    _shownStable = isStable;
    notifyListeners();
  }

  String _message(Object error) {
    if (error is PlatformException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) return message;
    }
    final text = error.toString().replaceFirst('Bad state: ', '');
    return text.replaceFirst('UnsupportedError: ', '').trim();
  }
}
