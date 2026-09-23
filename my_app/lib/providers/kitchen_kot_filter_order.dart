import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/kitchen_board.dart';

/// Persisted KOT channel-chip order (SharedPreferences, same keys as Selfx).
class KitchenKotFilterOrder extends ChangeNotifier {
  KitchenKotFilterOrder();

  static const _storageKey = 'kot_channel_filters_order';

  List<String> _keys = List<String>.from(kitchenKotFilterKeys);
  bool _loaded = false;

  List<String> get keys => List<String>.unmodifiable(_keys);

  List<String> visibleKeys({required bool allowDelivery}) {
    if (allowDelivery) return keys;
    return _keys.where((key) => key != 'delivery').toList();
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey);
    _keys = _normalize(stored);
    _loaded = true;
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final next = List<String>.from(_keys);
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    _keys = next;
    notifyListeners();
    await _persist();
  }

  Future<void> resetToDefault() async {
    _keys = List<String>.from(kitchenKotFilterKeys);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _keys);
  }

  List<String> _normalize(List<String>? stored) {
    if (stored == null || stored.isEmpty) {
      return List<String>.from(kitchenKotFilterKeys);
    }
    final allowed = kitchenKotFilterKeys.toSet();
    final seen = <String>{};
    final next = <String>[];
    for (final key in stored) {
      if (!allowed.contains(key) || seen.contains(key)) continue;
      seen.add(key);
      next.add(key);
    }
    for (final key in kitchenKotFilterKeys) {
      if (seen.contains(key)) continue;
      next.add(key);
    }
    return next;
  }
}
