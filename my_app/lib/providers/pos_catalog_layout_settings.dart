import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local register layout for menu photos. Does not change menu data.
enum PosCatalogLayout {
  images,
  colorCards,
  categoryImages,
  denseColor,
}

class PosCatalogLayoutSettings extends ChangeNotifier {
  PosCatalogLayoutSettings();

  static const _storageKey = 'pos_catalog_layout';

  PosCatalogLayout _layout = PosCatalogLayout.images;
  bool _loaded = false;

  PosCatalogLayout get layout => _layout;

  bool get showsItemImages => _layout == PosCatalogLayout.images;

  bool get showsCategoryImages =>
      _layout != PosCatalogLayout.colorCards &&
      _layout != PosCatalogLayout.denseColor;

  /// Color tiles with no initials circle and a shorter card.
  bool get denseColorCards => _layout == PosCatalogLayout.denseColor;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _layout = PosCatalogLayout.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => PosCatalogLayout.images,
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLayout(PosCatalogLayout next) async {
    if (_layout == next) return;
    _layout = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, next.name);
  }
}
