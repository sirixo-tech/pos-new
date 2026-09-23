import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import 'pos_ui.dart';

/// Manual scan-to-print: enter or wedge an order number, then print.
Future<String?> showPosScanToPrintDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _ScanToPrintDialog(),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
