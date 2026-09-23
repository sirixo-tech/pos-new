import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/pos_l10n.dart';

/// Cashier-customizable cart quick-pay pills (order + show/hide).
class CartQuickPaySettings extends ChangeNotifier {
  CartQuickPaySettings();

  static const storageOrderKey = 'pos_cart_quick_pay_order';
  static const storageHiddenKey = 'pos_cart_quick_pay_hidden';

  static const allKeys = ['cash', 'upi', 'card', 'more'];
  static const chargeKeys = ['cash', 'upi', 'card'];

  List<String> _order = List<String>.from(allKeys);
  Set<String> _hidden = <String>{};
  bool _loaded = false;

  List<String> get orderedKeys => List<String>.unmodifiable(_order);

  List<String> get visibleKeys {
    final visible = _order.where((key) => !_hidden.contains(key)).toList();
    if (visible.any(chargeKeys.contains)) return visible;
    return ['cash', ...visible.where((key) => key != 'cash')];
  }

  bool isVisible(String key) => !_hidden.contains(key);

  bool canHide(String key) {
    if (!chargeKeys.contains(key)) return true;
    return chargeKeys.where((item) => !_hidden.contains(item)).length > 1;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _order = _normalizeOrder(prefs.getStringList(storageOrderKey));
    _hidden = _normalizeHidden(prefs.getStringList(storageHiddenKey));
    _loaded = true;
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final next = List<String>.from(_order);
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    _order = next;
    notifyListeners();
    await _persist();
  }

  Future<void> setVisible(String key, bool visible) async {
    if (visible) {
      _hidden.remove(key);
    } else {
      if (!canHide(key)) return;
      _hidden.add(key);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> resetToDefault() async {
    _order = List<String>.from(allKeys);
    _hidden = <String>{};
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(storageOrderKey, _order);
    await prefs.setStringList(storageHiddenKey, _hidden.toList());
  }

  List<String> _normalizeOrder(List<String>? stored) {
    final seen = <String>{};
    final next = <String>[];
    for (final key in stored ?? const <String>[]) {
      if (!allKeys.contains(key) || seen.contains(key)) continue;
      seen.add(key);
      next.add(key);
    }
    for (final key in allKeys) {
      if (seen.contains(key)) continue;
      next.add(key);
    }
    return next;
  }

  Set<String> _normalizeHidden(List<String>? stored) {
    final hidden = <String>{};
    for (final key in stored ?? const <String>[]) {
      if (allKeys.contains(key)) hidden.add(key);
    }
    if (!chargeKeys.any((key) => !hidden.contains(key))) {
      hidden.remove('cash');
    }
    return hidden;
  }

  static String labelFor(BuildContext context, String key) {
    return switch (key) {
      'cash' => context.posText('payCash', 'Cash'),
      'upi' => context.posText('payUpi', 'UPI'),
      'card' => context.posText('payCard', 'Card'),
      'more' => context.posText('payMore', 'More'),
      _ => key,
    };
  }

  static IconData iconFor(String key) {
    return switch (key) {
      'cash' => Icons.payments_rounded,
      'upi' => Icons.qr_code_2_rounded,
      'card' => Icons.credit_card_rounded,
      'more' => Icons.more_horiz_rounded,
      _ => Icons.payments_rounded,
    };
  }

  static String hintFor(String key) {
    return switch (key) {
      'cash' => 'Tender & change',
      'upi' => 'QR / UPI collect',
      'card' => 'Card terminal',
      'more' => 'Wallet, voucher, pay later',
      _ => '',
    };
  }
}
