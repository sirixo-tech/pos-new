import 'package:shared_preferences/shared_preferences.dart';

const _autoPrintKotOnNewOrderKey = 'pos_auto_print_kot_on_new_order';
const _clearHandoffOnScanPrintKey = 'pos_clear_handoff_on_scan_print';
const _showKotFailurePopupKey = 'pos_show_kot_print_failed_popup';
const _printingEnabledKey = 'pos_printing_enabled';

/// Device-level preference for whether physical printing is active on this device.
///
/// When true (default), printing proceeds normally using configured printers.
/// When false (paperless mode), all background print jobs (receipts and KOTs)
/// are cleanly skipped with zero error popups, allowing restaurants with no printers
/// to operate purely digitally via KDS and Token Displays.
class PosPrintingSettings {
  PosPrintingSettings._();

  static bool _enabled = true;
  static bool get isEnabled => _enabled;
  static final List<void Function()> _listeners = [];

  static void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  static void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  static Future<bool> enabled() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_printingEnabledKey) ?? true;
    return _enabled;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_printingEnabledKey, value);
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }
}

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

/// Device preference for the KOT print-failed dialog. Missing pref = on,
/// so installs from before this switch keep the popup.
class KotFailurePopupSettings {
  KotFailurePopupSettings._();

  static final List<void Function()> _listeners = [];

  static void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  static void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  static Future<bool> enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showKotFailurePopupKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showKotFailurePopupKey, value);
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }
}
