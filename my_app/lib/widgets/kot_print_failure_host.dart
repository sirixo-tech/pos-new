import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/printing/print_job_coordinator.dart';
import '../services/printing/printer_status_service.dart';
import '../theme/pos_theme.dart';
import 'pos_navigator.dart';

/// App-level KOT failure UI. Uses the root navigator so route changes cannot
/// drop the event, and drains a FIFO so overlapping jobs are not lost.
class KotPrintFailureHost extends StatefulWidget {
  const KotPrintFailureHost({super.key});

  @override
  State<KotPrintFailureHost> createState() => _KotPrintFailureHostState();
}

class _KotPrintFailureHostState extends State<KotPrintFailureHost> {
  StreamSubscription<PrintJobFailure>? _sub;
  PrintJobCoordinator? _coordinator;
  bool _modalOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = context.read<PrintJobCoordinator>();
    if (identical(_coordinator, coordinator) && _sub != null) return;
    unawaited(_sub?.cancel());
    _coordinator = coordinator;
    _sub = coordinator.onFailure.listen((_) => _pump());
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _pump() {
    if (!mounted || _modalOpen) return;
    final coordinator = _coordinator;
    if (coordinator == null) return;
    final pending = coordinator.pendingKotFailures;
    if (pending.isEmpty) return;
    _show(pending.first, coordinator);
  }

  void _show(PrintJobFailure event, PrintJobCoordinator coordinator) {
    final nav = posRootNavigatorKey.currentState;
    final overlayContext = nav?.overlay?.context ?? posRootNavigatorContext;
    if (overlayContext == null || !overlayContext.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pump();
      });
      return;
    }

    _modalOpen = true;
    showDialog<void>(
      context: overlayContext,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => _PrintFailureDialog(
        event: event,
        onRetry: () async {
          await coordinator.retryFailed(includeMayHavePrinted: false);
        },
        onPrinterReady: () {
          coordinator.onHealthChanged(
            overlayContext.read<PrinterStatusService>().health,
          );
          unawaited(coordinator.retryFailed(includeMayHavePrinted: false));
        },
      ),
    ).whenComplete(() {
      coordinator.ackFailure(event.jobKey);
      _modalOpen = false;
      if (mounted) _pump();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _PrintFailureDialog extends StatefulWidget {
  const _PrintFailureDialog({
    required this.event,
    required this.onRetry,
    required this.onPrinterReady,
  });

  final PrintJobFailure event;
  final Future<void> Function() onRetry;
  final VoidCallback onPrinterReady;

  @override
  State<_PrintFailureDialog> createState() => _PrintFailureDialogState();
}

class _PrintFailureDialogState extends State<_PrintFailureDialog> {
  bool _resumed = false;
  bool _busy = false;
  late final PrinterStatusService _printerStatus;

  @override
  void initState() {
    super.initState();
    _printerStatus = context.read<PrinterStatusService>();
    _printerStatus.addListener(_watchHealth);
    unawaited(_printerStatus.refresh());
  }

  @override
  void dispose() {
    _printerStatus.removeListener(_watchHealth);
    super.dispose();
  }

  void _watchHealth() {
    if (!mounted || _resumed) return;
    final health = _printerStatus.health;
    final paperOut = health.issues.contains('paper_out');
    final down =
        health.hasIssue &&
        (paperOut ||
            health.issues.contains('offline') ||
            health.issues.contains('missing') ||
            health.state.name == 'missing' ||
            health.state.name == 'error' ||
            health.state.name == 'none');
    if (!down) {
      setState(() => _resumed = true);
      widget.onPrinterReady();
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = widget.event.isPaperOut;
    final missing = widget.event.isMissingPrinter;
    final title = _resumed
        ? 'Printing resumed'
        : (paper
              ? 'Printer paper roll over'
              : (missing ? 'No printer selected' : 'KOT printing failed'));
    final body = _resumed
        ? 'KOT for ${widget.event.orderNumber} is printing again.'
        : paper
        ? 'The printer paper roll is finished or not detected.\n\nReplace the roll. Printing continues automatically.'
        : missing
        ? 'Select a receipt printer in Printer setup.\n\nOrder ${widget.event.orderNumber} is saved. KOT prints automatically once a printer is ready.'
        : 'The printer is disconnected or not responding.\n\nOrder ${widget.event.orderNumber} is saved. Reconnect the printer — KOT prints automatically.';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _resumed
                    ? Icons.check_circle_rounded
                    : (paper
                          ? Icons.print_disabled_rounded
                          : Icons.print_disabled_outlined),
                size: 44,
                color: _resumed
                    ? const Color(0xFF059669)
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: PosTheme.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: PosTheme.inkMuted,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Dismiss'),
                    ),
                  ),
                  if (!_resumed)
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  await widget.onRetry();
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        child: Text(_busy ? 'Retrying…' : 'Retry now'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
