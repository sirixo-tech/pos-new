import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../offline/pos_database.dart';

class PendingPrintJob {
  const PendingPrintJob({
    required this.jobKey,
    required this.kind,
    required this.orderId,
    required this.orderNumber,
    this.source = '',
    this.cashier = false,
    this.status = 'pending',
    this.errorMessage,
    this.paperOut = false,
  });

  final String jobKey;
  final String kind;
  final int orderId;
  final String orderNumber;
  final String source;
  final bool cashier;
  final String status;
  final String? errorMessage;
  final bool paperOut;

  Map<String, dynamic> toRow() => {
        'job_key': jobKey,
        'kind': kind,
        'order_id': orderId,
        'order_number': orderNumber,
        'source': source,
        'cashier': cashier ? 1 : 0,
        'status': status,
        'error_message': errorMessage,
        'paper_out': paperOut ? 1 : 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

  static PendingPrintJob fromRow(Map<String, dynamic> row) {
    return PendingPrintJob(
      jobKey: row['job_key'] as String? ?? '',
      kind: row['kind'] as String? ?? 'kot',
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      orderNumber: row['order_number'] as String? ?? '',
      source: row['source'] as String? ?? '',
      cashier: row['cashier'] == 1 || row['cashier'] == true,
      status: row['status'] as String? ?? 'pending',
      errorMessage: row['error_message'] as String?,
      paperOut: row['paper_out'] == 1 || row['paper_out'] == true,
    );
  }
}

class PendingPrintJobStore {
  PendingPrintJobStore._();

  static const _webKey = 'pos_pending_print_jobs';
  static final Map<String, PendingPrintJob> _memory = {};

  static Future<void> upsert(PendingPrintJob job) async {
    if (kIsWeb) {
      _memory[job.jobKey] = job;
      await _persistWeb();
      return;
    }
    try {
      final db = await PosDatabase.instance.database;
      await db.insert(
        'pending_print_jobs',
        job.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('PendingPrintJobStore.upsert failed: $e');
      _memory[job.jobKey] = job;
    }
  }

  static Future<void> markDone(String jobKey) async {
    if (kIsWeb) {
      _memory.remove(jobKey);
      await _persistWeb();
      return;
    }
    try {
      final db = await PosDatabase.instance.database;
      await db.delete(
        'pending_print_jobs',
        where: 'job_key = ?',
        whereArgs: [jobKey],
      );
    } catch (e) {
      debugPrint('PendingPrintJobStore.markDone failed: $e');
      _memory.remove(jobKey);
    }
  }

  static Future<List<PendingPrintJob>> loadOpen() async {
    if (kIsWeb) {
      await _loadWeb();
      return _memory.values
          .where((j) => j.status == 'pending' || j.status == 'failed')
          .toList();
    }
    try {
      final db = await PosDatabase.instance.database;
      final rows = await db.query(
        'pending_print_jobs',
        where: 'status IN (?, ?)',
        whereArgs: const ['pending', 'failed'],
        orderBy: 'created_at ASC',
      );
      return rows.map(PendingPrintJob.fromRow).toList();
    } catch (e) {
      debugPrint('PendingPrintJobStore.loadOpen failed: $e');
      return _memory.values.toList();
    }
  }

  static Future<void> _loadWeb() async {
    if (_memory.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_webKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        if (item is! Map) continue;
        final job = PendingPrintJob.fromRow(Map<String, dynamic>.from(item));
        _memory[job.jobKey] = job;
      }
    } catch (_) {}
  }

  static Future<void> _persistWeb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _webKey,
        jsonEncode(_memory.values.map((j) => j.toRow()).toList()),
      );
    } catch (_) {}
  }
}
