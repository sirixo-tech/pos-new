import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Immersive / window fullscreen for POS tablets and desktop registers.
class PosDisplayMode {
  PosDisplayMode._();

  static const _prefsKey = 'pos_fullscreen_enabled';

  static bool _enabled = true;
  static bool _desktopReady = false;

  static bool get enabled => _enabled;

  static bool get supportsDesktopFullscreen =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  static bool get supportsImmersiveUi =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// True when a fullscreen control should be shown in the UI.
  static bool get supportsToggle =>
      supportsDesktopFullscreen || supportsImmersiveUi;

  /// macOS native fullscreen (`toggleFullScreen`) leaves a frozen duplicate
  /// window behind the live one — use zoom/maximize instead.
  static bool get _usesNativeFullscreen =>
      supportsDesktopFullscreen && !Platform.isMacOS;

  static Future<void> initialize() async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKey) ?? true;

    if (supportsDesktopFullscreen) {
      await windowManager.ensureInitialized();
      final options = WindowOptions(
        minimumSize: const Size(1024, 700),
        size: Platform.isMacOS ? const Size(1280, 800) : null,
        center: true,
        titleBarStyle: TitleBarStyle.normal,
        fullScreen: false,
      );
      await windowManager.waitUntilReadyToShow(options);
      // Await these operations directly: the plugin's callback is a
      // VoidCallback, so async failures inside it would escape initialization.
      await windowManager.show();
      await windowManager.focus();
      _desktopReady = true;
      await apply();
      return;
    }

    await apply();
  }

  static Future<void> apply() async {
    if (kIsWeb) return;

    if (supportsImmersiveUi) {
      if (_enabled) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Color(0x00000000),
          systemNavigationBarColor: Color(0x00000000),
        ),
      );
    }

    if (supportsDesktopFullscreen && _desktopReady) {
      await _applyDesktopImmersive(_enabled);
    }
  }

  static Future<void> _applyDesktopImmersive(bool enabled) async {
    if (Platform.isMacOS) {
      if (!await windowManager.isVisible()) return;

      if (enabled) {
        // Avoid window_manager "Resize timed out" during first show.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!await windowManager.isMaximized()) {
          await windowManager.maximize();
        }
      } else if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      }
      return;
    }

    if (!_usesNativeFullscreen) return;

    final isFull = await windowManager.isFullScreen();
    if (isFull != enabled) {
      await windowManager.setFullScreen(enabled);
    }
  }

  static Future<void> setEnabled(bool value) async {
    if (kIsWeb) return;
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    await apply();
  }

  static Future<bool> toggle() async {
    await setEnabled(!_enabled);
    return _enabled;
  }
}
