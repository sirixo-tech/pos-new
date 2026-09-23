import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../services/pos_storage.dart';

/// Persisted staff language preference for the POS UI chrome.
class PosLocaleController extends ChangeNotifier {
  PosLocaleController({PosStorage? storage})
      : _storage = storage ?? PosStorage();

  final PosStorage _storage;
  Locale _locale = PosLocales.en;
  bool _ready = false;
  bool _showSwitcher = false;
  List<Locale> _availableLocales = const [PosLocales.en];
  Map<String, String> _displayNames = const {};
  int _catalogGeneration = 0;

  Locale get locale => _locale;
  bool get ready => _ready;
  bool get showSwitcher => _showSwitcher;
  List<Locale> get availableLocales => _availableLocales;
  int get catalogGeneration => _catalogGeneration;

  String displayNameFor(Locale locale) {
    final fromRestaurant = _displayNames[locale.languageCode]?.trim();
    if (fromRestaurant != null && fromRestaurant.isNotEmpty) {
      return fromRestaurant;
    }
    return PosLocales.displayName(locale);
  }

  Future<void> load() async {
    await PosTranslationStore.instance.loadCached();
    _catalogGeneration = PosTranslationStore.instance.generation;
    final code = await _storage.getLocaleCode();
    _locale = _fromCode(code, _availableLocales);
    PosTranslationStore.instance.setActiveLocale(_locale.languageCode);
    _ready = true;
    notifyListeners();
  }

  /// Apply restaurant-configured languages + server catalogs from bootstrap.
  Future<void> syncFromBootstrap(PosBootstrap? bootstrap) async {
    if (bootstrap == null) {
      final changed = _showSwitcher ||
          _availableLocales.length != 1 ||
          _availableLocales.first.languageCode != 'en' ||
          _locale.languageCode != 'en';
      _showSwitcher = false;
      _availableLocales = const [PosLocales.en];
      _displayNames = const {};
      _locale = PosLocales.en;
      PosTranslationStore.instance.setActiveLocale('en');
      if (changed) notifyListeners();
      return;
    }

    PosTranslationStore.instance.replaceCatalogs(bootstrap.languageCatalogs);
    await PosTranslationStore.instance.persist();
    _catalogGeneration = PosTranslationStore.instance.generation;

    final mapped = <Locale>[];
    final names = <String, String>{};
    final seen = <String>{};

    for (final option in bootstrap.supportedLanguages) {
      if (!seen.add(option.code)) continue;
      Locale match = PosLocales.en;
      var found = false;
      for (final locale in PosLocales.all) {
        if (locale.languageCode == option.code) {
          match = locale;
          found = true;
          break;
        }
      }
      if (!found) {
        match = Locale(option.code);
      }
      mapped.add(match);
      final label = option.name.trim();
      if (label.isNotEmpty) {
        names[option.code] = label;
      }
    }

    final available =
        mapped.isEmpty ? const [PosLocales.en] : List<Locale>.from(mapped);
    final showSwitcher = available.length > 1 &&
        (bootstrap.showLanguageSwitcher ||
            bootstrap.supportedLanguages.length > 1);
    final savedCode = await _storage.getLocaleCode();
    final nextLocale = _fromCode(
      (savedCode != null && savedCode.trim().isNotEmpty)
          ? savedCode
          : available.first.languageCode,
      available,
    );

    _showSwitcher = showSwitcher;
    _availableLocales = available;
    _displayNames = names;
    _catalogGeneration = PosTranslationStore.instance.generation;

    if (nextLocale.languageCode != _locale.languageCode) {
      _locale = nextLocale;
      await _storage.saveLocaleCode(nextLocale.languageCode);
    }
    PosTranslationStore.instance.setActiveLocale(_locale.languageCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final next = PosLocales.resolve(locale, _availableLocales);
    if (next == _locale) return;
    _locale = next;
    PosTranslationStore.instance.setActiveLocale(next.languageCode);
    notifyListeners();
    await _storage.saveLocaleCode(next.languageCode);
  }

  static Locale _fromCode(String? code, List<Locale> available) {
    if (available.isEmpty) return PosLocales.en;
    if (code == null || code.isEmpty) return available.first;
    return PosLocales.resolve(Locale(code), available);
  }
}
