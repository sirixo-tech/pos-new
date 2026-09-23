import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pos_models.dart';

/// Device-level binding from POS pairing (branch + terminal before staff login).
class PosDeviceBindingStorage {
  static const _key = 'pos_device_binding';

  static Future<PosDeviceBinding?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    return PosDeviceBinding.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> save(PosDeviceBinding binding) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(binding.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
