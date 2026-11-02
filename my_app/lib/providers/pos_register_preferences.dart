import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const posOrderTypes = ['dine_in', 'takeaway', 'delivery'];

/// Types still offered on this register.
///
/// [serverAllowed] is the web list. A type the web turned off stays off.
/// A type the cashier hides here is removed. One type always remains.
List<String> visiblePosOrderTypes({
  required List<String> serverAllowed,
  required bool dineIn,
  required bool takeaway,
  required bool delivery,
}) {
  final base = serverAllowed.isEmpty
      ? List<String>.from(posOrderTypes)
      : List<String>.from(serverAllowed);
  bool on(String type) => switch (type) {
    'dine_in' => dineIn,
    'takeaway' => takeaway,
    'delivery' => delivery,
    _ => true,
  };
  final visible = base.where(on).toList();
  if (visible.isNotEmpty) return visible;
  return [base.first];
}

/// This register's order-type visibility.
class PosRegisterPreferences extends ChangeNotifier {
  PosRegisterPreferences();

  static final PosRegisterPreferences instance = PosRegisterPreferences();
  static const orderTypeKey = 'pos_local_order_types';

  bool dineIn = true;
  bool takeaway = true;
  bool delivery = true;
  bool _loaded = false;

  bool isOrderTypeEnabled(String type) => switch (type) {
    'dine_in' => dineIn,
    'takeaway' => takeaway,
    'delivery' => delivery,
    _ => true,
  };

  List<String> visibleOrderTypes(List<String> serverAllowed) {
    return visiblePosOrderTypes(
      serverAllowed: serverAllowed,
      dineIn: dineIn,
      takeaway: takeaway,
      delivery: delivery,
    );
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(orderTypeKey);
    if (stored != null) {
      dineIn = stored.contains('dine_in');
      takeaway = stored.contains('takeaway');
      delivery = stored.contains('delivery');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setOrderTypeEnabled(String type, bool enabled) async {
    switch (type) {
      case 'dine_in':
        dineIn = enabled;
      case 'takeaway':
        takeaway = enabled;
      case 'delivery':
        delivery = enabled;
      default:
        return;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(orderTypeKey, [
      if (dineIn) 'dine_in',
      if (takeaway) 'takeaway',
      if (delivery) 'delivery',
    ]);
  }
}
