import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../screens/printer_setup_screen.dart';
import '../services/customer_display/customer_display_broker.dart';
import '../services/customer_display/lan/customer_display_lan_service.dart';
import '../services/customer_display/smartpos_customer_display_service.dart';
import '../services/offline/connectivity_service.dart';
import '../services/printing/pos_receipt_printer.dart';
import '../services/printing/printer_health.dart';
import '../services/printing/printer_status_service.dart';
import '../services/scanner_connection_service.dart';
import '../theme/pos_theme.dart';
import 'pos_ui.dart';

/// Header Status control: internet, printer, scanner, and customer QR display.
class PosSystemStatusButton extends StatelessWidget {
  const PosSystemStatusButton({
    super.key,
    this.showLabel = true,
  });

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final printer = context.watch<PrinterStatusService>();
    final scanner = context.watch<ScannerConnectionService>();
    final lan = CustomerDisplayLanService.instance;

    return ListenableBuilder(
      listenable: lan,
      builder: (context, _) {
        final displayConnected = lan.connections.isNotEmpty;
        final summary = _statusSummary(
          connectivity: connectivity,
          printer: printer.health,
          printerSupported: PosReceiptPrinter.isSupported,
          displayConnected: displayConnected,
          scannerConnected: scanner.connected,
        );
        final tone = summary.ready
            ? posStatusColors('ready')
            : summary.severe
                ? posStatusColors('failed')
                : posStatusColors('pending');
        final icon = summary.ready
            ? Icons.check_circle_rounded
            : summary.severe
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded;

        return Tooltip(
          message: summary.ready
              ? 'Status: Systems ready'
              : 'Status: Needs attention',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => unawaited(showPosSystemStatusDialog(context)),
              hoverColor: PosTheme.surfaceMuted,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: PosTheme.headerPx(showLabel ? 12 : 10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: PosTheme.headerPx(18), color: tone.fg),
                    if (showLabel) ...[
                      SizedBox(width: PosTheme.headerPx(6)),
                      Text(
                        'Status',
                        style: TextStyle(
                          fontSize: PosTheme.headerPx(12.5),
                          fontWeight: FontWeight.w700,
                          color: PosTheme.ink.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showPosSystemStatusDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _PosSystemStatusDialog(),
  );
}

class _PosSystemStatusDialog extends StatefulWidget {
  const _PosSystemStatusDialog();

  @override
  State<_PosSystemStatusDialog> createState() => _PosSystemStatusDialogState();
}

class _PosSystemStatusDialogState extends State<_PosSystemStatusDialog> {
  Timer? _poll;
  bool _refreshing = false;
  WindowsCustomerDisplayStatus? _display;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refresh(silent: true));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() => _refreshing = true);
    try {
      await Future.wait([
        context.read<ConnectivityService>().checkConnectivity(),
        if (PosReceiptPrinter.isSupported)
          context.read<PrinterStatusService>().refresh(),
        context.read<ScannerConnectionService>().refresh(),
      ]);
      final display = await CustomerDisplayBroker.instance.hardwareStatus();
      if (!mounted) return;
      setState(() => _display = display);
    } finally {
      if (mounted && !silent) setState(() => _refreshing = false);
    }
  }

  Future<void> _openPrinter() async {
    Navigator.pop(context);
    if (!mounted) return;
    await PrinterSetupScreen.open(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connectivity = context.watch<ConnectivityService>();
    final printer = context.watch<PrinterStatusService>();
    final scanner = context.watch<ScannerConnectionService>();
    final lan = CustomerDisplayLanService.instance;
    final lanConnected = lan.connections.isNotEmpty;
    final usbConnected = _display?.connected == true;
    final displayConnected = usbConnected || lanConnected;
    final displayDetail = usbConnected
        ? (_display?.message ?? 'QR display connected.')
        : lanConnected
            ? 'LAN customer display paired (${lan.connections.length}).'
            : 'QR display is not connected.';

    final summary = _statusSummary(
      connectivity: connectivity,
      printer: printer.health,
      printerSupported: PosReceiptPrinter.isSupported,
      displayConnected: displayConnected,
      scannerConnected: scanner.connected,
    );

    return ListenableBuilder(
      listenable: lan,
      builder: (context, _) {
        return PosDialogShell(
          title: 'System status',
          subtitle: summary.ready
              ? 'Internet, printer, and this register are ready.'
              : 'One or more devices need attention.',
          icon: summary.ready
              ? Icons.check_circle_outline_rounded
              : Icons.warning_amber_rounded,
          headerColor: summary.ready
              ? const Color(0xFF16A34A)
              : summary.severe
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFFD97706),
          maxWidth: 440,
          onClose: () => Navigator.pop(context),
          body: Column(
            children: [
              _StatusRow(
                icon: Icons.wifi_rounded,
                label: 'Internet',
                connected: connectivity.isOnline,
                detail: connectivity.isOnline
                    ? 'Online'
                    : connectivity.status == ConnectionStatus.checking
                        ? 'Checking…'
                        : 'Offline',
              ),
              _StatusRow(
                icon: Icons.print_outlined,
                label: 'Printer',
                connected: PosReceiptPrinter.isSupported &&
                    printer.health.state == PrinterHealthState.ready,
                detail: _printerDetail(printer.health),
                onTap: _openPrinter,
              ),
              _StatusRow(
                icon: Icons.qr_code_2_rounded,
                label: 'QR display',
                connected: displayConnected,
                detail: displayDetail,
              ),
              _StatusRow(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scanner',
                connected: scanner.connected,
                detail: scanner.detail,
              ),
            ],
          ),
          footer: posDialogActionFooter(
            context: context,
            onCancel: _refreshing ? () {} : () => unawaited(_refresh()),
            onConfirm: () => Navigator.pop(context),
            cancelLabel: _refreshing ? 'Refreshing…' : 'Refresh',
            confirmLabel: l10n.commonClose,
          ),
        );
      },
    );
  }

  String _printerDetail(PrinterHealth health) {
    if (!PosReceiptPrinter.isSupported) {
      return 'Printing is not available on this device.';
    }
    switch (health.state) {
      case PrinterHealthState.ready:
        return health.config?.name.trim().isNotEmpty == true
            ? 'Ready · ${health.config!.name}'
            : 'Ready';
      case PrinterHealthState.none:
        return 'Not configured';
      case PrinterHealthState.unsupported:
        return 'Not supported';
      default:
        return health.message?.trim().isNotEmpty == true
            ? health.message!.trim()
            : health.statusLabel;
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.connected,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool connected;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = connected
        ? const Color(0xFF16A34A)
        : const Color(0xFFD97706);
    final soft = posAccentSoft(accent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: soft.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: soft.fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: PosTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  connected
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: accent,
                  size: 20,
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: PosTheme.inkFaint),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

({bool ready, bool severe}) _statusSummary({
  required ConnectivityService connectivity,
  required PrinterHealth printer,
  required bool printerSupported,
  required bool displayConnected,
  required bool scannerConnected,
}) {
  final internetOk = connectivity.isOnline;
  final printerSevere = printerSupported &&
      (printer.state == PrinterHealthState.missing ||
          printer.state == PrinterHealthState.error);
  final printerOk = !printerSupported ||
      printer.state == PrinterHealthState.ready;
  return (
    ready: internetOk && printerOk && displayConnected && scannerConnected,
    severe: !internetOk || printerSevere,
  );
}
