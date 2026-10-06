import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/pos_models.dart';
import '../../utils/pos_user_facing_error.dart';
import '../pos_api.dart';
import 'connectivity_service.dart';
import 'offline_order_payload.dart';
import 'pending_order.dart';
import 'offline_token_store.dart';

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
      await syncPendingOrders(includeFailed: true);
    }
  }

  void _onConnectivityChanged() {
    final status = connectivity.status;
    final wasOffline = _lastConnectivityStatus == ConnectionStatus.offline ||
        _lastConnectivityStatus == ConnectionStatus.checking;
    _lastConnectivityStatus = status;

    if (status == ConnectionStatus.online && wasOffline && _session != null) {
      unawaited(syncPendingOrders(includeFailed: true));
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
    String? idempotencyKey,
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
      idempotencyKey: idempotencyKey,
      tokenScope: OfflineTokenStore.scopeFor(session),
    );

    await _refreshCounts();
    return pending;
  }

  Future<void> syncPendingOrders({bool includeFailed = false}) async {
    final session = _session;
    if (session == null || _syncing || !connectivity.isOnline) {
      return;
    }
    if (PosApi.isRateLimited) return;

    _syncing = true;
    notifyListeners();

    try {
      await PendingOrderStore.resetOrphanedSyncing(session.branchId);
      final pendingOrders = await PendingOrderStore.getPendingOrders(
        session.branchId,
        includeFailed: includeFailed,
      );

      for (final order in pendingOrders) {
        if (!connectivity.isOnline) break;
        final step = await _syncOrder(order, session);
        if (step == _SyncStep.retryLater) break;
      }
    } finally {
      _syncing = false;
      await _refreshCounts();
      notifyListeners();
    }
  }

  Future<_SyncStep> _syncOrder(PendingOrder order, PosSession session) async {
    try {
      await PendingOrderStore.markSyncing(order.localUuid);

      final discountRaw = order.orderData['discount'];
      final discount = discountRaw is Map
          ? Map<String, dynamic>.from(discountRaw)
          : null;
      final paymentRaw = order.orderData['pos_register_payment'];
      if (paymentRaw is! Map) {
        await PendingOrderStore.markFailed(
          localUuid: order.localUuid,
          errorMessage: 'Saved order is missing a payment method.',
        );
        onOrderSynced?.call(
          order.copyWith(
            status: PendingOrderStatus.failed,
            errorMessage: 'Saved order is missing a payment method.',
          ),
          false,
        );
        return _SyncStep.failed;
      }

      final items = _itemsForSync(order.orderData);
      if (items.isEmpty) {
        const message = 'This offline order has no items to send.';
        await PendingOrderStore.markFailed(
          localUuid: order.localUuid,
          errorMessage: message,
        );
        onOrderSynced?.call(
          order.copyWith(
            status: PendingOrderStatus.failed,
            errorMessage: message,
          ),
          false,
        );
        return _SyncStep.failed;
      }

      final serverOrder = await api.createOrder(
        session,
        items: items,
        type: order.orderData['type']?.toString().trim().isNotEmpty == true
            ? order.orderData['type'].toString()
            : 'dine_in',
        posTerminalId: _asInt(order.orderData['pos_terminal_id']),
        tableId: _asInt(order.orderData['table_id']),
        customerId: _asInt(order.orderData['customer_id']),
        customerName: order.orderData['customer_name']?.toString(),
        notes: order.orderData['notes']?.toString(),
        discount: discount,
        payment: Map<String, dynamic>.from(paymentRaw),
        idempotencyKey:
            order.orderData['idempotency_key'] as String? ?? order.localUuid,
      );

      if (serverOrder.id <= 0 && serverOrder.orderNumber.trim().isEmpty) {
        const message = 'Order response missing order payload.';
        await PendingOrderStore.markFailed(
          localUuid: order.localUuid,
          errorMessage: message,
        );
        onOrderSynced?.call(
          order.copyWith(
            status: PendingOrderStatus.failed,
            errorMessage: message,
          ),
          false,
        );
        return _SyncStep.failed;
      }

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

      return _SyncStep.synced;
    } on PosApiException catch (e) {
      final safe = posUserFacingError(e);
      if (_isRetryableApiError(e)) {
        await PendingOrderStore.markPending(
          order.localUuid,
          errorMessage: safe,
        );
        return _SyncStep.retryLater;
      }
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

      return _SyncStep.failed;
    } catch (e) {
      final safe = posUserFacingError(e);
      await PendingOrderStore.markPending(
        order.localUuid,
        errorMessage: safe,
      );
      return _SyncStep.retryLater;
    }
  }

  bool _isRetryableApiError(PosApiException error) {
    final code = error.statusCode;
    if (code == null || code == 408 || code == 429 || code >= 500) {
      return true;
    }
    return false;
  }

  int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _itemsForSync(Map<String, dynamic> orderData) {
    final saved = _orderItems(orderData['items']);
    if (saved.any((item) => item['menu_item_id'] != null)) return saved;
    return _itemsFromSnapshot(orderData['cart_snapshot']);
  }

  List<Map<String, dynamic>> _itemsFromSnapshot(Object? raw) {
    if (raw is! List) return const [];
    final items = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final line = Map<String, dynamic>.from(entry);
      final menuItemId = line['menu_item_id'];
      if (menuItemId == null) continue;
      final modifiers = <Map<String, dynamic>>[];
      final rawMods = line['modifiers'];
      if (rawMods is List) {
        for (final mod in rawMods) {
          if (mod is! Map) continue;
          final optionId = mod['modifier_option_id'];
          if (optionId == null) continue;
          modifiers.add({
            'modifier_option_id': optionId,
            'quantity': 1,
          });
        }
      }
      items.add({
        'menu_item_id': menuItemId,
        if (line['variant_id'] != null) 'variant_id': line['variant_id'],
        'quantity': line['quantity'] ?? 1,
        if (line['notes'] != null && '${line['notes']}'.trim().isNotEmpty)
          'notes': line['notes'],
        if (modifiers.isNotEmpty) 'modifiers': modifiers,
      });
    }
    return items;
  }

  List<Map<String, dynamic>> _orderItems(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
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

enum _SyncStep { synced, failed, retryLater }
