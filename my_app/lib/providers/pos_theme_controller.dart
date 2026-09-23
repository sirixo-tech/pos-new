import 'package:flutter/material.dart';

import '../services/pos_storage.dart';

/// Persisted appearance preference for the POS UI (system / light / dark).
class PosThemeController extends ChangeNotifier {
  PosThemeController({PosStorage? storage}) : _storage = storage ?? PosStorage();

  final PosStorage _storage;
  ThemeMode _mode = ThemeMode.light;
  bool _ready = false;

  ThemeMode get mode => _mode;
  bool get ready => _ready;

  Future<void> load() async {
    final raw = await _storage.getThemeMode();
    _mode = _parse(raw);
    _ready = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _storage.saveThemeMode(_serialize(mode));
  }

  static ThemeMode _parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String _serialize(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
