import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pos_cart_sound.dart';

class CustomerVoiceService {
  CustomerVoiceService._();

  static final CustomerVoiceService instance = CustomerVoiceService._();

  static const _enabledKey = 'customer_voice_announcements_enabled';

  bool _isCustomerScreenActive = false;
  bool _isEnabled = true;
  bool _isProcessing = false;
  final List<String> _queue = [];

  bool get isEnabled => _isEnabled;
  bool get isCustomerScreenActive => _isCustomerScreenActive;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
    if (!value) _stopAndClear();
  }

  void setCustomerScreenActive(bool active) {
    _isCustomerScreenActive = active;
    if (!active) _stopAndClear();
  }

  void announceReadyToken(Object token) {
    final tokenStr = token.toString().trim();
    if (tokenStr.isEmpty) return;
    if (!_isCustomerScreenActive || !_isEnabled) return;
    if (_queue.contains(tokenStr)) return;
    _queue.add(tokenStr);
    unawaited(_processNext());
  }

  Future<void> testAnnouncement([String token = '1']) async {
    await PosCartSound.instance.playNewOrderAlert();
    debugPrint('[CustomerVoice] Test token $token');
  }

  Future<void> _processNext() async {
    if (_isProcessing ||
        !_isCustomerScreenActive ||
        !_isEnabled ||
        _queue.isEmpty) {
      return;
    }
    _isProcessing = true;
    final token = _queue.removeAt(0);
    try {
      await PosCartSound.instance.playNewOrderAlert();
      debugPrint('[CustomerVoice] Token $token');
      await Future<void>.delayed(const Duration(milliseconds: 1800));
    } catch (error) {
      debugPrint('[CustomerVoice] $error');
    }
    _isProcessing = false;
    if (_queue.isNotEmpty && _isCustomerScreenActive && _isEnabled) {
      await _processNext();
    }
  }

  void _stopAndClear() {
    _queue.clear();
    _isProcessing = false;
  }

  void dispose() => _stopAndClear();
}
