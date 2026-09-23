import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/pos_models.dart';
import '../../utils/pos_user_facing_error.dart';
import '../pos_api.dart';
import 'connectivity_service.dart';
import 'offline_order_payload.dart';
import 'pending_order.dart';

typedef OrderSyncCallback = void Function(PendingOrder order, bool success);

class OrderSyncService extends ChangeNotifier {
  OrderSyncService({
    required this.api,
    required this.connectivity,
  }) {
    connectivity.addListener(_onConnectivityChanged);
  }

  final PosApi api;
  final ConnectivityService connectivity;

  bool _syncing = false;
  int _pendingCount = 0;
  int _failedCount = 0;
  String? _lastError;
  Timer? _syncTimer;
  PosSession? _session;
  ConnectionStatus? _lastConnectivityStatus;
  OrderSyncCallback? onOrderSynced;

  bool get isSyncing => _syncing;
  int get pendingCount => _pendingCount;
  int get failedCount => _failedCount;
  String? get lastError => _lastError;
  bool get hasPendingOrders => _pendingCount > 0;
  bool get hasFailedOrders => _failedCount > 0;

  void configure(PosSession? session) {
    _session = session;
    if (session != null) {
      unawaited(_prepareAndMaybeSync());
      _startSyncTimer();
    } else {
      _stopSyncTimer();
      _pendingCount = 0;
      _failedCount = 0;
      _lastError = null;
      notifyListeners();
    }
  }

  Future<void> _prepareAndMaybeSync() async {
    final session = _session;
    if (session == null) return;
    await PendingOrderStore.resetOrphanedSyncing(session.branchId);
    await _refreshCounts();
    if (connectivity.isOnline) {
      await syncPendingOrders();
    }
  }

  void _onConnectivityChanged() {
    final status = connectivity.status;
    final wasOffline = _lastConnectivityStatus == ConnectionStatus.offline ||
        _lastConnectivityStatus == ConnectionStatus.checking;
    _lastConnectivityStatus = status;

    if (status == ConnectionStatus.online && wasOffline && _session != null) {
      unawaited(syncPendingOrders());
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => syncPendingOrders(),
    );
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _refreshCounts() async {
    final session = _session;
    if (session == null) return;

    _pendingCount = await PendingOrderStore.getPendingCount(session.branchId);
    _failedCount = await PendingOrderStore.getFailedCount(session.branchId);
    _lastError = await PendingOrderStore.getLatestError(session.branchId);
    notifyListeners();
  }

  Future<PendingOrder> createOfflineOrder({
    required List<CartLine> cart,
    required String orderType,
    required Map<String, dynamic> payment,
    int? posTerminalId,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('Not signed in');
    }

    final orderData = buildOfflineOrderPayload(
      cart: cart,
      orderType: orderType,
      payment: payment,
      posTerminalId: posTerminalId,
      tableId: tableId,
      customerId: customerId,
      customerName: customerName,
      notes: notes,
      discount: discount,
    );

    final pending = await PendingOrderStore.create(
      branchId: session.branchId,
      orderData: orderData,
    );

    await _refreshCounts();
    return pending;
  }

  Future<void> syncPendingOrders() async {
    final session = _session;
    if (session == null || _syncing || !connectivity.isOnline) {
      return;
    }

    _syncing = true;
    notifyListeners();

    try {
      await PendingOrderStore.resetOrphanedSyncing(session.branchId);
      final pendingOrders =
          await PendingOrderStore.getPendingOrders(session.branchId);

      for (final order in pendingOrders) {
        if (!connectivity.isOnline) break;
        await _syncOrder(order, session);
      }
    } finally {
      _syncing = false;
      await _refreshCounts();
      notifyListeners();
    }
  }

  Future<bool> _syncOrder(PendingOrder order, PosSession session) async {
    try {
      await PendingOrderStore.markSyncing(order.localUuid);

      final discountRaw = order.orderData['discount'];
      final discount = discountRaw is Map
          ? Map<String, dynamic>.from(discountRaw)
          : null;

      final serverOrder = await api.createOrder(
        session,
        items: (order.orderData['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>(),
        type: order.orderData['type'] as String,
        posTerminalId: order.orderData['pos_terminal_id'] as int?,
        tableId: order.orderData['table_id'] as int?,
        customerId: order.orderData['customer_id'] as int?,
        customerName: order.orderData['customer_name'] as String?,
        notes: order.orderData['notes'] as String?,
        discount: discount,
        payment:
            order.orderData['pos_register_payment'] as Map<String, dynamic>,
        idempotencyKey:
            order.orderData['idempotency_key'] as String? ?? order.localUuid,
      );

      await PendingOrderStore.markSynced(
        localUuid: order.localUuid,
        serverOrderId: serverOrder.id,
        serverOrderNumber: serverOrder.orderNumber,
      );

      final updated = order.copyWith(
        status: PendingOrderStatus.synced,
        serverOrderId: serverOrder.id,
        serverOrderNumber: serverOrder.orderNumber,
        syncedAt: DateTime.now(),
        errorMessage: null,
      );
      onOrderSynced?.call(updated, true);

      return true;
    } on PosApiException catch (e) {
      // Failed rows stay in the outbox and are retried on the next flush.
      // Hard 4xx (e.g. shift required) surface via lastError until resolved.
      final safe = posUserFacingError(e);
      await PendingOrderStore.markFailed(
        localUuid: order.localUuid,
        errorMessage: safe,
      );

      final updated = order.copyWith(
        status: PendingOrderStatus.failed,
        errorMessage: safe,
        retryCount: order.retryCount + 1,
      );
      onOrderSynced?.call(updated, false);

      return false;
    } catch (e) {
      final safe = posUserFacingError(e);
      await PendingOrderStore.markFailed(
        localUuid: order.localUuid,
        errorMessage: safe,
      );

      final updated = order.copyWith(
        status: PendingOrderStatus.failed,
        errorMessage: safe,
        retryCount: order.retryCount + 1,
      );
      onOrderSynced?.call(updated, false);

      return false;
    }
  }

  Future<void> retrySingleOrder(String localUuid) async {
    final session = _session;
    if (session == null || !connectivity.isOnline) return;

    final order = await PendingOrderStore.getByUuid(localUuid);
    if (order == null) return;

    await _syncOrder(order, session);
    await _refreshCounts();
  }

  @override
  void dispose() {
    connectivity.removeListener(_onConnectivityChanged);
    _stopSyncTimer();
    super.dispose();
  }
}
