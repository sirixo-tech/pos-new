import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/order_barcode_scan.dart';

/// Foreground order scanning; never treats a payment QR as an order.
class PosAutomaticOrderCamera extends StatefulWidget {
  const PosAutomaticOrderCamera({super.key, required this.onOrder});
  final Future<void> Function(String orderNumber) onOrder;

  @override
  State<PosAutomaticOrderCamera> createState() => _PosAutomaticOrderCameraState();
}

class _PosAutomaticOrderCameraState extends State<PosAutomaticOrderCamera>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39],
  );
  Timer? _timer;
  bool _foreground = true;
  bool _switching = false;
  bool _busy = false;
  bool _unavailable = false;
  final _seen = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCamera());
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _syncCamera());
  }

  Future<void> _syncCamera() async {
    if (!mounted || _switching) return;
    final shouldRun = _foreground && !_busy && !_unavailable && ModalRoute.of(context)?.isCurrent == true;
    _switching = true;
    try {
      if (shouldRun && !_camera.value.isRunning) {
        await _camera.start();
      } else if (!shouldRun && _camera.value.isRunning) {
        await _camera.stop();
      }
    } catch (_) {
      _unavailable = true;
      // Permission/camera failures are shown in the preview; manual Scan remains available.
    } finally {
      _switching = false;
    }
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (!mounted || _busy || !_foreground || ModalRoute.of(context)?.isCurrent != true) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue ?? '';
      if (!OrderBarcodeScan.isOrderReference(raw)) continue;
      final number = OrderBarcodeScan.parseOrderNumber(raw);
      if (number == null || !_seen.add(number)) continue;
      _busy = true;
      try {
        await _camera.stop();
        if (mounted) await widget.onOrder(number);
      } finally {
        _busy = false;
        await _syncCamera();
      }
      return;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_syncCamera());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    height: 96,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: MobileScanner(
        controller: _camera,
        onDetect: _detect,
        errorBuilder: (_, __) => const ColoredBox(
          color: Colors.black87,
          child: Center(child: Icon(Icons.no_photography_outlined, color: Colors.white)),
        ),
      ),
    ),
  );
}
