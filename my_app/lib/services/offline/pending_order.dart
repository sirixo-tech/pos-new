import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'pos_database.dart';

enum PendingOrderStatus {
  pending,
  syncing,
  synced,
  failed,
}

class PendingOrder {
  PendingOrder({
    required this.localUuid,
    required this.branchId,
    required this.orderData,
    required this.localOrderNumber,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    this.id,
    this.serverOrderId,
    this.serverOrderNumber,
    this.errorMessage,
    this.syncedAt,
    this.printedAt,
  });

  final int? id;
  final String localUuid;
  final int branchId;
  final Map<String, dynamic> orderData;
  final String localOrderNumber;
  final PendingOrderStatus status;
  final int retryCount;
  final int? serverOrderId;
  final String? serverOrderNumber;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final DateTime? printedAt;

  String get displayOrderNumber => serverOrderNumber ?? localOrderNumber;
  bool get isSynced => status == PendingOrderStatus.synced;
  bool get isPrinted => printedAt != null;
  bool get hasSyncError =>
      status == PendingOrderStatus.failed &&
      (errorMessage != null && errorMessage!.trim().isNotEmpty);

  factory PendingOrder.fromRow(Map<String, dynamic> row) {
    return PendingOrder(
      id: row['id'] as int?,
      localUuid: row['local_uuid'] as String,
      branchId: row['branch_id'] as int,
      orderData: jsonDecode(row['order_data'] as String) as Map<String, dynamic>,
      localOrderNumber: row['local_order_number'] as String,
      status: PendingOrderStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => PendingOrderStatus.pending,
      ),
      retryCount: row['retry_count'] as int? ?? 0,
      serverOrderId: row['server_order_id'] as int?,
      serverOrderNumber: row['server_order_number'] as String?,
      errorMessage: row['error_message'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      syncedAt: row['synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['synced_at'] as int)
          : null,
      printedAt: row['printed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['printed_at'] as int)
          : null,
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'local_uuid': localUuid,
      'branch_id': branchId,
      'order_data': jsonEncode(orderData),
      'local_order_number': localOrderNumber,
      'status': status.name,
      'retry_count': retryCount,
      'server_order_id': serverOrderId,
      'server_order_number': serverOrderNumber,
      'error_message': errorMessage,
      'created_at': createdAt.millisecondsSinceEpoch,
      'synced_at': syncedAt?.millisecondsSinceEpoch,
      'printed_at': printedAt?.millisecondsSinceEpoch,
    };
  }

  PendingOrder copyWith({
    PendingOrderStatus? status,
    int? retryCount,
    int? serverOrderId,
    String? serverOrderNumber,
    String? errorMessage,
    DateTime? syncedAt,
    DateTime? printedAt,
    Map<String, dynamic>? orderData,
  }) {
    return PendingOrder(
      id: id,
      localUuid: localUuid,
      branchId: branchId,
      orderData: orderData ?? this.orderData,
      localOrderNumber: localOrderNumber,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      serverOrderId: serverOrderId ?? this.serverOrderId,
      serverOrderNumber: serverOrderNumber ?? this.serverOrderNumber,
      errorMessage: errorMessage,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      printedAt: printedAt ?? this.printedAt,
    );
  }
}

class PendingOrderStore {
  PendingOrderStore._();

  static const _uuid = Uuid();
  static int _localOrderCounter = 0;

  static const _webOrderPrefix = 'pos_pending_order_';
  static const _webBranchList = 'pos_pending_uuids_';

  static String generateLocalOrderNumber() {
    _localOrderCounter++;
    final timestamp =
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return 'L$timestamp-$_localOrderCounter';
  }

  static Future<PendingOrder> create({
    required int branchId,
    required Map<String, dynamic> orderData,
    String? idempotencyKey,
  }) async {
    final supplied = idempotencyKey?.trim();
    final localUuid =
        supplied != null && supplied.isNotEmpty ? supplied : _uuid.v4();
    final localOrderNumber = generateLocalOrderNumber();
    final now = DateTime.now();
    final data = Map<String, dynamic>.from(orderData)
      ..['idempotency_key'] = localUuid;

    final order = PendingOrder(
      id: now.millisecondsSinceEpoch,
      localUuid: localUuid,
      branchId: branchId,
      orderData: data,
      localOrderNumber: localOrderNumber,
      status: PendingOrderStatus.pending,
      retryCount: 0,
      createdAt: now,
    );

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_webOrderPrefix$localUuid',
          jsonEncode(order.toRow()),
        );
        final uuids = prefs.getStringList('$_webBranchList$branchId') ?? [];
        if (!uuids.contains(localUuid)) {
          uuids.add(localUuid);
          await prefs.setStringList('$_webBranchList$branchId', uuids);
        }
      } catch (e) {
        debugPrint('PendingOrderStore web create failed: $e');
      }
      return order;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.insert('pending_orders', {
        'local_uuid': localUuid,
        'branch_id': branchId,
        'order_data': jsonEncode(data),
        'local_order_number': localOrderNumber,
        'status': PendingOrderStatus.pending.name,
        'retry_count': 0,
        'created_at': now.millisecondsSinceEpoch,
      });

      return order;
    } catch (e) {
      debugPrint('PendingOrderStore create failed: $e');
      return order;
    }
  }

  /// Orders waiting to sync — includes orphaned `syncing` rows after a crash.
  static Future<List<PendingOrder>> getPendingOrders(
    int branchId, {
    bool includeFailed = true,
  }) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final uuids = prefs.getStringList('$_webBranchList$branchId') ?? [];
        final list = <PendingOrder>[];
        for (final uuid in uuids) {
          final raw = prefs.getString('$_webOrderPrefix$uuid');
          if (raw != null) {
            final row = jsonDecode(raw) as Map<String, dynamic>;
            final order = PendingOrder.fromRow(row);
            final status = order.status;
            final waiting = status == PendingOrderStatus.pending ||
                status == PendingOrderStatus.syncing ||
                (includeFailed && status == PendingOrderStatus.failed);
            if (waiting) {
              list.add(order);
            }
          }
        }
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return list;
      } catch (e) {
        debugPrint('PendingOrderStore web getPendingOrders failed: $e');
        return [];
      }
    }

    try {
      final db = await PosDatabase.instance.database;
      final statuses = <String>[
        PendingOrderStatus.pending.name,
        PendingOrderStatus.syncing.name,
        if (includeFailed) PendingOrderStatus.failed.name,
      ];
      final results = await db.query(
        'pending_orders',
        where:
            'branch_id = ? AND status IN (${List.filled(statuses.length, '?').join(', ')})',
        whereArgs: [branchId, ...statuses],
        orderBy: 'created_at ASC',
      );
      return results.map(PendingOrder.fromRow).toList();
    } catch (e) {
      debugPrint('PendingOrderStore getPendingOrders failed: $e');
      return [];
    }
  }

  /// Reset rows left in `syncing` (app killed mid-request) back to `pending`.
  static Future<int> resetOrphanedSyncing(int branchId) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final uuids = prefs.getStringList('$_webBranchList$branchId') ?? [];
        var count = 0;
        for (final uuid in uuids) {
          final raw = prefs.getString('$_webOrderPrefix$uuid');
          if (raw != null) {
            final row = jsonDecode(raw) as Map<String, dynamic>;
            if (row['status'] == PendingOrderStatus.syncing.name) {
              row['status'] = PendingOrderStatus.pending.name;
              await prefs.setString('$_webOrderPrefix$uuid', jsonEncode(row));
              count++;
            }
          }
        }
        return count;
      } catch (_) {
        return 0;
      }
    }

    try {
      final db = await PosDatabase.instance.database;
      return db.update(
        'pending_orders',
        {'status': PendingOrderStatus.pending.name},
        where: 'branch_id = ? AND status = ?',
        whereArgs: [branchId, PendingOrderStatus.syncing.name],
      );
    } catch (e) {
      debugPrint('PendingOrderStore resetOrphanedSyncing failed: $e');
      return 0;
    }
  }

  static Future<List<PendingOrder>> getRecentOrders(
    int branchId, {
    int limit = 50,
  }) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final uuids = prefs.getStringList('$_webBranchList$branchId') ?? [];
        final list = <PendingOrder>[];
        for (final uuid in uuids) {
          final raw = prefs.getString('$_webOrderPrefix$uuid');
          if (raw != null) {
            list.add(PendingOrder.fromRow(jsonDecode(raw) as Map<String, dynamic>));
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list.take(limit).toList();
      } catch (_) {
        return [];
      }
    }

    try {
      final db = await PosDatabase.instance.database;
      final results = await db.query(
        'pending_orders',
        where: 'branch_id = ?',
        whereArgs: [branchId],
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return results.map(PendingOrder.fromRow).toList();
    } catch (e) {
      debugPrint('PendingOrderStore getRecentOrders failed: $e');
      return [];
    }
  }

  static Future<PendingOrder?> getByUuid(String localUuid) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$_webOrderPrefix$localUuid');
        if (raw == null) return null;
        return PendingOrder.fromRow(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }

    try {
      final db = await PosDatabase.instance.database;
      final results = await db.query(
        'pending_orders',
        where: 'local_uuid = ?',
        whereArgs: [localUuid],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return PendingOrder.fromRow(results.first);
    } catch (e) {
      debugPrint('PendingOrderStore getByUuid failed: $e');
      return null;
    }
  }

  static Future<void> markSyncing(String localUuid) async {
    if (kIsWeb) {
      final existing = await getByUuid(localUuid);
      if (existing != null) {
        final updated = existing.copyWith(status: PendingOrderStatus.syncing);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_webOrderPrefix$localUuid',
          jsonEncode(updated.toRow()),
        );
      }
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.update(
        'pending_orders',
        {'status': PendingOrderStatus.syncing.name},
        where: 'local_uuid = ?',
        whereArgs: [localUuid],
      );
    } catch (e) {
      debugPrint('PendingOrderStore markSyncing failed: $e');
    }
  }

  static Future<void> markPending(
    String localUuid, {
    String? errorMessage,
  }) async {
    if (kIsWeb) {
      final existing = await getByUuid(localUuid);
      if (existing != null) {
        final updated = existing.copyWith(
          status: PendingOrderStatus.pending,
          errorMessage: errorMessage,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_webOrderPrefix$localUuid',
          jsonEncode(updated.toRow()),
        );
      }
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.update(
        'pending_orders',
        {
          'status': PendingOrderStatus.pending.name,
          'error_message': errorMessage,
        },
        where: 'local_uuid = ?',
        whereArgs: [localUuid],
      );
    } catch (e) {
      debugPrint('PendingOrderStore markPending failed: $e');
    }
  }

  static Future<void> markSynced({
    required String localUuid,
    required int serverOrderId,
    required String serverOrderNumber,
  }) async {
    if (kIsWeb) {
      final existing = await getByUuid(localUuid);
      if (existing != null) {
        final updated = existing.copyWith(
          status: PendingOrderStatus.synced,
          serverOrderId: serverOrderId,
          serverOrderNumber: serverOrderNumber,
          syncedAt: DateTime.now(),
          errorMessage: null,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_webOrderPrefix$localUuid',
          jsonEncode(updated.toRow()),
        );
      }
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.update(
        'pending_orders',
        {
          'status': PendingOrderStatus.synced.name,
          'server_order_id': serverOrderId,
          'server_order_number': serverOrderNumber,
          'synced_at': DateTime.now().millisecondsSinceEpoch,
          'error_message': null,
        },
        where: 'local_uuid = ?',
        whereArgs: [localUuid],
      );
    } catch (e) {
      debugPrint('PendingOrderStore markSynced failed: $e');
    }
  }

  static Future<void> markFailed({
    required String localUuid,
    required String errorMessage,
  }) async {
    if (kIsWeb) {
      final existing = await getByUuid(localUuid);
      if (existing != null) {
        final updated = existing.copyWith(
          status: PendingOrderStatus.failed,
          retryCount: existing.retryCount + 1,
          errorMessage: errorMessage,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_webOrderPrefix$localUuid',
          jsonEncode(updated.toRow()),
        );
      }
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      final existing = await getByUuid(localUuid);
      if (existing == null) return;

      await db.update(
        'pending_orders',
        {
          'status': PendingOrderStatus.failed.name,
          'retry_count': existing.retryCount + 1,
          'error_message': errorMessage,
        },
        where: 'local_uuid = ?',
        whereArgs: [localUuid],
      );
    } catch (e) {
      debugPrint('PendingOrderStore markFailed failed: $e');
    }
  }

  static Future<void> markPrinted(String localUuid) async {
    if (kIsWeb) {
      final existing = await getByUuid(localUuid);
      if (existing != null) {
        final updated = existing.copyWith(printedAt: DateTime.now());
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_webOrderPrefix$localUuid',
          jsonEncode(updated.toRow()),
        );
      }
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.update(
        'pending_orders',
        {'printed_at': DateTime.now().millisecondsSinceEpoch},
        where: 'local_uuid = ?',
        whereArgs: [localUuid],
      );
    } catch (e) {
      debugPrint('PendingOrderStore markPrinted failed: $e');
    }
  }

  static Future<int> getPendingCount(int branchId) async {
    if (kIsWeb) {
      final list = await getPendingOrders(branchId);
      return list.length;
    }

    try {
      final db = await PosDatabase.instance.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM pending_orders WHERE branch_id = ? AND status IN (?, ?, ?)',
        [
          branchId,
          PendingOrderStatus.pending.name,
          PendingOrderStatus.failed.name,
          PendingOrderStatus.syncing.name,
        ],
      );
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('PendingOrderStore getPendingCount failed: $e');
      return 0;
    }
  }

  static Future<int> getFailedCount(int branchId) async {
    if (kIsWeb) {
      final all = await getRecentOrders(branchId, limit: 1000);
      return all.where((o) => o.status == PendingOrderStatus.failed).length;
    }

    try {
      final db = await PosDatabase.instance.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM pending_orders WHERE branch_id = ? AND status = ?',
        [branchId, PendingOrderStatus.failed.name],
      );
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('PendingOrderStore getFailedCount failed: $e');
      return 0;
    }
  }

  static Future<String?> getLatestError(int branchId) async {
    if (kIsWeb) {
      final all = await getRecentOrders(branchId, limit: 100);
      for (final order in all) {
        if (order.status == PendingOrderStatus.failed &&
            order.errorMessage != null &&
            order.errorMessage!.trim().isNotEmpty) {
          return order.errorMessage;
        }
      }
      return null;
    }

    try {
      final db = await PosDatabase.instance.database;
      final results = await db.query(
        'pending_orders',
        columns: ['error_message'],
        where: 'branch_id = ? AND status = ? AND error_message IS NOT NULL',
        whereArgs: [branchId, PendingOrderStatus.failed.name],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (results.isEmpty) return null;
      final message = results.first['error_message'] as String?;
      if (message == null || message.trim().isNotEmpty == false) return null;
      return message;
    } catch (e) {
      debugPrint('PendingOrderStore getLatestError failed: $e');
      return null;
    }
  }

  static Future<void> deleteOldSyncedOrders({int daysOld = 7}) async {
    if (kIsWeb) {
      // In-memory / shared prefs: no bulk purge needed for small web sessions.
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      final cutoff = DateTime.now()
          .subtract(Duration(days: daysOld))
          .millisecondsSinceEpoch;

      await db.delete(
        'pending_orders',
        where: 'status = ? AND synced_at < ?',
        whereArgs: [PendingOrderStatus.synced.name, cutoff],
      );
    } catch (e) {
      debugPrint('PendingOrderStore deleteOldSyncedOrders failed: $e');
    }
  }
}
