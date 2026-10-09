import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef ScannerConnectionStatus = ({
  bool connected,
  int deviceCount,
  String message,
  bool hasHardwareKeyboard,
});

/// HID / iMin scanner presence for STATUS and scan-to-print.
class ScannerConnectionService extends ChangeNotifier
    with WidgetsBindingObserver {
  ScannerConnectionService() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _channels = [
    MethodChannel('pos_main/scanner_status'),
    MethodChannel('selfx_pos/scanner_status'),
  ];

  ScannerConnectionStatus _status = (
    connected: false,
    deviceCount: 0,
    message: 'Checking scanner connection…',
    hasHardwareKeyboard: false,
  );
  DateTime? _lastInputAt;
  Timer? _timer;
  bool _started = false;

  ScannerConnectionStatus get status => _status;
  DateTime? get lastInputAt => _lastInputAt;

  // Scan activity is telemetry, not evidence that a device is still attached.
  bool get connected => _status.connected;

  String get detail {
    if (connected) return 'Scanner connected.';
    return _status.message;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(refresh());
    });
  }

  void markInput() {
    _lastInputAt = DateTime.now();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    _status = await readScannerConnectionStatus();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static Future<ScannerConnectionStatus> readScannerConnectionStatus() async {
    for (final channel in _channels) {
      try {
        final result = await channel.invokeMapMethod<String, Object?>(
          'getStatus',
        );
        if (result == null) continue;
        final connected = result['connected'] == true;
        final hasHardwareKeyboard = result['hasHardwareKeyboard'] == true;
        final rawCount = result['deviceCount'];
        final count = rawCount is num
            ? rawCount.toInt()
            : int.tryParse(rawCount?.toString() ?? '') ?? 0;
        return (
          connected: connected,
          deviceCount: count,
          message:
              connected ? 'Scanner connected.' : 'Scanner is not connected.',
          hasHardwareKeyboard: hasHardwareKeyboard,
        );
      } on MissingPluginException {
        continue;
      } on PlatformException {
        return (
          connected: false,
          deviceCount: 0,
          message: 'Unable to check scanner connection.',
          hasHardwareKeyboard: false,
        );
      }
    }
    return (
      connected: false,
      deviceCount: 0,
      message: kIsWeb
          ? 'Scanner detection is not available in the browser.'
          : 'Scanner is not connected.',
      hasHardwareKeyboard: false,
    );
  }
}

Stream<String> iminScannerPayloads() {
  return Stream.multi((controller) {
    final subs = <StreamSubscription<dynamic>>[];
    for (final name in const [
      'pos_main/imin_scanner',
      'selfx_pos/imin_scanner',
    ]) {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        continue;
      }
      try {
        subs.add(
          EventChannel(name).receiveBroadcastStream().listen(
            (value) {
              if (value is String && value.trim().isNotEmpty) {
                controller.add(value);
              }
            },
            onError: (_) {},
          ),
        );
      } on MissingPluginException {
        // Keyboard-wedge scanning still works.
      }
    }
    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };
  });
}
