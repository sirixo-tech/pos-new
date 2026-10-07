import 'dart:async';
import 'dart:io' show Directory, File, Process;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cart taps, new-order alerts, and kitchen chimes.
class PosCartSound {
  PosCartSound._();

  static final PosCartSound instance = PosCartSound._();

  static const orderTones = <String, String>{
    'new_order': 'Kitchen Bell (Default)',
    'modern_chime': 'Modern Studio Chime',
    'marimba': 'Warm Marimba',
    'success_ping': 'Success Ping',
    'bell': 'Classic Reception Bell',
    'ready': 'Pickup Arpeggio',
    'accept': 'Short Beep',
  };

  static const clickTones = <String, String>{
    'pos-beep': 'Crisp Click (Default)',
    'soft_tap': 'Soft Bubble Pop',
    'haptic_tick': 'Haptic Micro-Tick',
    'accept': 'Confirm Pulse',
    'bell': 'Classic Ding',
  };

  static const _clickEnabledKey = 'pos_click_sound_enabled';
  static const _orderEnabledKey = 'pos_order_placed_sound_enabled';
  static const _kitchenEnabledKey = 'pos_kitchen_sound_enabled';
  static const _clickToneKey = 'pos_click_tone';
  static const _orderToneKey = 'pos_order_placed_tone';
  static const _kitchenToneKey = 'pos_kitchen_tone';

  static const _soundChannels = <MethodChannel>[
    MethodChannel('pos_main/device_sound'),
    MethodChannel('selfx_pos/device_sound'),
  ];

  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final Map<String, String> _extractedPaths = {};
  bool _contextReady = false;

  bool clickEnabled = true;
  bool orderAlertEnabled = true;
  bool kitchenAlertEnabled = false;
  String clickTone = 'pos-beep';
  String orderTone = 'new_order';
  String kitchenTone = 'new_order';
  bool _loaded = false;
  bool _warming = false;

  DateTime _lastCart = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAlert = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> loadSettings() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    clickEnabled = prefs.getBool(_clickEnabledKey) ?? true;
    orderAlertEnabled = prefs.getBool(_orderEnabledKey) ?? true;
    kitchenAlertEnabled = prefs.getBool(_kitchenEnabledKey) ?? false;
    clickTone = prefs.getString(_clickToneKey) ?? 'pos-beep';
    orderTone = prefs.getString(_orderToneKey) ?? 'new_order';
    kitchenTone = prefs.getString(_kitchenToneKey) ?? 'new_order';
    _loaded = true;
  }

  Future<void> warmUp() async {
    await loadSettings();
    await _ensureAudioContext();
    if (_warming || kIsWeb) return;
    _warming = true;
    try {
      for (final tone in {...orderTones.keys, ...clickTones.keys}) {
        await _extractTone(tone);
      }
    } finally {
      _warming = false;
    }
  }

  Future<void> setClickEnabled(bool value) async {
    clickEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clickEnabledKey, value);
  }

  Future<void> setOrderAlertEnabled(bool value) async {
    orderAlertEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_orderEnabledKey, value);
  }

  Future<void> setKitchenAlertEnabled(bool value) async {
    kitchenAlertEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kitchenEnabledKey, value);
  }

  Future<void> setClickTone(String tone) async {
    clickTone = tone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clickToneKey, tone);
  }

  Future<void> setOrderTone(String tone) async {
    orderTone = tone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_orderToneKey, tone);
  }

  Future<void> setKitchenTone(String tone) async {
    kitchenTone = tone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kitchenToneKey, tone);
  }

  Future<void> playPreview(String tone) => _playTone(tone, volume: 1.0);

  Future<void> playAddToCart() async {
    await loadSettings();
    if (!clickEnabled) return;
    final now = DateTime.now();
    if (now.difference(_lastCart).inMilliseconds < 80) return;
    _lastCart = now;
    await _playTone(clickTone, volume: 0.55);
  }

  Future<void> playNewOrderAlert() async {
    await loadSettings();
    if (!orderAlertEnabled) return;
    if (!_throttleAlert()) return;
    final ok = await _playTone(orderTone, volume: 1.0);
    if (!ok) {
      await _playTone('pos-beep', volume: 0.9);
    }
  }

  Future<void> playMarketplaceOrderAlert() async {
    await loadSettings();
    if (!orderAlertEnabled) return;
    if (!_throttleAlert()) return;
    final ok = await _playTone('ready', volume: 1.0);
    if (ok) return;
    await _playTone(orderTone, volume: 1.0);
  }

  Future<void> playKitchenNewOrder() async {
    await loadSettings();
    if (!kitchenAlertEnabled) return;
    if (!_throttleAlert()) return;
    await _playTone(kitchenTone, volume: 1.0);
  }

  bool _throttleAlert() {
    final now = DateTime.now();
    if (now.difference(_lastAlert).inMilliseconds < 1200) return false;
    _lastAlert = now;
    return true;
  }

  Future<void> _ensureAudioContext() async {
    if (_contextReady) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('PosCartSound context: $e');
    }
    _contextReady = true;
  }

  Future<ByteData?> _loadAsset(String tone) async {
    for (final path in ['assets/audio/$tone.wav', 'audio/$tone.wav']) {
      try {
        return await rootBundle.load(path);
      } catch (_) {}
    }
    return null;
  }

  Future<Uint8List> _wavBytes(String tone) async {
    final data = await _loadAsset(tone);
    if (data != null) {
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    return _synthesizeWav(tone);
  }

  Future<String?> _extractTone(String tone) async {
    if (kIsWeb) return null;
    final cached = _extractedPaths[tone];
    if (cached != null && File(cached).existsSync()) return cached;

    final bytes = await _wavBytes(tone);
    final file = File('${Directory.systemTemp.path}/pos_main_$tone.wav');
    await file.writeAsBytes(bytes, flush: true);
    _extractedPaths[tone] = file.path;
    return file.path;
  }

  Future<bool> _playTone(String tone, {required double volume}) async {
    try {
      await _ensureAudioContext();

      if (await _playNativeChannel(tone)) return true;

      if (!kIsWeb) {
        final path = await _extractTone(tone);
        if (path != null && await _playOsPlayer(path)) {
          return true;
        }
        if (path != null && await _playDeviceFile(path, volume)) {
          return true;
        }
      }

      final bytes = await _wavBytes(tone);
      if (await _playBytes(bytes, volume)) return true;

      await SystemSound.play(SystemSoundType.alert);
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('PosCartSound ($tone): $e');
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
      return false;
    }
  }

  Future<bool> _playNativeChannel(String tone) async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    for (final channel in _soundChannels) {
      try {
        final result = await channel.invokeMethod<dynamic>('playTone', {
          'tone': tone,
        });
        if (result == true || result == 1 || result == 'ok') return true;
      } on MissingPluginException {
        continue;
      } catch (e) {
        if (kDebugMode) debugPrint('PosCartSound channel: $e');
      }
    }
    return false;
  }

  Future<bool> _playOsPlayer(String path) async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS:
          final result = await Process.run('/usr/bin/afplay', [
            '-v',
            '1',
            path,
          ]);
          return result.exitCode == 0;
        case TargetPlatform.windows:
          final normalized = path.replaceAll('/', r'\');
          final result = await Process.run('powershell', [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "(New-Object Media.SoundPlayer '$normalized').PlaySync()",
          ]);
          return result.exitCode == 0;
        case TargetPlatform.linux:
          final paplay = await Process.run('paplay', [path]);
          if (paplay.exitCode == 0) return true;
          final aplay = await Process.run('aplay', [path]);
          return aplay.exitCode == 0;
        default:
          return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PosCartSound native: $e');
      return false;
    }
  }

  Future<bool> _playDeviceFile(String path, double volume) async {
    try {
      await _player.stop();
      await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.play(DeviceFileSource(path));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('PosCartSound file: $e');
      return false;
    }
  }

  Future<bool> _playBytes(Uint8List bytes, double volume) async {
    try {
      await _player.stop();
      await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('PosCartSound bytes: $e');
      return false;
    }
  }

  Uint8List _synthesizeWav(String tone) {
    const sampleRate = 22050;
    final spec = switch (tone) {
      'modern_chime' => (freqs: [523.0, 784.0, 1046.0], dur: 0.42, decay: 3.2),
      'marimba' => (freqs: [392.0, 494.0, 587.0], dur: 0.38, decay: 6.0),
      'success_ping' => (freqs: [988.0, 1318.0], dur: 0.28, decay: 5.0),
      'bell' => (freqs: [830.0, 1661.0], dur: 0.5, decay: 2.4),
      'ready' => (freqs: [523.0, 659.0, 784.0, 1046.0], dur: 0.48, decay: 3.0),
      'accept' => (freqs: [880.0], dur: 0.12, decay: 10.0),
      'pos-beep' => (freqs: [1400.0, 2100.0], dur: 0.07, decay: 16.0),
      'soft_tap' => (freqs: [620.0], dur: 0.05, decay: 20.0),
      'haptic_tick' => (freqs: [1900.0], dur: 0.04, decay: 28.0),
      _ => (freqs: [880.0, 1174.0, 1568.0], dur: 0.45, decay: 2.8),
    };
    final n = (sampleRate * spec.dur).round();
    final pcm = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var sample = 0.0;
      for (var j = 0; j < spec.freqs.length; j++) {
        sample += math.sin(2 * math.pi * spec.freqs[j] * t) * math.pow(0.7, j);
      }
      sample /= spec.freqs.length;
      final attack = math.min(1.0, t / 0.012);
      final remain = spec.dur - t;
      final release = remain > 0.06 ? 1.0 : math.max(0.0, remain / 0.06);
      sample *= math.exp(-spec.decay * t) * attack * release * 0.72;
      pcm[i] = (sample * 32767).round().clamp(-32767, 32767);
    }
    return _wrapWav(pcm, sampleRate);
  }

  Uint8List _wrapWav(Int16List pcm, int sampleRate) {
    final dataSize = pcm.length * 2;
    final bytes = ByteData(44 + dataSize);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);
    var offset = 44;
    for (final sample in pcm) {
      bytes.setInt16(offset, sample, Endian.little);
      offset += 2;
    }
    return bytes.buffer.asUint8List();
  }

  void dispose() {
    _player.dispose();
  }
}
