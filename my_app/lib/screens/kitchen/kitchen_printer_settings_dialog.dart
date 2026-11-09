import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../providers/pos_controller.dart';
import '../../services/printing/scan_to_print_settings.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_ui.dart';
import '../printer_setup_screen.dart';

/// Settings dialog for KDS screens to control paperless mode and KOT printing.
Future<void> showKitchenPrinterSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _KitchenPrinterSettingsDialog(),
  );
}

class _KitchenPrinterSettingsDialog extends StatefulWidget {
  const _KitchenPrinterSettingsDialog();

  @override
  State<_KitchenPrinterSettingsDialog> createState() =>
      _KitchenPrinterSettingsDialogState();
}

class _KitchenPrinterSettingsDialogState
    extends State<_KitchenPrinterSettingsDialog> {
  bool _loading = true;
  bool _printingEnabled = true;
  bool _autoKot = true;
  bool _showFailurePopup = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final printing = await PosPrintingSettings.enabled();
    final autoKot = await AutoPrintKotSettings.enabled();
    final popup = await KotFailurePopupSettings.enabled();
    if (!mounted) return;
    setState(() {
      _printingEnabled = printing;
      _autoKot = autoKot;
      _showFailurePopup = popup;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final pos = context.watch<PosController>();
    final canManagePrinters = pos.canOpenStaffAction('printer');

    return PosDialogShell(
      title: context.posText('kitchenPrinterSettings', 'Kitchen ticket printing'),
      subtitle: context.posText(
        'kitchenPrinterSettingsSubtitle',
        'Paperless mode and KOT print preferences for this screen.',
      ),
      icon: Icons.print_outlined,
      maxWidth: 480,
      onClose: () => Navigator.pop(context),
      body: _loading
          ? const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_printingEnabled) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.eco_rounded,
                            color: Color(0xFF059669),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.posText(
                                'kitchenPaperlessBanner',
                                'Paperless Mode Active: Tickets appear on this board without attempting physical printing or showing printer error popups.',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF065F46),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _switchCard(
                    soft: soft,
                    icon: _printingEnabled
                        ? Icons.print_rounded
                        : Icons.eco_rounded,
                    title: context.posText(
                      'kitchenPrintingEnabled',
                      'Printing on this screen',
                    ),
                    badge: _printingEnabled
                        ? _statusPill(
                            'ACTIVE',
                            const Color(0xFF0284C7),
                            const Color(0xFFE0F2FE),
                          )
                        : _statusPill(
                            'PAPERLESS',
                            const Color(0xFF059669),
                            const Color(0xFFD1FAE5),
                          ),
                    subtitle: _printingEnabled
                        ? context.posText(
                            'kitchenPrintingEnabledHelp',
                            'Physical printing is active. Kitchen tickets can print automatically.',
                          )
                        : context.posText(
                            'kitchenPaperlessHelp',
                            'Paperless Mode active. Orders appear on the KDS board without attempting printing or showing printer errors.',
                          ),
                    value: _printingEnabled,
                    onChanged: (value) async {
                      setState(() => _printingEnabled = value);
                      await PosPrintingSettings.setEnabled(value);
                      if (!mounted) return;
                      showPosSnackBar(
                        this.context,
                        value
                            ? 'Printing enabled on this screen'
                            : 'Paperless Mode enabled (no physical printing)',
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _switchCard(
                    soft: soft,
                    icon: Icons.receipt_long_rounded,
                    enabled: _printingEnabled,
                    title: context.posText(
                      'kitchenAutoKot',
                      'Auto-print KOT on new orders',
                    ),
                    subtitle: context.posText(
                      'kitchenAutoKotHelp',
                      'Automatically send ticket to printer when a new order arrives.',
                    ),
                    value: _autoKot,
                    onChanged: (value) async {
                      setState(() => _autoKot = value);
                      await AutoPrintKotSettings.setEnabled(value);
                      if (!mounted) return;
                      showPosSnackBar(
                        this.context,
                        value
                            ? 'Auto-print KOT turned on'
                            : 'Auto-print KOT turned off',
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _switchCard(
                    soft: soft,
                    icon: Icons.notifications_active_outlined,
                    enabled: _printingEnabled,
                    title: context.posText(
                      'kitchenFailurePopup',
                      'Show KOT print failed popup',
                    ),
                    subtitle: context.posText(
                      'kitchenFailurePopupHelp',
                      'Show an on-screen popup when a printer is missing or fails. When off, tickets stay queued silently.',
                    ),
                    value: _showFailurePopup,
                    onChanged: (value) async {
                      setState(() => _showFailurePopup = value);
                      await KotFailurePopupSettings.setEnabled(value);
                      if (!mounted) return;
                      showPosSnackBar(
                        this.context,
                        value
                            ? 'Print failure popup turned on'
                            : 'Print failure popup turned off',
                      );
                    },
                  ),
                  if (canManagePrinters) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text(context.l10n.printerSetupTitle),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrinterSetupScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
      footer: posDialogActionFooter(
        context: context,
        onCancel: () => Navigator.pop(context),
        onConfirm: () => Navigator.pop(context),
        cancelLabel: l10n.commonClose,
        confirmLabel: l10n.commonDone,
      ),
    );
  }

  Widget _switchCard({
    required ({Color bg, Color fg}) soft,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? badge,
    bool enabled = true,
  }) {
    final active = enabled && value;
    return Material(
      color: active ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.25)
                    : PosTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? Colors.white.withValues(alpha: 0.35)
                      : PosTheme.border,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: active
                    ? soft.fg
                    : (enabled ? PosTheme.inkMuted : PosTheme.inkFaint),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: active
                                ? soft.fg
                                : (enabled ? PosTheme.ink : PosTheme.inkFaint),
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        badge,
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: enabled ? PosTheme.inkMuted : PosTheme.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
