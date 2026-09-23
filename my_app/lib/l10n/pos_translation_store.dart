import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';
import 'app_localizations_remote.dart';

/// In-memory (+ optional disk) catalogs downloaded from POS bootstrap.
class PosTranslationStore {
  PosTranslationStore._();

  static final PosTranslationStore instance = PosTranslationStore._();

  // Bump when server catalogs grow so stale offline caches are discarded.
  static const _prefsKey = 'pos_language_catalogs_v2';

  Map<String, Map<String, String>> _catalogs = {};
  int generation = 0;
  bool _networkApplied = false;

  /// Locale currently selected in the POS UI.
  String activeLocaleCode = 'en';

  Map<String, String>? catalogFor(String localeCode) {
    final code = _normalize(localeCode);
    if (code.isEmpty || code == 'en') return null;
    return _catalogs[code];
  }

  void setActiveLocale(String localeCode) {
    activeLocaleCode = _normalize(localeCode).isEmpty
        ? 'en'
        : _normalize(localeCode);
  }

  String text(
    String key,
    String fallback, {
    String? localeCode,
    Map<String, Object> replacements = const {},
  }) {
    final code = _normalize(localeCode ?? activeLocaleCode);
    var value = catalogFor(code)?[key];
    if (value == null || value.trim().isEmpty) {
      value = fallback;
    }
    return interpolate(value, replacements);
  }

  static String interpolate(
    String template, [
    Map<String, Object> replacements = const {},
  ]) {
    if (replacements.isEmpty) return template;
    var resolved = template;
    replacements.forEach((name, replacement) {
      resolved = resolved.replaceAll('{$name}', '$replacement');
    });
    return resolved;
  }

  void replaceCatalogs(Map<String, Map<String, String>> catalogs) {
    final next = <String, Map<String, String>>{};
    catalogs.forEach((code, strings) {
      final normalized = _normalize(code);
      if (normalized.isEmpty || normalized == 'en' || strings.isEmpty) return;
      next[normalized] = Map<String, String>.from(strings);
    });
    _catalogs = next;
    _networkApplied = true;
    generation++;
  }

  /// Drop in-memory + disk catalogs (e.g. after switching API hosts).
  Future<void> clear() async {
    _catalogs = {};
    _networkApplied = false;
    generation++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      // Legacy key from earlier builds.
      await prefs.remove('pos_language_catalogs_v1');
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> loadCached() async {
    // Bootstrap sync can finish while SharedPreferences is still loading.
    // Never clobber fresher in-memory / network catalogs with a stale disk read.
    if (_networkApplied || _catalogs.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      // Another await may have applied bootstrap catalogs while we were reading.
      if (_networkApplied || _catalogs.isNotEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final next = <String, Map<String, String>>{};
      decoded.forEach((key, value) {
        if (value is! Map) return;
        final code = key.toString().toLowerCase();
        if (code.isEmpty || code == 'en') return;
        final flat = <String, String>{};
        value.forEach((stringKey, stringValue) {
          if (stringKey == null || stringValue == null) return;
          flat[stringKey.toString()] = stringValue.toString();
        });
        if (flat.isNotEmpty) next[code] = flat;
      });
      if (next.isEmpty) return;
      if (_networkApplied || _catalogs.isNotEmpty) return;
      _catalogs = next;
      generation++;
    } catch (_) {
      // Ignore corrupt cache.
    }
  }

  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_catalogs));
    } catch (_) {
      // Best-effort offline cache.
    }
  }

  static String _normalize(String localeCode) =>
      localeCode.trim().toLowerCase();
}

/// Loads English from the local ARB backup; other locales from server catalogs.
class PosLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const PosLocalizationsDelegate(this.generation);

  final int generation;

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode.trim().isNotEmpty;
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    final code = locale.languageCode;
    if (code == 'en') {
      return SynchronousFuture<AppLocalizations>(AppLocalizationsEn());
    }

    final catalog = PosTranslationStore.instance.catalogFor(code) ?? const {};
    return SynchronousFuture<AppLocalizations>(
      AppLocalizationsRemote(catalog, locale: code),
    );
  }

  @override
  bool shouldReload(covariant PosLocalizationsDelegate old) {
    return old.generation != generation;
  }
}
