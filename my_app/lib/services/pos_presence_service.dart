import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the Android process alive while the screen is off or the app is
/// in the background, so the register does not look offline after sleep.
class PosPresenceService {
  PosPresenceService._();

  static const _channel = MethodChannel('pos_main/presence');

  static Future<void> start() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('start');
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
