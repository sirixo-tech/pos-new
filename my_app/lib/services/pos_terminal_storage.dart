import 'package:shared_preferences/shared_preferences.dart';

/// Persists which POS terminal code this device uses per branch (mirrors web localStorage).
class PosTerminalStorage {
  static String _key(int branchId) => 'serve_pos_terminal_$branchId';

  static Future<String?> readTerminalCode(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(branchId));
  }

  static Future<void> writeTerminalCode(int branchId, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(branchId), code.trim().toUpperCase());
  }

  static Future<void> clearTerminalCode(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(branchId));
  }
}
