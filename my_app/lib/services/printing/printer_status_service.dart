import 'dart:async';

import 'package:flutter/widgets.dart';

import 'pos_receipt_printer.dart';
import 'print_skipped.dart';
import 'printer_health.dart';

/// App-bar printer health: USB / LAN / built-in are probed every few seconds.
/// Bluetooth checks live links without scanning and reconnects after a drop.
class PrinterStatusService extends ChangeNotifier with WidgetsBindingObserver {
  PrinterStatusService({
    Future<PrinterHealth> Function(bool reconnect)? probe,
    Future<UsbPrinterConfig?> Function()? loadConfig,
  }) : _probe =
           probe ??
           ((reconnect) =>
               PosReceiptPrinter.probe(allowBluetoothScan: reconnect)),
       _loadConfig = loadConfig ?? UsbPrinterStorage.load {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _pollInterval = Duration(seconds: 5);
  final Future<PrinterHealth> Function(bool reconnect) _probe;
  final Future<UsbPrinterConfig?> Function() _loadConfig;
  bool _disposed = false;
  int _revision = 0;

  PrinterHealth _health = const PrinterHealth(state: PrinterHealthState.none);
  bool _probing = false;
  bool _started = false;
  bool _hasProbed = false;
  Timer? _timer;
  StreamSubscription<dynamic>? _usbHardware;
  Future<void>? _flight;
  bool _queued = false;
  bool _queuedScan = false;

  PrinterHealth get health => _health;
  bool get probing => _probing;
  bool get hasProbed => _hasProbed;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh(allowBluetoothScan: true);
    if (_disposed) return;
    _usbHardware ??= PosReceiptPrinter.watchUsbHardware(() {
      unawaited(refresh());
    });
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) {
      if (!_probing) unawaited(refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh(allowBluetoothScan: true));
    }
  }

  /// Soft probe. One check runs at a time. A newer request waits and then
  /// runs once, so a slow USB or LAN failure is never dropped.
  /// Bluetooth never discovery-scans here. [allowBluetoothScan] only allows
  /// one connect to the saved address (start, resume, setup).
  Future<void> refresh({bool allowBluetoothScan = false}) {
    if (_disposed) return Future.value();
    final current = _flight;
    if (current != null) {
      _queued = true;
      if (allowBluetoothScan) _queuedScan = true;
      return current;
    }
    final run = _refreshOnce(allowBluetoothScan: allowBluetoothScan);
    _flight = run;
    return run.whenComplete(() {
      _flight = null;
      if (_disposed || !_queued) return;
      final scan = _queuedScan;
      _queued = false;
      _queuedScan = false;
      unawaited(refresh(allowBluetoothScan: scan));
    });
  }

  Future<void> _refreshOnce({required bool allowBluetoothScan}) async {
    if (!PosReceiptPrinter.isSupported) {
      _setHealth(
        PrinterHealth(
          state: PrinterHealthState.unsupported,
          message: PosReceiptPrinter.unsupportedMessage,
          lastCheckedAt: DateTime.now(),
        ),
      );
      return;
    }

    final revision = _revision;
    UsbPrinterConfig? config;
    try {
      config = await _loadConfig().timeout(const Duration(seconds: 3));
    } catch (error) {
      if (!_disposed && revision == _revision) {
        _setHealth(
          PrinterHealth(
            state: PrinterHealthState.error,
            message:
                'Could not load printer settings. Open Printer setup and try again.',
            lastCheckedAt: DateTime.now(),
          ),
        );
      }
      return;
    }
    if (_disposed || revision != _revision) return;
    if (config == null || config.name.trim().isEmpty) {
      _setHealth(
        PrinterHealth(
          state: PrinterHealthState.none,
          message: null,
          lastCheckedAt: DateTime.now(),
        ),
      );
      return;
    }

    _probing = true;
    notifyListeners();
    final reconnect = allowBluetoothScan ||
        (config.connection == PosPrinterConnection.bluetooth &&
            _health.config?.address == config.address &&
            (_health.state == PrinterHealthState.missing ||
                _health.state == PrinterHealthState.error));
    try {
      final next = await _probe(reconnect).timeout(
        Duration(
          seconds:
              config.connection == PosPrinterConnection.bluetooth &&
                  reconnect
              ? 25
              : 6,
        ),
      );
      if (!_disposed && revision == _revision) _setHealth(next);
    } catch (e, st) {
      if (_disposed || revision != _revision) return;
      debugPrint('PrinterStatusService.refresh failed: $e\n$st');
      _setHealth(
        PrinterHealth(
          state: PrinterHealthState.error,
          config: config,
          message: e is TimeoutException
              ? 'Printer did not respond. Check the connection, then refresh or test print.'
              : e.toString(),
          issues: PrinterHealth.issuesFromErrorMessage(e.toString()),
          lastCheckedAt: DateTime.now(),
        ),
      );
    }
  }

  /// Instant UI update when a print write fails (USB unplug mid-job, BLE drop).
  void markUnreachable(Object error) {
    _revision++;
    final config = _health.config;
    final paper = isPrinterPaperOut(error);
    _setHealth(
      PrinterHealth(
        state: paper
            ? PrinterHealthState.attention
            : PrinterHealthState.missing,
        config: config,
        message: error.toString(),
        issues: paper ? const ['paper_out'] : const ['offline', 'missing'],
        lastCheckedAt: DateTime.now(),
      ),
    );
  }

  void applyHealth(PrinterHealth health) {
    _revision++;
    _setHealth(health);
  }

  void _setHealth(PrinterHealth next) {
    if (_disposed) return;
    _health = next;
    _probing = false;
    _hasProbed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_usbHardware?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
