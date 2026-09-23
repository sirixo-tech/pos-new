import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the register POS kitchen dock panel is open per branch.
class KitchenDockStorage {
  KitchenDockStorage._();

  static String _key(int branchId) => 'serve_pos_kitchen_dock_open_$branchId';

  static Future<bool> readOpen(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(branchId)) ?? false;
  }

  static Future<void> persistOpen(int branchId, bool open) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(branchId), open);
  }
}
