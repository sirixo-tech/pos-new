import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pos_models.dart';

class PosStorage {
  PosStorage({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  static const _serverUrlKey = 'pos_server_url';
  static const _sessionKey = 'pos_session';
  static const _localeKey = 'pos_locale_code';
  static const _themeModeKey = 'pos_theme_mode';
  static const _autoLockEnabledKey = 'pos_auto_lock_enabled';
  static const _moreHiddenKey = 'pos_more_hidden_options';
  static const _moreExpandedKey = 'pos_more_expanded_sections';

  static Set<String> _moreHidden = {};
  static bool _moreHiddenLoaded = false;

  final FlutterSecureStorage _secure;

  Future<String?> getLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey);
  }

  Future<void> saveLocaleCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code.trim().toLowerCase());
  }

  Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey);
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.trim().toLowerCase());
  }

  /// Off unless the cashier explicitly enabled it (matches Selfx).
  Future<bool> getAutoLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoLockEnabledKey) ?? false;
  }

  Future<void> saveAutoLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLockEnabledKey, enabled);
  }

  Future<Set<String>> getMoreMenuHiddenIds() async {
    if (_moreHiddenLoaded) return Set<String>.from(_moreHidden);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_moreHiddenKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _moreHidden = decoded.map((e) => e.toString()).toSet();
        }
      } catch (_) {}
    }
    _moreHiddenLoaded = true;
    return Set<String>.from(_moreHidden);
  }

  Future<void> saveMoreMenuHiddenIds(Set<String> ids) async {
    _moreHidden = Set<String>.from(ids);
    _moreHiddenLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_moreHiddenKey, jsonEncode(_moreHidden.toList()));
  }

  /// Null until the cashier has opened or closed a heading.
  Future<Set<String>?> getMoreMenuExpandedTitles() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_moreExpandedKey)) return null;
    final raw = prefs.getString(_moreExpandedKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw);
      if (list is! List) return {};
      return list.map((item) => '$item').toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveMoreMenuExpandedTitles(Set<String> titles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_moreExpandedKey, jsonEncode(titles.toList()));
  }

  Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }

  Future<PosSession?> getSession() async {
    if (kIsWeb) {
      return _getSessionFromPrefs();
    }

    try {
      final raw = await _secure.read(key: _sessionKey);
      if (raw == null || raw.isEmpty) {
        return _getSessionFromPrefs();
      }
      return PosSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _getSessionFromPrefs();
    }
  }

  Future<void> saveSession(PosSession session) async {
    final encoded = jsonEncode(session.toJson());

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, encoded);
      return;
    }

    try {
      await _secure.write(key: _sessionKey, value: encoded);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, encoded);
    }
  }

  Future<void> clearSession() async {
    if (!kIsWeb) {
      try {
        await _secure.delete(key: _sessionKey);
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
    await clearSession();
  }

  Future<PosSession?> _getSessionFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    return PosSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
