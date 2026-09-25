import 'dart:async';

import 'package:flutter/widgets.dart';

import 'pos_receipt_printer.dart';
import 'print_skipped.dart';
import 'printer_health.dart';

/// App-bar printer health: USB / LAN / built-in are probed every few seconds.
/// Bluetooth uses a cheap isConnected check on the timer (no scan / no connect).
class PrinterStatusService extends ChangeNotifier with WidgetsBindingObserver {
  PrinterStatusService() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _pollInterval = Duration(seconds: 5);

  PrinterHealth _health = const PrinterHealth(
    state: PrinterHealthState.none,
  );
  bool _probing = false;
  bool _started = false;
  bool _hasProbed = false;
  Timer? _timer;
  StreamSubscription<dynamic>? _usbHardware;
  int _ticks = 0;
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
    _usbHardware ??= PosReceiptPrinter.watchUsbHardware(() {
      unawaited(refresh());
    });
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) {
      _ticks++;
      unawaited(
        refresh(allowBluetoothScan: _ticks % 6 == 0),
      );
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
      if (!_queued) return;
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

    final config = await UsbPrinterStorage.load();
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
    try {
      final next = await PosReceiptPrinter.probe(
        allowBluetoothScan: allowBluetoothScan,
      );
      _setHealth(next);
    } catch (e, st) {
      debugPrint('PrinterStatusService.refresh failed: $e\n$st');
      _setHealth(
        PrinterHealth(
          state: PrinterHealthState.error,
          config: config,
          message: e.toString(),
          issues: PrinterHealth.issuesFromErrorMessage(e.toString()),
          lastCheckedAt: DateTime.now(),
        ),
      );
    }
  }

  /// Instant UI update when a print write fails (USB unplug mid-job, BLE drop).
  void markUnreachable(Object error) {
    final config = _health.config;
    final paper = isPrinterPaperOut(error);
    _setHealth(
      PrinterHealth(
        state: paper ? PrinterHealthState.attention : PrinterHealthState.missing,
        config: config,
        message: error.toString(),
        issues: paper
            ? const ['paper_out']
            : const ['offline', 'missing'],
        lastCheckedAt: DateTime.now(),
      ),
    );
  }

  void applyHealth(PrinterHealth health) {
    _setHealth(health);
  }

  void _setHealth(PrinterHealth next) {
    _health = next;
    _probing = false;
    _hasProbed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_usbHardware?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
