import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../models/pos_models.dart';
import '../../utils/thermal_printer_platform.dart';
import '../order_fulfillment_policy.dart';
import 'pending_print_jobs.dart';
import 'pos_receipt_printer.dart';
import 'pos_channel_print_policy.dart';
import 'print_skipped.dart';
import 'printer_health.dart';
import 'printer_status_service.dart';
import 'scan_to_print_settings.dart';

enum PrintJobKind { kot, receipt }

/// True when bytes may already have reached the printer.
/// A connect failure before the write can still retry. Paper-out on the
/// built-in printer is reported before printEpson, so those jobs can too.
bool _printMayHaveStarted(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('smartpos print failed') ||
      text.contains('smartpos_print_failed') ||
      text.contains('printer write failed');
}

class PrintJobFailure {
  const PrintJobFailure({
    required this.kind,
    required this.orderNumber,
    required this.orderId,
    required this.isPaperOut,
    required this.isDisconnected,
    required this.error,
    required this.jobKey,
    this.source = '',
    this.cashier = false,
  });

  final PrintJobKind kind;
  final String orderNumber;
  final int orderId;
  final bool isPaperOut;
  final bool isDisconnected;
  final Object error;
  final String jobKey;
  final String source;
  final bool cashier;

  bool get kotNotReady => isKotNotReady(error);
  bool get isMissingPrinter => isPrinterMissing(error);
}

class _PrintJob {
  _PrintJob({
    required this.kind,
    required this.orderId,
    required this.orderNumber,
    this.source = '',
    this.cashier = false,
    DateTime? queuedAt,
  }) : queuedAt = queuedAt ?? DateTime.now();

  final PrintJobKind kind;
  final int orderId;
  final String orderNumber;
  final String source;
  final bool cashier;
  final DateTime queuedAt;
  bool forceAttempt = false;

  /// The write may already have fed the slip. Automatic recovery must not
  /// send that job again. A connect failure before the write stays false.
  bool mayHavePrinted = false;

  String get jobKey {
    final ref = orderNumber.trim().isNotEmpty
        ? 'number:${orderNumber.trim().toLowerCase()}'
        : 'order:$orderId';
    return '${kind.name}:$ref';
  }
}

/// Process-wide KOT + receipt print queue. Order APIs never wait on this.
class PrintJobCoordinator extends ChangeNotifier {
  PrintJobCoordinator();

  PosSession? Function()? _session;
  String? Function()? _serverUrl;
  PrinterStatusService? _printerStatus;

  final Queue<_PrintJob> _queue = Queue();
  final Set<String> _queued = {};
  final Set<String> _completed = {};
  final Map<String, _PrintJob> _failed = {};
  final List<PrintJobFailure> _pendingKotUi = [];
  final StreamController<PrintJobFailure> _failures =
      StreamController<PrintJobFailure>.broadcast();

  bool _draining = false;
  Future<void>? _retryFlight;
  bool _restored = false;
  Timer? _healthWatch;
  PrinterHealthState? _lastHealthState;
  List<String> _lastIssues = const [];

  Stream<PrintJobFailure> get onFailure => _failures.stream;

  List<PrintJobFailure> get pendingKotFailures =>
      List<PrintJobFailure>.unmodifiable(_pendingKotUi);

  bool get hasFailedJobs => _failed.isNotEmpty;

  void ackFailure(String jobKey) {
    _pendingKotUi.removeWhere((event) => event.jobKey == jobKey);
  }

  void attach({
    required PosSession? Function() session,
    required String? Function() serverUrl,
    PrinterStatusService? printerStatus,
  }) {
    _session = session;
    _serverUrl = serverUrl;
    _printerStatus = printerStatus;
    unawaited(_restore());
  }

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    final open = await PendingPrintJobStore.loadOpen();
    for (final row in open) {
      if (_completed.contains(row.jobKey) || _queued.contains(row.jobKey)) {
        continue;
      }
      final job = _PrintJob(
        kind: row.kind == 'receipt' ? PrintJobKind.receipt : PrintJobKind.kot,
        orderId: row.orderId,
        orderNumber: row.orderNumber,
        source: row.source,
        cashier: row.cashier,
        queuedAt: row.createdAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.createdAtMs!),
      );
      job.mayHavePrinted = _printMayHaveStarted(
        StateError(row.errorMessage ?? ''),
      );
      _failed[job.jobKey] = job;
      if (job.kind == PrintJobKind.kot) {
        final err = StateError(row.errorMessage ?? 'KOT printing failed');
        if (!isKotNotReady(err)) {
          _offerKotFailure(
            PrintJobFailure(
              kind: job.kind,
              orderNumber: job.orderNumber,
              orderId: job.orderId,
              isPaperOut: row.paperOut || isPrinterPaperOut(err),
              isDisconnected: isPrinterDisconnected(err),
              error: err,
              jobKey: job.jobKey,
              source: job.source,
              cashier: job.cashier,
            ),
          );
        }
      }
    }
    if (_failed.isNotEmpty) {
      _startHealthWatch();
      notifyListeners();
    }
  }

  Future<void> enqueueKot({
    required int orderId,
    required String orderNumber,
    String source = '',
    Map<String, dynamic>? order,
    bool cashierCheckout = false,
  }) async {
    if (!PosReceiptPrinter.isSupported) return;
    final number = orderNumber.trim();
    if (number.isEmpty && orderId <= 0) return;

    if (!cashierCheckout) {
      if (!await AutoPrintKotSettings.enabled()) return;
      if (order != null &&
          !canAutomaticallyFulfillOrder(order, source: source)) {
        return;
      }
      if (order == null && source.toLowerCase().trim() == 'pos') {
        return;
      }
    }

    await _enqueue(
      _PrintJob(
        kind: PrintJobKind.kot,
        orderId: orderId,
        orderNumber: number,
        source: source,
        cashier: cashierCheckout,
      ),
    );
  }

  Future<void> enqueueReceipt({
    required int orderId,
    String? orderNumber,
  }) async {
    if (!PosReceiptPrinter.isSupported) return;
    if (!PosChannelPrintPolicy.resolve().printsAnyReceiptJob) {
      debugPrint(
        '[PRINT] skip receipt — customer and counter receipts are off for POS',
      );
      return;
    }
    if (orderId <= 0 && (orderNumber == null || orderNumber.trim().isEmpty)) {
      return;
    }
    await _enqueue(
      _PrintJob(
        kind: PrintJobKind.receipt,
        orderId: orderId,
        orderNumber: orderNumber?.trim() ?? '',
      ),
    );
  }

  Future<void> retryFailed({bool includeMayHavePrinted = true}) async {
    final inFlight = _retryFlight;
    if (inFlight != null) {
      await inFlight;
      if (!includeMayHavePrinted) return;
    }
    final run = _retryFailedOnce(includeMayHavePrinted: includeMayHavePrinted);
    _retryFlight = run;
    try {
      await run;
    } finally {
      if (identical(_retryFlight, run)) _retryFlight = null;
    }
  }

  Future<void> _retryFailedOnce({required bool includeMayHavePrinted}) async {
    if (_failed.isEmpty) return;
    final jobs = _failed.values
        .where((job) => includeMayHavePrinted || !job.mayHavePrinted)
        .toList()
      ..sort((a, b) {
        final byTime = a.queuedAt.compareTo(b.queuedAt);
        if (byTime != 0) return byTime;
        if (a.kind != b.kind) {
          return a.kind == PrintJobKind.kot ? -1 : 1;
        }
        return a.jobKey.compareTo(b.jobKey);
      });
    if (jobs.isEmpty) return;
    for (final job in jobs) {
      if (_queued.contains(job.jobKey)) continue;
      _failed.remove(job.jobKey);
      job.forceAttempt = true;
      _completed.remove(job.jobKey);
      await _enqueue(job, append: true);
    }
  }

  void onHealthChanged(PrinterHealth health) {
    final wasBlocked = _isBlockedHealth(_lastHealthState, _lastIssues);
    _lastHealthState = health.state;
    _lastIssues = health.issues;
    final paperOrCable =
        health.issues.contains('paper_out') ||
        health.issues.contains('offline') ||
        health.issues.contains('missing');
    final ready =
        !health.hasIssue ||
        ((health.state == PrinterHealthState.ready ||
                health.state == PrinterHealthState.attention) &&
            !paperOrCable);
    if (wasBlocked && ready && _failed.isNotEmpty) {
      unawaited(retryFailed(includeMayHavePrinted: false));
    }
  }

  bool _isBlockedHealth(PrinterHealthState? state, List<String> issues) {
    if (state == PrinterHealthState.missing ||
        state == PrinterHealthState.error ||
        state == PrinterHealthState.none ||
        state == PrinterHealthState.notPrintable) {
      return true;
    }
    return issues.contains('paper_out') ||
        issues.contains('offline') ||
        issues.contains('missing');
  }

  /// Last probe only. Never scans or connects — checkout must stay instant.
  void _throwIfCachedPrinterDown(_PrintJob job) {
    if (job.forceAttempt) return;
    final status = _printerStatus;
    if (status == null || !status.hasProbed) return;

    final health = status.health;
    if (health.state == PrinterHealthState.unsupported) {
      throw const PrintSkipped('Printing is not supported on this device.');
    }
    if (!health.blocksPrinting) return;

    if (health.issues.contains('paper_out')) {
      throw StateError(
        health.message ?? 'Printer paper out. Replace the roll.',
      );
    }
    if (health.state == PrinterHealthState.none) {
      throw StateError(thermalPrinterMissingMessage());
    }
    throw StateError(
      health.message ??
          'The printer is disconnected or not responding.',
    );
  }

  Future<void> _enqueue(_PrintJob job, {bool append = false}) async {
    final key = job.jobKey;
    if (key.isEmpty) return;
    if (_completed.contains(key) || _queued.contains(key)) return;

    _queued.add(key);
    if (!append && job.kind == PrintJobKind.kot) {
      _queue.addFirst(job);
    } else {
      _queue.add(job);
    }
    await PendingPrintJobStore.upsert(
      PendingPrintJob(
        jobKey: key,
        kind: job.kind.name,
        orderId: job.orderId,
        orderNumber: job.orderNumber,
        source: job.source,
        cashier: job.cashier,
        createdAtMs: job.queuedAt.millisecondsSinceEpoch,
      ),
    );
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeFirst();
        try {
          if (job.kind == PrintJobKind.kot) {
            await _printKot(job);
          } else {
            await _printReceipt(job);
          }
          _completed.add(job.jobKey);
          _failed.remove(job.jobKey);
          ackFailure(job.jobKey);
          await PendingPrintJobStore.markDone(job.jobKey);
          _remember(job.jobKey);
          if (_failed.isEmpty) _healthWatch?.cancel();
        } catch (error) {
          if (isPrintingDisabled(error)) {
            _completed.add(job.jobKey);
            _failed.remove(job.jobKey);
            await PendingPrintJobStore.markDone(job.jobKey);
            _remember(job.jobKey);
            debugPrint(
              '[PRINT] skipped ${job.kind.name} ${job.orderNumber} $error',
            );
          } else {
            job.mayHavePrinted = _printMayHaveStarted(error);
            _failed[job.jobKey] = job;
            await PendingPrintJobStore.upsert(
              PendingPrintJob(
                jobKey: job.jobKey,
                kind: job.kind.name,
                orderId: job.orderId,
                orderNumber: job.orderNumber,
                source: job.source,
                cashier: job.cashier,
                status: 'failed',
                errorMessage: error.toString(),
                paperOut: isPrinterPaperOut(error),
              ),
            );
            _startHealthWatch();
            _printerStatus?.markUnreachable(error);
            debugPrint(
              '[PRINT] failed ${job.kind.name} ${job.orderNumber} $error',
            );
            if (job.kind == PrintJobKind.kot && !isKotNotReady(error)) {
              _offerKotFailure(
                PrintJobFailure(
                  kind: job.kind,
                  orderNumber: job.orderNumber,
                  orderId: job.orderId,
                  isPaperOut: isPrinterPaperOut(error),
                  isDisconnected: isPrinterDisconnected(error),
                  error: error,
                  jobKey: job.jobKey,
                  source: job.source,
                  cashier: job.cashier,
                ),
              );
            }
            notifyListeners();
          }
        } finally {
          _queued.remove(job.jobKey);
        }
      }
    } finally {
      _draining = false;
      if (_queue.isNotEmpty) {
        unawaited(_drain());
      }
    }
  }

  Future<void> _printKot(_PrintJob job) async {
    final current = _session?.call();
    if (current == null) {
      throw StateError('Not signed in.');
    }
    _throwIfCachedPrinterDown(job);
    Object? lastError;
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 200),
      Duration(milliseconds: 400),
      Duration(milliseconds: 700),
      Duration(milliseconds: 1000),
      Duration(milliseconds: 1500),
      Duration(milliseconds: 2000),
    ];
    for (var i = 0; i < delays.length; i++) {
      final wait = delays[i];
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      try {
        await PosReceiptPrinter.printKotByOrderNumber(
          session: current,
          orderNumber: job.orderNumber.isNotEmpty
              ? job.orderNumber
              : '${job.orderId}',
        );
        return;
      } catch (error) {
        if (isPrintingDisabled(error)) rethrow;
        lastError = error;
        final text = error.toString().toLowerCase();
        final notReady =
            isKotNotReady(error) ||
            text.contains('no kot slips') ||
            text.contains('not available') ||
            text.contains('no printable');
        if (!notReady) rethrow;
      }
    }
    throw lastError ?? StateError('KOT is not available yet.');
  }

  Future<void> _printReceipt(_PrintJob job) async {
    final current = _session?.call();
    final url = _serverUrl?.call();
    if (current == null || url == null) {
      throw StateError('Not signed in.');
    }
    _throwIfCachedPrinterDown(job);
    await PosReceiptPrinter.printReceipt(
      session: current,
      serverUrl: url,
      orderId: job.orderId,
      orderNumber: job.orderNumber.isEmpty ? null : job.orderNumber,
    );
  }

  void _remember(String key) {
    _completed.add(key);
    if (_completed.length > 160) {
      _completed.removeAll(_completed.take(_completed.length - 120));
    }
  }

  void _startHealthWatch() {
    _healthWatch?.cancel();
    if (_failed.isEmpty) return;
    _healthWatch = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_printerStatus?.refresh());
      final health = _printerStatus?.health;
      if (health != null) onHealthChanged(health);
      if (_failed.isNotEmpty &&
          !_draining &&
          health != null &&
          !health.blocksPrinting) {
        unawaited(retryFailed(includeMayHavePrinted: false));
      }
    });
  }

  void _offerKotFailure(PrintJobFailure event) {
    if (event.kind != PrintJobKind.kot || event.kotNotReady) return;
    _pendingKotUi.removeWhere((existing) => existing.jobKey == event.jobKey);
    _pendingKotUi.add(event);
    if (!_failures.isClosed) {
      _failures.add(event);
    }
  }

  Future<void> warmPrinter() async {
    final health = _printerStatus?.health;
    if (_printerStatus?.hasProbed == true &&
        (health == null ||
            health.blocksPrinting ||
            health.state == PrinterHealthState.unsupported)) {
      return;
    }
    unawaited(PosReceiptPrinter.warmUp());
  }

  @override
  void dispose() {
    _healthWatch?.cancel();
    unawaited(_failures.close());
    super.dispose();
  }
}
