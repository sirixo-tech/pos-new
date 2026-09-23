import 'package:shared_preferences/shared_preferences.dart';

const _autoPrintKotOnNewOrderKey = 'pos_auto_print_kot_on_new_order';
const _clearHandoffOnScanPrintKey = 'pos_clear_handoff_on_scan_print';

/// Device preference for scan-to-print (first scan prints immediately).
class ScanToPrintSettings {
  ScanToPrintSettings._();

  /// When true (default), scan-to-print sends `handoff=1` so a ready KDS
  /// ticket is cleared after the customer receipt prints.
  static Future<bool> clearHandoffOnScanPrint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_clearHandoffOnScanPrintKey) ?? true;
  }

  static Future<void> setClearHandoffOnScanPrint(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clearHandoffOnScanPrintKey, value);
  }
}

/// Device preference: print KOT on this POS printer when a new guest / kiosk /
/// online / partner order arrives. Missing pref = on (first install).
class AutoPrintKotSettings {
  AutoPrintKotSettings._();

  static Future<bool> enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPrintKotOnNewOrderKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPrintKotOnNewOrderKey, value);
  }
}
