import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/scanner_connection_service.dart';
import '../utils/order_barcode_scan.dart';

/// Listens for USB / iMin barcode scanner input and forwards the payload.
class PosOrderBarcodeListener extends StatefulWidget {
  const PosOrderBarcodeListener({
    super.key,
    required this.onScan,
    required this.child,
  });

  final ValueChanged<String> onScan;
  final Widget child;

  @override
  State<PosOrderBarcodeListener> createState() =>
      _PosOrderBarcodeListenerState();
}

class _PosOrderBarcodeListenerState extends State<PosOrderBarcodeListener> {
  late final OrderBarcodeScan _scanner;
  final _delivery = ScannerDeliveryFilter();
  StreamSubscription<String>? _imin;

  @override
  void initState() {
    super.initState();
    _scanner = OrderBarcodeScan(onScan: (payload) => _emit(payload));
    HardwareKeyboard.instance.addHandler(_handleKey);
    _imin = iminScannerPayloads().listen((payload) {
      _emit(payload, broadcast: true);
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _imin?.cancel();
    _scanner.dispose();
    super.dispose();
  }

  void _emit(String payload, {bool broadcast = false}) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return;
    if (!_delivery.accept(trimmed, broadcast: broadcast)) return;
    if (mounted) {
      context.read<ScannerConnectionService>().markInput();
    }
    widget.onScan(trimmed);
  }

  bool _handleKey(KeyEvent event) => _scanner.handleKeyEvent(event);

  @override
  Widget build(BuildContext context) => widget.child;
}
