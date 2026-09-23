import 'package:shared_preferences/shared_preferences.dart';

/// Staff work mode on this device: register, waiter/captain, or kitchen KOT view.
enum PosWorkMode {
  register,
  waiter,
  kitchen,
}

/// Persists work mode per branch (mirrors terminal code storage).
class PosWorkModeStorage {
  static String _key(int branchId) => 'serve_pos_work_mode_$branchId';

  static Future<PosWorkMode?> read(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(branchId))?.trim().toLowerCase();
    return switch (raw) {
      'register' => PosWorkMode.register,
      'waiter' => PosWorkMode.waiter,
      'kitchen' => PosWorkMode.kitchen,
      _ => null,
    };
  }

  static Future<void> write(int branchId, PosWorkMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      PosWorkMode.waiter => 'waiter',
      PosWorkMode.kitchen => 'kitchen',
      PosWorkMode.register => 'register',
    };
    await prefs.setString(_key(branchId), value);
  }

  static Future<void> clear(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(branchId));
  }
}
