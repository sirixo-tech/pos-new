import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local “bill requested” flags per branch (maps UI billing to reserved/amber).
class PosBillRequestStorage {
  static String _key(int branchId) => 'serve_pos_bill_requested_$branchId';

  static Future<Set<int>> read(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(branchId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw);
      if (list is! List) return {};
      return list
          .map((e) => e is int ? e : int.tryParse('$e'))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> write(int branchId, Set<int> tableIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(branchId), jsonEncode(tableIds.toList()));
  }

  static Future<void> add(int branchId, int tableId) async {
    final ids = await read(branchId);
    if (ids.add(tableId)) {
      await write(branchId, ids);
    }
  }

  static Future<void> remove(int branchId, int tableId) async {
    final ids = await read(branchId);
    if (ids.remove(tableId)) {
      await write(branchId, ids);
    }
  }
}
