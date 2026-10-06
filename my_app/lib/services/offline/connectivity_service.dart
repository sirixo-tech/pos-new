import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus {
  online,
  offline,
  checking,
}

typedef ConnectivityProbe = Future<bool> Function(String serverUrl);

class ConnectivityService extends ChangeNotifier {
  ConnectivityService({this.serverUrl, ConnectivityProbe? probe})
    : _probe = probe ?? _probeHealth;

  String? serverUrl;
  final ConnectivityProbe _probe;
  ConnectionStatus _status = ConnectionStatus.checking;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _healthCheckTimer;
  bool _disposed = false;
  bool _backgrounded = false;
  int _failedProbes = 0;
  Future<bool>? _inFlight;

  ConnectionStatus get status => _status;
  bool get isOnline => _status == ConnectionStatus.online;
  bool get isOffline => _status == ConnectionStatus.offline;

  Future<void> initialize() async {
    _subscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    await checkConnectivity();

    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkConnectivity(),
    );
  }

  /// Screen-off and background must not paint the register offline.
  /// The caller checks the server again when the app is visible.
  void noteAppBackgrounded(bool backgrounded) {
    _backgrounded = backgrounded;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // Android often reports [none] when the screen turns off even though the
    // radio is still up. Confirm with the health probe instead of flipping
    // the register offline from that event.
    if (results.isEmpty && _disposed) return;
    unawaited(checkConnectivity());
  }

  Future<bool> checkConnectivity() {
    final current = _inFlight;
    if (current != null) return current;
    final run = _probeOnce();
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  Future<bool> _probeOnce() async {
    if (_disposed) return false;

    final url = serverUrl;
    if (url == null || url.isEmpty) {
      if (_backgrounded && _status == ConnectionStatus.online) return true;
      _setStatus(ConnectionStatus.offline);
      return false;
    }

    bool online;
    try {
      online = await _probe(url);
    } catch (_) {
      online = false;
    }
    if (_disposed) return false;

    if (online) {
      _failedProbes = 0;
      _setStatus(ConnectionStatus.online);
      return true;
    }

    if (_backgrounded && _status == ConnectionStatus.online) {
      return false;
    }

    _failedProbes++;
    if (_status == ConnectionStatus.online && _failedProbes < 2) {
      return false;
    }
    _setStatus(ConnectionStatus.offline);
    return false;
  }

  void _setStatus(ConnectionStatus newStatus) {
    if (_disposed) return;
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  void updateServerUrl(String? url) {
    serverUrl = url;
    checkConnectivity();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}

Future<bool> _probeHealth(String serverUrl) async {
  final uri = Uri.parse('$serverUrl/api/v1/health');
  final response = await http.get(uri).timeout(
    const Duration(seconds: 5),
    onTimeout: () => http.Response('', 408),
  );
  return response.statusCode >= 200 && response.statusCode < 500;
}
