import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/pos_models.dart';
import 'offline_order_payload.dart';
import 'pos_database.dart';

/// Device-local held (parked) ticket while offline or when park API fails.
class LocalHeldOrder {
  LocalHeldOrder({
    required this.localUuid,
    required this.branchId,
    required this.payload,
    required this.localOrderNumber,
    required this.createdAt,
    this.id,
    this.updatedAt,
  });

  final int? id;
  final String localUuid;
  final int branchId;
  final Map<String, dynamic> payload;
  final String localOrderNumber;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory LocalHeldOrder.fromRow(Map<String, dynamic> row) {
    return LocalHeldOrder(
      id: row['id'] as int?,
      localUuid: row['local_uuid'] as String,
      branchId: row['branch_id'] as int,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      localOrderNumber: row['local_order_number'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: row['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int)
          : null,
    );
  }

  /// Shape compatible with the Held tab / server open-order rows.
  Map<String, dynamic> toListRow() {
    final cart = (payload['resume_cart'] as List?) ?? const [];
    final total = _amountDue(payload);
    return {
      'local_uuid': localUuid,
      'is_local': true,
      'order_number': localOrderNumber,
      'token': null,
      'type': payload['type'] ?? 'dine_in',
      'status': 'draft',
      'payment_status': 'pending',
      'total': total,
      'amount_due': total,
      'item_count': cart.length,
      'can_collect_payment': true,
      'table_id': payload['table_id'],
      'customer_id': payload['customer_id'],
      'customer_name': payload['customer_name'],
      'notes': payload['notes'],
      'created_at': createdAt.toIso8601String(),
      'items': cart,
    };
  }

  static double _amountDue(Map<String, dynamic> payload) {
    final cart = (payload['resume_cart'] as List?) ?? const [];
    var sum = 0.0;
    for (final row in cart) {
      if (row is! Map) continue;
      final qty = (row['quantity'] is num)
          ? (row['quantity'] as num).toDouble()
          : double.tryParse('${row['quantity']}') ?? 1;
      final unit = (row['unit_price'] is num)
          ? (row['unit_price'] as num).toDouble()
          : double.tryParse('${row['unit_price']}') ?? 0;
      sum += unit * qty;
    }
    return sum;
  }
}

class LocalHeldOrderStore {
  LocalHeldOrderStore._();

  static const _uuid = Uuid();
  static int _counter = 0;

  static const _webHeldPrefix = 'pos_local_held_';
  static const _webBranchHeldList = 'pos_local_held_uuids_';

  static String generateLocalOrderNumber() {
    _counter++;
    final stamp =
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return 'H$stamp-$_counter';
  }

  static Future<LocalHeldOrder> create({
    required int branchId,
    required List<CartLine> cart,
    required String orderType,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
  }) async {
    final localUuid = _uuid.v4();
    final localOrderNumber = generateLocalOrderNumber();
    final now = DateTime.now().millisecondsSinceEpoch;

    final payload = {
      'items': cart.map((line) => line.toOrderJson()).toList(),
      'resume_cart': cartRowsForHeldResume(cart),
      'cart_snapshot': buildOfflineOrderPayload(
        cart: cart,
        orderType: orderType,
        payment: const {'method': 'pay_later'},
      )['cart_snapshot'],
      'type': orderType,
      if (tableId != null) 'table_id': tableId,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null && customerName.isNotEmpty)
        'customer_name': customerName,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (discount != null) 'discount': discount,
    };

    final order = LocalHeldOrder(
      localUuid: localUuid,
      branchId: branchId,
      payload: payload,
      localOrderNumber: localOrderNumber,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = jsonEncode({
          'local_uuid': localUuid,
          'branch_id': branchId,
          'payload': jsonEncode(payload),
          'local_order_number': localOrderNumber,
          'created_at': now,
          'updated_at': now,
        });
        await prefs.setString('$_webHeldPrefix$localUuid', raw);
        final uuids = prefs.getStringList('$_webBranchHeldList$branchId') ?? [];
        if (!uuids.contains(localUuid)) {
          uuids.insert(0, localUuid);
          await prefs.setStringList('$_webBranchHeldList$branchId', uuids);
        }
      } catch (e) {
        debugPrint('LocalHeldOrderStore web create failed: $e');
      }
      return order;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.insert('local_held_orders', {
        'local_uuid': localUuid,
        'branch_id': branchId,
        'payload': jsonEncode(payload),
        'local_order_number': localOrderNumber,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      debugPrint('LocalHeldOrderStore create failed: $e');
    }

    return order;
  }

  static Future<List<LocalHeldOrder>> listForBranch(int branchId) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final uuids = prefs.getStringList('$_webBranchHeldList$branchId') ?? [];
        final list = <LocalHeldOrder>[];
        for (final uuid in uuids) {
          final raw = prefs.getString('$_webHeldPrefix$uuid');
          if (raw != null) {
            final row = jsonDecode(raw) as Map<String, dynamic>;
            list.add(LocalHeldOrder.fromRow(row));
          }
        }
        return list;
      } catch (e) {
        debugPrint('LocalHeldOrderStore web listForBranch failed: $e');
        return [];
      }
    }

    try {
      final db = await PosDatabase.instance.database;
      final rows = await db.query(
        'local_held_orders',
        where: 'branch_id = ?',
        whereArgs: [branchId],
        orderBy: 'created_at DESC',
      );
      return rows.map(LocalHeldOrder.fromRow).toList();
    } catch (e) {
      debugPrint('LocalHeldOrderStore listForBranch failed: $e');
      return [];
    }
  }

  static Future<int> countForBranch(int branchId) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final uuids = prefs.getStringList('$_webBranchHeldList$branchId') ?? [];
        return uuids.length;
      } catch (e) {
        return 0;
      }
    }

    try {
      final db = await PosDatabase.instance.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM local_held_orders WHERE branch_id = ?',
        [branchId],
      );
      return (result.first['c'] as int?) ?? 0;
    } catch (e) {
      debugPrint('LocalHeldOrderStore countForBranch failed: $e');
      return 0;
    }
  }

  static Future<LocalHeldOrder?> get(String localUuid) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$_webHeldPrefix$localUuid');
        if (raw == null) return null;
        final row = jsonDecode(raw) as Map<String, dynamic>;
        return LocalHeldOrder.fromRow(row);
      } catch (e) {
        return null;
      }
    }

    try {
      final db = await PosDatabase.instance.database;
      final rows = await db.query(
        'local_held_orders',
        where: 'local_uuid = ?',
        whereArgs: [localUuid],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LocalHeldOrder.fromRow(rows.first);
    } catch (e) {
      debugPrint('LocalHeldOrderStore get failed: $e');
      return null;
    }
  }

  static Future<void> updateCart({
    required String localUuid,
    required List<CartLine> cart,
    required String orderType,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
  }) async {
    final existing = await get(localUuid);
    if (existing == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      ...existing.payload,
      'items': cart.map((line) => line.toOrderJson()).toList(),
      'resume_cart': cartRowsForHeldResume(cart),
      'cart_snapshot': buildOfflineOrderPayload(
        cart: cart,
        orderType: orderType,
        payment: const {'method': 'pay_later'},
      )['cart_snapshot'],
      'type': orderType,
      'table_id': tableId,
      'customer_id': customerId,
      'customer_name': customerName,
      'notes': notes,
      'discount': discount,
    }..removeWhere((key, value) => value == null);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = jsonEncode({
          'local_uuid': localUuid,
          'branch_id': existing.branchId,
          'payload': jsonEncode(payload),
          'local_order_number': existing.localOrderNumber,
          'created_at': existing.createdAt.millisecondsSinceEpoch,
          'updated_at': now,
        });
        await prefs.setString('$_webHeldPrefix$localUuid', raw);
      } catch (e) {
        debugPrint('LocalHeldOrderStore web updateCart failed: $e');
      }
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.update(
        'local_held_orders',
        {
          'payload': jsonEncode(payload),
          'updated_at': now,
        },
        where: 'local_uuid = ?',
        whereArgs: [localUuid],
      );
    } catch (e) {
      debugPrint('LocalHeldOrderStore updateCart failed: $e');
    }
  }

  static Future<void> delete(String localUuid) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$_webHeldPrefix$localUuid');
        if (raw != null) {
          final row = jsonDecode(raw) as Map<String, dynamic>;
          final branchId = row['branch_id'] as int?;
          if (branchId != null) {
            final uuids =
                prefs.getStringList('$_webBranchHeldList$branchId') ?? [];
            uuids.remove(localUuid);
            await prefs.setStringList('$_webBranchHeldList$branchId', uuids);
          }
          await prefs.remove('$_webHeldPrefix$localUuid');
        }
      } catch (e) {
        debugPrint('LocalHeldOrderStore web delete failed: $e');
      }
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.delete(
        'local_held_orders',
        where: 'local_uuid = ?',
        whereArgs: [localUuid],
      );
    } catch (e) {
      debugPrint('LocalHeldOrderStore delete failed: $e');
    }
  }
}
