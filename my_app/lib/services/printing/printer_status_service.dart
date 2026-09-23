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
  int _probeToken = 0;
  int _ticks = 0;

  PrinterHealth get health => _health;
  bool get probing => _probing;
  bool get hasProbed => _hasProbed;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh(allowBluetoothScan: true);
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

  /// Soft probe. Bluetooth discovery only when [allowBluetoothScan] is true
  /// (start, resume, return from setup) — BLE scan is slow and steals the radio.
  Future<void> refresh({bool allowBluetoothScan = false}) async {
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

    final token = ++_probeToken;
    _probing = true;
    notifyListeners();
    try {
      final next = await PosReceiptPrinter.probe(
        allowBluetoothScan: allowBluetoothScan,
      );
      if (token != _probeToken) return;
      if (!allowBluetoothScan &&
          config.connection == PosPrinterConnection.bluetooth &&
          next.state == PrinterHealthState.missing &&
          _health.state == PrinterHealthState.ready &&
          !PosReceiptPrinter.bleLinkIsLive) {
        return;
      }
      _setHealth(next);
    } catch (e, st) {
      debugPrint('PrinterStatusService.refresh failed: $e\n$st');
      if (token != _probeToken) return;
      _setHealth(
        PrinterHealth(
          state: PrinterHealthState.error,
          config: config,
          message: e.toString(),
          issues: PrinterHealth.issuesFromErrorMessage(e.toString()),
          lastCheckedAt: DateTime.now(),
        ),
      );
    } finally {
      if (token == _probeToken) {
        _probing = false;
        notifyListeners();
      }
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
