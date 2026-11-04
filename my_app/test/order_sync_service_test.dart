import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/services/offline/connectivity_service.dart';
import 'package:my_app/services/offline/offline_token_store.dart';
import 'package:my_app/services/offline/order_sync_service.dart';
import 'package:my_app/services/offline/pending_order.dart';
import 'package:my_app/services/offline/pos_database.dart';
import 'package:my_app/services/pos_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  late Database db;
  late ConnectivityService connectivity;
  late _RecordingApi api;
  late OrderSyncService sync;

  final session = PosSession(
    serverUrl: 'http://pos.test',
    token: 'token',
    restaurantId: 1,
    branchId: 1,
  );

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE pending_orders (
        id INTEGER PRIMARY KEY,
        local_uuid TEXT NOT NULL UNIQUE,
        branch_id INTEGER NOT NULL,
        order_data TEXT NOT NULL,
        local_order_number TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        server_order_id INTEGER,
        server_order_number TEXT,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        synced_at INTEGER,
        printed_at INTEGER
      )
    ''');
    await OfflineTokenStore.createTable(db);
    PosDatabase.debugDatabase = db;
    PosApi.debugSetRateLimitedUntil(null);
    connectivity = ConnectivityService(serverUrl: session.serverUrl);
    connectivity.debugSetStatus(ConnectionStatus.offline);
    api = _RecordingApi();
    sync = OrderSyncService(
      api: api,
      connectivity: connectivity,
      enablePolling: false,
    );
    sync.configure(session);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    sync.dispose();
    connectivity.dispose();
    PosDatabase.debugDatabase = null;
    PosApi.debugSetRateLimitedUntil(null);
    await db.close();
  });

  test('a waiting sale is posted once and marked synced', () async {
    await _queueSale();
    connectivity.debugSetStatus(ConnectionStatus.online);
    api.next = PlacedPosOrder(id: 44, orderNumber: 'SRV-44');

    final result = await sync.syncPendingOrders(includeFailed: true);

    expect(result.stop, OrderSyncStop.finished);
    expect(api.calls, 1);
    expect(api.keys.single, isNotEmpty);
    expect(api.payments.single['method'], 'cash');
    expect(api.items.single.single['menu_item_id'], 9);
    expect(api.items.single.single.containsKey('offline_token'), isFalse);
    final saved = await PendingOrderStore.getByUuid(api.keys.single);
    expect(saved?.status, PendingOrderStatus.synced);
    expect(saved?.serverOrderId, 44);
    expect(saved?.serverOrderNumber, 'SRV-44');

    await sync.syncPendingOrders(includeFailed: true);
    expect(api.calls, 1);
  });

  test('a server 500 stays waiting and a 422 stays failed', () async {
    connectivity.debugSetStatus(ConnectionStatus.online);
    await sync.syncPendingOrders();
    await _queueSale();
    api.error = PosApiException('unavailable', statusCode: 500);
    final retry = await sync.syncPendingOrders(includeFailed: true);
    final key = api.keys.single;
    expect(retry.stop, OrderSyncStop.incomplete);
    expect(
      (await PendingOrderStore.getByUuid(key))?.status,
      PendingOrderStatus.pending,
    );

    api.error = PosApiException('sold out', statusCode: 422);
    await sync.syncPendingOrders(includeFailed: true);
    expect(api.calls, 2);
    expect(
      (await PendingOrderStore.getByUuid(key))?.status,
      PendingOrderStatus.failed,
    );

    api.error = null;
    api.next = PlacedPosOrder(id: 45, orderNumber: 'SRV-45');
    await sync.syncPendingOrders();
    expect(api.calls, 2);

    final recovered = await sync.syncPendingOrders(includeFailed: true);
    expect(recovered.stop, OrderSyncStop.finished);
    expect(api.calls, 3);
  });

  test('offline and rate limit do not post', () async {
    await _queueSale();
    connectivity.debugSetStatus(ConnectionStatus.offline);
    final offline = await sync.syncPendingOrders(includeFailed: true);
    expect(offline.stop, OrderSyncStop.offline);
    expect(api.calls, 0);

    PosApi.debugSetRateLimitedUntil(
      DateTime.now().add(const Duration(minutes: 1)),
    );
    connectivity.debugSetStatus(ConnectionStatus.online);
    final limited = await sync.syncPendingOrders(includeFailed: true);
    expect(limited.stop, OrderSyncStop.rateLimited);
    expect(api.calls, 0);
  });

  test('a second sync waits and does not post the sale twice', () async {
    await _queueSale();
    connectivity.debugSetStatus(ConnectionStatus.online);
    final gate = api.hold();
    api.next = PlacedPosOrder(id: 46, orderNumber: 'SRV-46');
    final first = sync.syncPendingOrders(includeFailed: true);
    await api.started.future;
    final second = sync.syncPendingOrders(includeFailed: true);
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(results.first.stop, OrderSyncStop.finished);
    expect(api.calls, 1);
  });

  test('sync does not call a printer', () {
    final source = File(
      'lib/services/offline/order_sync_service.dart',
    ).readAsStringSync();
    expect(source.contains('PosReceiptPrinter'), isFalse);
    expect(source.contains('printKot'), isFalse);
    expect(source.contains('printReceipt'), isFalse);
    expect(source.contains('printOffline'), isFalse);
  });
}

Future<void> _queueSale() {
  return PendingOrderStore.create(
    branchId: 1,
    tokenScope: 'sync-test',
    tokenStore: OfflineTokenStore(
      database: () async => PosDatabase.debugDatabase!,
    ),
    orderData: {
      'items': [
        {'menu_item_id': 9, 'quantity': 1},
      ],
      'type': 'takeaway',
      'pos_register_payment': {'method': 'cash'},
    },
  );
}

class _RecordingApi extends PosApi {
  PlacedPosOrder? next;
  PosApiException? error;
  final Completer<void> started = Completer<void>();
  Completer<void>? _hold;
  int calls = 0;
  final keys = <String>[];
  final payments = <Map<String, dynamic>>[];
  final items = <List<Map<String, dynamic>>>[];

  Completer<void> hold() {
    final gate = Completer<void>();
    _hold = gate;
    return gate;
  }

  @override
  Future<PlacedPosOrder> createOrder(
    PosSession session, {
    required List<Map<String, dynamic>> items,
    required String type,
    required Map<String, dynamic> payment,
    int? posTerminalId,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
    String? idempotencyKey,
  }) async {
    calls++;
    this.items.add(items);
    payments.add(payment);
    final key = idempotencyKey?.trim() ?? '';
    if (key.isEmpty) {
      throw StateError('Sync posted an order without an idempotency key.');
    }
    keys.add(key);
    if (!started.isCompleted) started.complete();
    final gate = _hold;
    if (gate != null) await gate.future;
    final failure = error;
    if (failure != null) throw failure;
    return next ?? PlacedPosOrder(id: 1, orderNumber: 'SRV-1');
  }
}
