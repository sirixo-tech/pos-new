import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/pos_l10n.dart';
import '../utils/order_barcode_scan.dart';
import 'pos_ui.dart';

/// Manual scan-to-print: enter or wedge an order number, then print.
Future<String?> showPosScanToPrintDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? const _CameraScanToPrintDialog()
        : const _ScanToPrintDialog(),
  );
}

class _CameraScanToPrintDialog extends StatefulWidget {
  const _CameraScanToPrintDialog();

  @override
  State<_CameraScanToPrintDialog> createState() =>
      _CameraScanToPrintDialogState();
}

class _CameraScanToPrintDialogState extends State<_CameraScanToPrintDialog> {
  final _camera = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [],
  );
  bool _completed = false;
  String? _hint;

  void _detected(BarcodeCapture capture) {
    if (_completed || !mounted) return;
    for (final barcode in capture.barcodes) {
      final raw = (barcode.rawValue ?? '').trim();
      if (context.read<PosController>().matchBarcode(raw) != null) {
        _completed = true;
        Navigator.of(context).pop(raw);
        return;
      }
      if (!OrderBarcodeScan.isOrderReference(raw)) continue;
      final number = OrderBarcodeScan.parseOrderNumber(raw);
      if (number == null) continue;
      _completed = true;
      Navigator.of(context).pop(number);
      return;
    }
    setState(
      () => _hint =
          'No matching item found. Show an item SKU barcode or an order QR.',
    );
  }

  Future<void> _manual() async {
    await _camera.stop();
    if (!mounted) return;
    final reference = await showDialog<String>(
      context: context,
      builder: (_) => const _ScanToPrintDialog(),
    );
    if (!mounted) return;
    if (reference != null) {
      _completed = true;
      Navigator.of(context).pop(reference);
    } else {
      await _camera.start();
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PosDialogShell(
    title: 'Scan barcode',
    subtitle:
        'Scan an item barcode to add it to the cart, or an order QR to print.',
    icon: Icons.qr_code_scanner_rounded,
    headerColor: Theme.of(context).colorScheme.primary,
    maxWidth: 480,
    onClose: () => Navigator.of(context).pop(),
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.4).clamp(160.0, 320.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: _camera,
              onDetect: _detected,
              errorBuilder: (_, error) => const Center(
                child: Text(
                  'Camera unavailable. Allow camera permission, or enter the order number below.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        if (_hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_hint!, textAlign: TextAlign.center),
          ),
      ],
    ),
    footer: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton.icon(
          onPressed: () => _camera.switchCamera(),
          icon: const Icon(Icons.flip_camera_android),
          label: const Text('Switch camera'),
        ),
        TextButton.icon(
          onPressed: _manual,
          icon: const Icon(Icons.keyboard),
          label: const Text('Enter order number'),
        ),
      ],
    ),
  );
}

class _ScanToPrintDialog extends StatefulWidget {
  const _ScanToPrintDialog();

  @override
  State<_ScanToPrintDialog> createState() => _ScanToPrintDialogState();
}

class _ScanToPrintDialogState extends State<_ScanToPrintDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'ORD-');
    _focus = FocusNode();
    _controller.selection = const TextSelection.collapsed(offset: 4);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty || value == 'ORD-') return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;

    return PosDialogShell(
      title: 'Scan to print',
      subtitle: 'Scan a barcode or enter the order number, then print.',
      icon: Icons.qr_code_scanner_rounded,
      headerColor: accent,
      maxWidth: 440,
      onClose: () => Navigator.pop(context),
      body: TextField(
        controller: _controller,
        focusNode: _focus,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Order number',
          hintText: 'ORD-20260730110050',
          prefixIcon: const Icon(Icons.receipt_long_outlined),
          helperText: 'USB scanners type into this field automatically.',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      footer: posDialogActionFooter(
        context: context,
        onCancel: () => Navigator.pop(context),
        onConfirm: _submit,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.commonPrint,
      ),
    );
  }
}
