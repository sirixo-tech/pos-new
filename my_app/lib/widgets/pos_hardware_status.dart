import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../screens/printer_setup_screen.dart';
import '../services/printing/pos_receipt_printer.dart';
import '../services/printing/printer_health.dart';
import '../services/printing/printer_status_service.dart';
import '../theme/pos_theme.dart';

/// App-bar warning when the receipt printer needs attention. Hidden when ready.
class PosPrinterWarningButton extends StatelessWidget {
  const PosPrinterWarningButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!PosReceiptPrinter.isSupported) {
      return const SizedBox.shrink();
    }

    return Consumer<PrinterStatusService>(
      builder: (context, service, _) {
        if (!service.hasProbed || !service.health.hasIssue) {
          return const SizedBox.shrink();
        }

        final health = service.health;
        // "No printer selected" is setup, not a live fault — keep chrome quiet.
        if (health.state == PrinterHealthState.none ||
            health.state == PrinterHealthState.unsupported) {
          return const SizedBox.shrink();
        }

        final l10n = context.l10n;
        final severe = health.state == PrinterHealthState.missing ||
            health.state == PrinterHealthState.error;
        final tone = posStatusColors(severe ? 'failed' : 'pending');
        final bg = tone.bg;
        final fg = tone.fg;
        final title = _title(l10n, health);
        final body = _body(l10n, health);
        final printerName = health.config?.name.trim();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: MenuAnchor(
            alignmentOffset: const Offset(0, 6),
            style: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(PosTheme.surface),
              elevation: const WidgetStatePropertyAll(12),
              shadowColor: WidgetStatePropertyAll(
                Colors.black.withValues(alpha: 0.18),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: PosTheme.border.withValues(alpha: 0.95),
                  ),
                ),
              ),
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            ),
            builder: (context, controller, _) {
              return Tooltip(
                message: title,
                waitDuration: const Duration(milliseconds: 600),
                child: Material(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Icon(
                        severe
                            ? Icons.print_disabled_rounded
                            : Icons.warning_amber_rounded,
                        size: PosTheme.headerPx(20),
                        color: fg,
                      ),
                    ),
                  ),
                ),
              );
            },
            menuChildren: [
              Builder(
                builder: (menuContext) {
                  return _PrinterIssueMenu(
                    title: title,
                    body: body,
                    printerName:
                        printerName != null && printerName.isNotEmpty
                            ? printerName
                            : null,
                    accent: fg,
                    accentBg: bg,
                    severe: severe,
                    onOpenSetup: () {
                      MenuController.maybeOf(menuContext)?.close();
                      _openSetup(context);
                    },
                    onRecheck: () async {
                      await context
                          .read<PrinterStatusService>()
                          .refresh(allowBluetoothScan: true);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _title(AppLocalizations l10n, PrinterHealth health) {
    switch (health.state) {
      case PrinterHealthState.missing:
        return l10n.statusPrinterMissing;
      case PrinterHealthState.notPrintable:
        return l10n.statusPrinterNeedsSetup;
      case PrinterHealthState.attention:
        return health.statusLabel;
      case PrinterHealthState.error:
        return l10n.statusPrinterError;
      case PrinterHealthState.none:
        return l10n.statusPrinterNone;
      case PrinterHealthState.unsupported:
        return l10n.statusPrinterUnsupported;
      case PrinterHealthState.ready:
        return l10n.statusPrinterReady;
    }
  }

  String _body(AppLocalizations l10n, PrinterHealth health) {
    final custom = health.message?.trim();
    if (custom != null &&
        custom.isNotEmpty &&
        custom.toLowerCase() != 'ready' &&
        custom.toLowerCase() != health.statusLabel.toLowerCase()) {
      return custom;
    }

    switch (health.state) {
      case PrinterHealthState.missing:
        return l10n.statusPrinterMissingHelp;
      case PrinterHealthState.notPrintable:
        return l10n.statusPrinterNeedsSetupHelp;
      case PrinterHealthState.attention:
        return l10n.statusPrinterAttentionHelp;
      case PrinterHealthState.error:
        return l10n.statusPrinterErrorHelp;
      case PrinterHealthState.none:
        return l10n.statusPrinterNone;
      case PrinterHealthState.unsupported:
        return l10n.statusPrinterUnsupported;
      case PrinterHealthState.ready:
        return l10n.statusPrinterReady;
    }
  }

  Future<void> _openSetup(BuildContext context) async {
    await PrinterSetupScreen.open(context);
  }
}

class _PrinterIssueMenu extends StatelessWidget {
  const _PrinterIssueMenu({
    required this.title,
    required this.body,
    required this.printerName,
    required this.accent,
    required this.accentBg,
    required this.severe,
    required this.onOpenSetup,
    required this.onRecheck,
  });

  final String title;
  final String body;
  final String? printerName;
  final Color accent;
  final Color accentBg;
  final bool severe;
  final VoidCallback onOpenSetup;
  final Future<void> Function() onRecheck;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    severe
                        ? Icons.print_disabled_rounded
                        : Icons.warning_amber_rounded,
                    size: 20,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: PosTheme.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (printerName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          printerName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PosTheme.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: PosTheme.inkMuted,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    await onRecheck();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: PosTheme.inkMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.statusPrinterRecheck),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onOpenSetup,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(l10n.printerSetupTitle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
