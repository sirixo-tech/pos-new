import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/services/pos_api.dart';
import 'package:my_app/services/printing/print_job_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FloorApi extends PosApi {
  final tables = Completer<Map<String, dynamic>>();
  final orders = Completer<List<Map<String, dynamic>>>();
  int tableCalls = 0;
  int orderCalls = 0;

  @override
  Future<Map<String, dynamic>> fetchTables(PosSession session) {
    tableCalls++;
    return tables.future;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFloorOrders(PosSession session) {
    orderCalls++;
    return orders.future;
  }
}

class _Captain extends PosController {
  _Captain(_FloorApi api) : super(api: api);
  @override
  Future<List<Map<String, dynamic>>> fetchHeldOrders() async => [];
  @override
  Future<void> refreshHeldOrderCount() async {}
}

class _KitchenApi extends PosApi {
  @override
  Future<PlacedPosOrder> sendToKitchen(PosSession session, {
    required List<Map<String, dynamic>> items, required String type,
    int? tableId, int? customerId, String? customerName, String? notes,
    Map<String, dynamic>? discount,
  }) async => PlacedPosOrder(id: 53, orderNumber: 'ORD-53');
}

class _PrintQueue extends PrintJobCoordinator {
  final orders = <int>[];
  @override
  Future<void> enqueueKot({required int orderId, required String orderNumber,
    String source = '', Map<String, dynamic>? order,
    bool cashierCheckout = false,
  }) async {
    expect(source, 'captain');
    orders.add(orderId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('changing register does not schedule another login printer prompt', () async {
    final pos = PosController();
    await pos.changeTerminal();
    expect(pos.claimPrinterSetupForSession(), isFalse);
    pos.dispose();
  });

  test('printer setup can only be claimed once in the same session', () {
    final pos = PosController();
    expect(pos.claimPrinterSetupForSession(), isTrue);
    expect(pos.claimPrinterSetupForSession(), isFalse);
    pos.dispose();
  });

  test('sending a Captain ticket queues KOT printing immediately', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = _PrintQueue();
    final pos = PosController(api: _KitchenApi(), printJobs: queue)
      ..session = PosSession(serverUrl: 'https://example.test', token: 'test',
        restaurantId: 1, branchId: 1);
    pos.cart.add(CartLine(menuItem: MenuItem(id: 1, name: 'Item', price: 10,
      variants: [], modifiers: []), quantity: 1));
    final order = await pos.sendWaiterKot();
    expect(queue.orders, [order.id]);
    expect(pos.cart, isEmpty);
    pos.dispose();
    queue.dispose();
  });

  test('Captain shows tables before orders and shares concurrent refreshes', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _FloorApi();
    final pos = _Captain(api)
      ..session = PosSession(
        serverUrl: 'https://example.test', token: 'test',
        restaurantId: 1, branchId: 1,
      )
      ..workMode = PosWorkMode.waiter;
    final first = pos.refreshWaiterFloor();
    final second = pos.refreshWaiterFloor();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(api.tableCalls, 1);
    expect(api.orderCalls, 1);
    api.tables.complete({'tables': [{'id': 1, 'status': 'available'}]});
    await Future<void>.delayed(Duration.zero);
    expect(pos.waiterTables, hasLength(1));
    expect(api.orders.isCompleted, isFalse);
    api.orders.complete([]);
    await first;
    expect(pos.waiterRefreshing, isFalse);
    pos.dispose();
  });
}
