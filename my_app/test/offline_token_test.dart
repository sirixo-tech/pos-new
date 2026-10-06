import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/services/offline/offline_token_store.dart';
import 'package:my_app/services/offline/pending_order.dart';
import 'package:my_app/services/offline/pos_database_platform.dart';
import 'package:my_app/services/printing/offline_print_adapter.dart';
import 'package:my_app/services/printing/offline_kot_builder.dart';
import 'package:my_app/services/printing/pos_local_print_builder.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  late Database db;
  late OfflineTokenStore store;
  setUp(() async {
    db = await posDatabaseFactory.openDatabase(inMemoryDatabasePath);
    await OfflineTokenStore.createTable(db);
    await db.execute('''CREATE TABLE pending_orders (
      id INTEGER PRIMARY KEY, local_uuid TEXT UNIQUE, branch_id INTEGER,
      order_data TEXT, local_order_number TEXT, status TEXT, retry_count INTEGER,
      created_at INTEGER
    )''');
    store = OfflineTokenStore(database: () async => db);
  });
  tearDown(() => db.close());

  Future<PendingOrder> sale({String scope = 'branch:1', String? key}) =>
      PendingOrderStore.create(
        branchId: 1,
        tokenScope: scope,
        tokenStore: store,
        idempotencyKey: key,
        orderData: {
          'type': 'dine_in',
          'pos_register_payment': {'method': 'cash'},
          'cart_snapshot': [
            {'name': 'Dosa', 'quantity': 1, 'unit_price': 50, 'line_total': 50},
          ],
        },
      );

  test(
    'online 12 continues offline 13, 14 and survives store recreation',
    () async {
      await store.observe('branch:1', '12');
      expect((await sale()).offlineToken, 13);
      store = OfflineTokenStore(database: () async => db);
      final next = await sale();
      expect(next.offlineToken, 14);
      final row = (await db.query(
        'pending_orders',
        where: 'local_uuid = ?',
        whereArgs: [next.localUuid],
      )).single;
      expect(PendingOrder.fromRow(row).offlineToken, 14);
    },
  );

  test('concurrent offline sales receive unique consecutive tokens', () async {
    await store.observe('branch:1', 12);
    final orders = await Future.wait(List.generate(5, (_) => sale()));
    expect(orders.map((order) => order.offlineToken).toList()..sort(), [
      13,
      14,
      15,
      16,
      17,
    ]);
  });

  test('older online responses never rewind the local sequence', () async {
    await store.observe('branch:1', 12);
    await sale();
    await store.observe('branch:1', 9);
    expect((await sale()).offlineToken, 14);
    await store.observe('branch:1', 20);
    expect((await sale()).offlineToken, 21);
    expect((await sale(scope: 'another-server|branch:1')).offlineToken, 1);
  });

  test('a failed pending-order save rolls back token allocation', () async {
    await store.observe('branch:1', 12);
    await sale(key: 'same-sale');
    expect((await sale(key: 'same-sale')).offlineToken, 13);
    await expectLater(
      store.allocate<void>('branch:1', (_, __) async {
        throw StateError('disk write failed');
      }),
      throwsStateError,
    );
    expect((await sale()).offlineToken, 14);
  });

  test(
    'receipt and item token slips print saved 13 on every reprint',
    () async {
      await store.observe('branch:1', 12);
      final order = await sale();
      final bootstrap = PosBootstrap.fromJson({
        'restaurant': {
          'id': 1,
          'name': 'Day and Night Canteen',
          'default_currency': 'INR',
        },
        'branch': {'id': 1, 'name': 'Main'},
        'receipt_settings': {
          'pos_receipt_print_mode': 'both',
          'token': {
            'enabled': true,
            'print_with_receipt': true,
            'channels': ['pos'],
          },
        },
      });
      final dto = OfflinePrintAdapter.orderFromPending(
        bootstrap: bootstrap,
        order: order,
      );
      expect(dto.token, 13);
      expect(dto.orderNumber, isEmpty);
      final bytes = await buildPosReceiptBytesLocally(
        bootstrap: bootstrap,
        order: order,
      );
      final reprint = await buildPosReceiptBytesLocally(
        bootstrap: bootstrap,
        order: order,
      );
      expect(reprint, bytes);
      final printed = latin1.decode(bytes);
      expect(
        RegExp(r'TOKEN #13').allMatches(printed).length,
        greaterThanOrEqualTo(2),
      );
      expect(printed, contains('Dosa'));
      expect(printed, isNot(contains(order.localOrderNumber)));
      expect(printed, isNot(contains('Bill No:')));
      final kot = OfflineKotBuilder.buildBytes(
        bootstrap: bootstrap,
        order: order,
      );
      final kitchenText = latin1.decode(kot);
      expect(kitchenText, contains('KITCHEN ORDER'));
      expect(kitchenText, contains('TOKEN #13'));
      expect(kitchenText, contains('Dine in'));
      expect(kitchenText, contains('Date:'));
      expect(kitchenText, contains('1x Dosa'));
      expect(kitchenText, isNot(contains(order.localOrderNumber)));
      expect(kitchenText, isNot(contains('Bill No:')));
      expect(
        OfflineKotBuilder.buildBytes(bootstrap: bootstrap, order: order),
        kot,
      );
      expect(
        OfflinePrintAdapter.orderFromPending(
          bootstrap: bootstrap,
          order: order.copyWith(
            status: PendingOrderStatus.synced,
            serverOrderNumber: 'ONLINE-99',
          ),
        ).orderNumber,
        'ONLINE-99',
      );
      expect(
        order
            .copyWith(
              status: PendingOrderStatus.synced,
              serverOrderNumber: 'ONLINE-99',
            )
            .offlineToken,
        13,
      );
      expect((await sale()).offlineToken, 14);
    },
  );
}
