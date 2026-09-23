import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only POS category rail placement. Default is the left rail.
enum PosCategoryBarPlacement { left, top }

class PosCategoryBarSettings extends ChangeNotifier {
  PosCategoryBarSettings();

  static const _storageKey = 'pos_category_bar_placement';

  PosCategoryBarPlacement _placement = PosCategoryBarPlacement.left;
  bool _loaded = false;

  PosCategoryBarPlacement get placement => _placement;

  bool get isTop => _placement == PosCategoryBarPlacement.top;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _placement = raw == PosCategoryBarPlacement.top.name
        ? PosCategoryBarPlacement.top
        : PosCategoryBarPlacement.left;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setPlacement(PosCategoryBarPlacement next) async {
    if (_placement == next) return;
    _placement = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, next.name);
  }
}
