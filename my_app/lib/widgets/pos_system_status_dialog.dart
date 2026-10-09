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
import '../utils/pos_layout.dart';

/// Header Status control: internet, printer, scanner, and customer QR display.
class PosSystemStatusButton extends StatefulWidget {
  const PosSystemStatusButton({super.key, this.showLabel = true});

  final bool showLabel;

  @override
  State<PosSystemStatusButton> createState() => _PosSystemStatusButtonState();
}

class _PosSystemStatusButtonState extends State<PosSystemStatusButton> {
  Timer? _displayPoll;
  WindowsCustomerDisplayStatus? _usbDisplay;

  @override
  void initState() {
    super.initState();
    unawaited(_probeDisplay());
    _displayPoll = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_probeDisplay());
    });
  }

  @override
  void dispose() {
    _displayPoll?.cancel();
    super.dispose();
  }

  Future<void> _probeDisplay() async {
    try {
      final status = await CustomerDisplayBroker.instance.hardwareStatus();
      if (!mounted) return;
      setState(() => _usbDisplay = status);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final printer = context.watch<PrinterStatusService>();
    final scanner = context.watch<ScannerConnectionService>();
    final lan = CustomerDisplayLanService.instance;

    return ListenableBuilder(
      listenable: lan,
      builder: (context, _) {
        final displayConnected = qrDisplayIsConnected(
          lanSessions: lan.devices.length,
          usb: _usbDisplay,
        );
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
                  horizontal: usePosHandheldLayout(context)
                      ? 13
                      : PosTheme.headerPx(widget.showLabel ? 12 : 10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: PosTheme.headerPx(18), color: tone.fg),
                    if (widget.showLabel) ...[
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

Future<void> showPosSystemStatusDialog(
  BuildContext context, {
  Future<WindowsCustomerDisplayStatus> Function()? displayProbe,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _PosSystemStatusDialog(displayProbe: displayProbe),
  );
}

class _PosSystemStatusDialog extends StatefulWidget {
  const _PosSystemStatusDialog({this.displayProbe});
  final Future<WindowsCustomerDisplayStatus> Function()? displayProbe;

  @override
  State<_PosSystemStatusDialog> createState() => _PosSystemStatusDialogState();
}

class _PosSystemStatusDialogState extends State<_PosSystemStatusDialog> {
  Timer? _poll;
  bool _refreshing = false;
  bool _refreshActive = false;
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
    if (_refreshActive || !mounted) return;
    _refreshActive = true;
    if (!silent) setState(() => _refreshing = true);
    try {
      await Future.wait([
        context.read<ConnectivityService>().checkConnectivity(),
        if (!silent && PosReceiptPrinter.isSupported)
          context.read<PrinterStatusService>().refresh(
            allowBluetoothScan: true,
          ),
        context.read<ScannerConnectionService>().refresh().timeout(
          const Duration(seconds: 3),
        ),
      ]);
      final display =
          await (widget.displayProbe ??
                  CustomerDisplayBroker.instance.hardwareStatus)()
              .timeout(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() => _display = display);
    } catch (error) {
      debugPrint('System status refresh failed: $error');
    } finally {
      _refreshActive = false;
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

    return ListenableBuilder(
      listenable: lan,
      builder: (context, _) {
        final displayConnected = qrDisplayIsConnected(
          lanSessions: lan.devices.length,
          usb: _display,
        );
        final displayDetail = _qrDisplayDetail(
          lanSessions: lan.devices.length,
          usb: _display,
        );
        final summary = _statusSummary(
          connectivity: connectivity,
          printer: printer.health,
          printerSupported: PosReceiptPrinter.isSupported,
          printerChecking: printer.probing && !printer.hasProbed,
          displayConnected: displayConnected,
          scannerConnected: scanner.connected,
        );
        return _StatusDialogShell(
          title: 'System Status',
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
          maxWidth: 400,
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
                connected:
                    PosReceiptPrinter.isSupported &&
                    printer.health.state == PrinterHealthState.ready,
                detail: printer.probing && !printer.hasProbed
                    ? 'Checking…'
                    : _printerDetail(printer.health),
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
          footer: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _refreshing ? null : () => unawaited(_refresh()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF26500),
                    side: const BorderSide(color: Color(0xFFF26500)),
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: Text(
                    _refreshing ? 'Refreshing…' : 'Refresh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6500),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(l10n.commonClose, maxLines: 1),
                ),
              ),
            ],
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

class _StatusDialogShell extends StatelessWidget {
  const _StatusDialogShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.headerColor,
    required this.maxWidth,
    required this.onClose,
    required this.body,
    required this.footer,
  });
  final String title, subtitle;
  final IconData icon;
  final Color headerColor;
  final double maxWidth;
  final VoidCallback onClose;
  final Widget body, footer;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    backgroundColor: PosTheme.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF9C00), Color(0xFFFF5100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: const Color(0xFFFF6500), size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: body,
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: footer),
        ],
      ),
    ),
  );
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
        color: connected ? const Color(0xFFF0F9F4) : const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: soft.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: soft.fg),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: PosTheme.ink,
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              connected
                                  ? (label == 'Printer' ? 'Ready' : 'Connected')
                                  : 'Not Connected',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 11,
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

bool qrDisplayIsConnected({
  required int lanSessions,
  required WindowsCustomerDisplayStatus? usb,
}) {
  if (lanSessions > 0) return true;
  final device = usb?.device;
  if (usb?.connected != true || device == null || device.isEmpty) {
    return false;
  }
  return device == 'dq11' || device == 'dqr222' || device == 'dq11+dqr222';
}

String _qrDisplayDetail({
  required int lanSessions,
  required WindowsCustomerDisplayStatus? usb,
}) {
  if (lanSessions > 0) {
    return lanSessions == 1
        ? 'LAN customer display connected.'
        : 'LAN customer displays connected ($lanSessions).';
  }
  if (qrDisplayIsConnected(lanSessions: 0, usb: usb)) {
    return usb?.message ?? 'QR display connected.';
  }
  return 'QR display is not connected.';
}

({bool ready, bool severe}) _statusSummary({
  required ConnectivityService connectivity,
  required PrinterHealth printer,
  required bool printerSupported,
  required bool displayConnected,
  required bool scannerConnected,
  bool printerChecking = false,
}) {
  final internetOk = connectivity.isOnline;
  final printerSevere =
      printerSupported &&
      !printerChecking &&
      (printer.state == PrinterHealthState.missing ||
          printer.state == PrinterHealthState.error);
  final printerOk =
      !printerSupported ||
      (!printerChecking && printer.state == PrinterHealthState.ready);
  return (
    ready: internetOk && printerOk && displayConnected && scannerConnected,
    severe: !internetOk || printerSevere,
  );
}
