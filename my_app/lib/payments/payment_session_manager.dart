import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../services/pos_api.dart';
import 'payment_session.dart';
import 'payment_session_store.dart';

typedef PaymentStatusQuery = Future<String?> Function(int orderId);

class PaymentSessionManager extends ChangeNotifier {
  PaymentSessionManager._();

  static final instance = PaymentSessionManager._();
  static const _uuid = Uuid();

  final PaymentSessionStore _store = PaymentSessionStore();
  final Map<String, PaymentSession> _sessions = {};
  final Map<String, Future<void>> _locks = {};
  final Map<String, Timer> _pollers = {};
  final Set<String> _pollsInFlight = {};
  Timer? _expiryTimer;
  PaymentStatusQuery? _queryStatus;
  bool _hydrated = false;

  List<PaymentSession> get sessions => List.unmodifiable(
        _sessions.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  List<PaymentSession> get activeSessions =>
      sessions.where((session) => !session.status.isTerminal).toList();

  Future<void> start(PaymentStatusQuery queryStatus) async {
    _queryStatus = queryStatus;
    if (!_hydrated) {
      for (final session in await _store.load()) {
        _sessions[session.paymentSessionId] = session;
      }
      _hydrated = true;
    }
    _expiryTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_expireDueSessions()),
    );
    for (final session in activeSessions) {
      _startMonitor(session.paymentSessionId);
    }
    notifyListeners();
  }

  void stop() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    for (final timer in _pollers.values) {
      timer.cancel();
    }
    _pollers.clear();
    _queryStatus = null;
  }

  Future<PaymentSession> createPersisted({
    required int orderId,
    required String orderNumber,
    required String? transactionId,
    required double amount,
    required String qrData,
    required int timeoutSeconds,
    DateTime? expiresAt,
    required Map<String, dynamic> orderSnapshot,
  }) async {
    final now = DateTime.now();
    for (final previous in _sessions.values
        .where(
          (candidate) =>
              candidate.orderId == orderId && !candidate.status.isTerminal,
        )
        .toList()) {
      _pollers.remove(previous.paymentSessionId)?.cancel();
      _sessions[previous.paymentSessionId] = previous.copyWith(
        status: PaymentSessionStatus.cancelled,
      );
    }
    final displayTimeout = Duration(seconds: timeoutSeconds.clamp(1, 900));
    final session = PaymentSession(
      paymentSessionId: 'PS-${_uuid.v4()}',
      orderId: orderId,
      orderNumber: orderNumber,
      transactionId: transactionId,
      amount: amount,
      qrData: qrData,
      createdAt: now,
      expiresAt: expiresAt != null && expiresAt.isAfter(now)
          ? expiresAt
          : now.add(displayTimeout),
      status: PaymentSessionStatus.waitingForDisplay,
      orderSnapshot: Map.unmodifiable(orderSnapshot),
    );
    _sessions[session.paymentSessionId] = session;
    try {
      await _persist();
    } on Object {
      _sessions.remove(session.paymentSessionId);
      rethrow;
    }
    notifyListeners();
    return session;
  }

  Future<bool> transition(String id, PaymentSessionStatus next) {
    return _locked(id, () async {
      final current = _sessions[id];
      if (current == null || current.status.isTerminal) return false;
      if (!_allowed(current.status, next)) return false;
      _sessions[id] = current.copyWith(
        status: next,
        successHandled:
            next == PaymentSessionStatus.paid ? true : current.successHandled,
      );
      if (next.isTerminal) _pollers.remove(id)?.cancel();
      await _persist();
      notifyListeners();
      return true;
    });
  }

  Future<bool> reconcileAuthoritative(String id, String? backendStatus) {
    return _locked(id, () async {
      final current = _sessions[id];
      if (current == null) return false;
      final value = backendStatus?.trim().toLowerCase();
      final next = switch (value) {
        'paid' ||
        'success' ||
        'successful' ||
        'completed' ||
        'captured' ||
        'settled' =>
          PaymentSessionStatus.paid,
        'failed' || 'failure' => PaymentSessionStatus.failed,
        'cancelled' || 'canceled' => PaymentSessionStatus.cancelled,
        'expired' || 'timed_out' || 'timeout' => PaymentSessionStatus.expired,
        _ => null,
      };
      if (next == null || current.status == PaymentSessionStatus.paid) {
        return current.status == PaymentSessionStatus.paid;
      }
      if (current.status.isTerminal && next != PaymentSessionStatus.paid) {
        return false;
      }
      _sessions[id] = current.copyWith(
        status: next,
        successHandled:
            next == PaymentSessionStatus.paid || current.successHandled,
      );
      if (next.isTerminal) _pollers.remove(id)?.cancel();
      await _persist();
      notifyListeners();
      return next == PaymentSessionStatus.paid;
    });
  }

  PaymentSession? sessionForOrder(int orderId) {
    final matches =
        sessions.where((session) => session.orderId == orderId).toList();
    return matches.isEmpty ? null : matches.last;
  }

  Future<void> markHeldForNewOrder(String id) {
    return _locked(id, () async {
      final current = _sessions[id];
      if (current == null || current.status.isTerminal || current.heldForNewOrder) {
        return;
      }
      _sessions[id] = current.copyWith(heldForNewOrder: true);
      await _persist();
      notifyListeners();
    });
  }

  Future<void> markReceiptPrinted(String id) {
    return _locked(id, () async {
      final current = _sessions[id];
      if (current == null || current.receiptPrinted) return;
      _sessions[id] = current.copyWith(receiptPrinted: true);
      await _persist();
      notifyListeners();
    });
  }

  void monitor(String id) => _startMonitor(id);

  void _startMonitor(String id) {
    if (_pollers.containsKey(id)) return;
    _pollers[id] = Timer.periodic(const Duration(seconds: 3), (_) async {
      final session = _sessions[id];
      final query = _queryStatus;
      if (session == null || session.status.isTerminal || query == null) {
        _pollers.remove(id)?.cancel();
        return;
      }
      if (!_pollsInFlight.add(id)) return;
      try {
        final status = (await query(session.orderId))?.trim().toLowerCase();
        await reconcileAuthoritative(id, status);
      } on PosApiException catch (error) {
        if (error.statusCode == 422) {
          _pollers.remove(id)?.cancel();
        }
      } on Object {
        // Keep the session; a later poll can succeed.
      } finally {
        _pollsInFlight.remove(id);
      }
    });
  }

  Future<void> _expireDueSessions() async {
    final now = DateTime.now();
    for (final session in activeSessions) {
      if (!now.isBefore(session.expiresAt)) {
        await transition(
          session.paymentSessionId,
          PaymentSessionStatus.expired,
        );
      }
    }
  }

  Future<T> _locked<T>(String id, Future<T> Function() action) async {
    final previous = _locks[id] ?? Future<void>.value();
    final completer = Completer<void>();
    _locks[id] = completer.future;
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
      if (identical(_locks[id], completer.future)) _locks.remove(id);
    }
  }

  bool _allowed(PaymentSessionStatus current, PaymentSessionStatus next) {
    if (current == next) return true;
    return switch (current) {
      PaymentSessionStatus.creating =>
        next == PaymentSessionStatus.waitingForDisplay ||
            next == PaymentSessionStatus.failed,
      PaymentSessionStatus.waitingForDisplay =>
        next == PaymentSessionStatus.displayingQr || next.isTerminal,
      PaymentSessionStatus.displayingQr =>
        next == PaymentSessionStatus.waitingPayment || next.isTerminal,
      PaymentSessionStatus.waitingPayment => next.isTerminal,
      _ => false,
    };
  }

  Future<void> _persist() => _store.saveAll(_sessions.values);
}
