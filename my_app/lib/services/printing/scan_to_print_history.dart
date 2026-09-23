import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _historyKey = 'pos_scan_to_print_history';
const _maxEntries = 500;

/// Device-local record of order QRs that already printed a customer receipt.
class ScanToPrintHistory {
  ScanToPrintHistory._();

  static String keyFor({
    required int branchId,
    required String orderNumber,
  }) {
    return '$branchId:${orderNumber.trim().toUpperCase()}';
  }

  static Future<bool> hasPrinted({
    required int branchId,
    required String orderNumber,
  }) async {
    final needle = keyFor(branchId: branchId, orderNumber: orderNumber);
    if (needle.endsWith(':')) return false;
    final history = await _read();
    return history.contains(needle);
  }

  static Future<void> markPrinted({
    required int branchId,
    required String orderNumber,
  }) async {
    final needle = keyFor(branchId: branchId, orderNumber: orderNumber);
    if (needle.endsWith(':')) return;
    final history = await _read();
    if (!history.add(needle)) return;
    await _write(history);
  }

  static Future<Set<String>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final values = jsonDecode(raw);
      if (values is! List) return <String>{};
      return values.map((value) => value.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> _write(Set<String> history) async {
    var list = history.toList()..sort();
    if (list.length > _maxEntries) {
      list = list.sublist(list.length - _maxEntries);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(list));
  }
}
