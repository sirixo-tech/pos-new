import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local POS PIN verifier for offline unlock.
///
/// Stores a salted SHA-256 hash (never the raw PIN), scoped per staff user id.
/// Writes to secure storage and SharedPreferences so unlock still works if
/// keychain access is slow/unavailable (common on sandboxed macOS builds).
class PosLocalPinStorage {
  PosLocalPinStorage._();

  static FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final _random = Random.secure();

  /// Test-only: swap the secure storage backend.
  static void debugSetStorage(FlutterSecureStorage storage) {
    _storage = storage;
  }

  static void debugResetStorage() {
    _storage = const FlutterSecureStorage();
  }

  static String _key(int userId) => 'pos_local_pin_v1_$userId';

  static Future<void> savePin({
    required int userId,
    required String pin,
  }) async {
    final saltBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final hash = hashPin(salt: salt, pin: pin);
    final value = '$salt:$hash';
    final key = _key(userId);

    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Prefs fallback below.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<bool> hasPin(int userId) async {
    final value = await _read(userId);
    return value != null && value.contains(':');
  }

  static Future<bool> verifyPin({
    required int userId,
    required String pin,
  }) async {
    final value = await _read(userId);
    if (value == null) return false;
    final parts = value.split(':');
    if (parts.length != 2) return false;
    final salt = parts[0];
    final expected = parts[1];
    final actual = hashPin(salt: salt, pin: pin);
    return constantTimeEquals(expected, actual);
  }

  static Future<void> clear(int userId) async {
    final key = _key(userId);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<String?> _read(int userId) async {
    final key = _key(userId);
    try {
      final secure = await _storage.read(key: key).timeout(
            const Duration(milliseconds: 800),
          );
      if (secure != null && secure.contains(':')) {
        return secure;
      }
    } catch (_) {
      // Fall through to prefs.
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static String hashPin({required String salt, required String pin}) {
    final digest = sha256.convert(utf8.encode('$salt:$pin'));
    return digest.toString();
  }

  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
