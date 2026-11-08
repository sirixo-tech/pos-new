import 'dart:async';
import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages device auto-start on boot or power on.
///
/// By default, auto-start is **ON (enabled)** so that unattended hardware
/// (e.g., 32" Token Display Android TV, KDS screens, and POS registers)
/// automatically recovers and opens the POS app when the device powers on
/// or restarts.
class PosAutoStart {
  PosAutoStart._();

  static const String prefsKey = 'pos_auto_start_enabled';
  static const MethodChannel _channel = MethodChannel('pos_main/auto_start');

  static bool _enabled = true;
  static bool _initialized = false;
  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(true);

  /// Current auto-start state. Defaults to `true`.
  static bool get isEnabled => _enabled;

  /// Whether auto-start has completed its initial preference load.
  static bool get isInitialized => _initialized;

  /// Initializes the auto-start setting.
  /// If no setting exists yet, sets it to `true` (ON by default).
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(prefsKey)) {
        await prefs.setBool(prefsKey, true);
        _enabled = true;
      } else {
        _enabled = prefs.getBool(prefsKey) ?? true;
      }
      notifier.value = _enabled;
      _initialized = true;
      await _syncNative(_enabled);
    } catch (e) {
      debugPrint('[PosAutoStart] Failed to initialize: $e');
    }
  }

  /// Sets whether the app should launch automatically on boot.
  static Future<bool> setEnabled(bool enabled) async {
    _enabled = enabled;
    notifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, enabled);
    } catch (e) {
      debugPrint('[PosAutoStart] Failed to save preference: $e');
    }
    await _syncNative(enabled);
    return _enabled;
  }

  /// Toggles the auto-start state.
  static Future<bool> toggle() => setEnabled(!_enabled);

  /// Synchronizes the auto-start configuration with native OS mechanisms.
  static Future<void> _syncNative(bool enabled) async {
    if (kIsWeb) return;

    // 1. Android native broadcast receiver & component setting
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod<bool>('setEnabled', {'enabled': enabled});
        return;
      }
    } catch (e) {
      debugPrint('[PosAutoStart] Android sync failed: $e');
    }

    // 2. Windows registry run key
    try {
      if (Platform.isWindows) {
        final exe = Platform.resolvedExecutable;
        if (exe.toLowerCase().endsWith('.exe')) {
          if (enabled) {
            await Process.run('reg', [
              'add',
              r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
              '/v',
              'SELFX POS',
              '/t',
              'REG_SZ',
              '/d',
              '"$exe"',
              '/f',
            ]);
          } else {
            await Process.run('reg', [
              'delete',
              r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
              '/v',
              'SELFX POS',
              '/f',
            ]);
            await Process.run('reg', [
              'delete',
              r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
              '/v',
              'SelfxPOS',
              '/f',
            ]);
          }
        }
      }
    } catch (e) {
      debugPrint('[PosAutoStart] Windows sync failed: $e');
    }
  }
}
