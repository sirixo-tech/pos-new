import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/waiter_alert.dart';

/// Persists captain notification inbox per branch (survives app restarts).
class PosWaiterAlertsStorage {
  static const _maxStored = 40;

  static String _key(int branchId) => 'serve_pos_waiter_alerts_$branchId';

  static Future<List<WaiterAlert>> read(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(branchId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => WaiterAlert.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.id.isNotEmpty)
          .take(_maxStored)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> write(int branchId, List<WaiterAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = alerts.take(_maxStored).map((a) => a.toJson()).toList();
    await prefs.setString(_key(branchId), jsonEncode(payload));
  }

  static Future<void> clear(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(branchId));
  }
}
