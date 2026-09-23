import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus {
  online,
  offline,
  checking,
}

class ConnectivityService extends ChangeNotifier {
  ConnectivityService({this.serverUrl});

  String? serverUrl;
  ConnectionStatus _status = ConnectionStatus.checking;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _healthCheckTimer;
  bool _disposed = false;

  ConnectionStatus get status => _status;
  bool get isOnline => _status == ConnectionStatus.online;
  bool get isOffline => _status == ConnectionStatus.offline;

  Future<void> initialize() async {
    _subscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    await checkConnectivity();

    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkConnectivity(),
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (r) => r != ConnectivityResult.none,
    );

    if (hasConnection) {
      checkConnectivity();
    } else {
      _setStatus(ConnectionStatus.offline);
    }
  }

  Future<bool> checkConnectivity() async {
    if (_disposed) return false;

    final url = serverUrl;
    if (url == null || url.isEmpty) {
      _setStatus(ConnectionStatus.offline);
      return false;
    }

    try {
      final uri = Uri.parse('$url/api/v1/health');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('', 408),
      );

      final online = response.statusCode >= 200 && response.statusCode < 500;
      _setStatus(online ? ConnectionStatus.online : ConnectionStatus.offline);
      return online;
    } catch (_) {
      _setStatus(ConnectionStatus.offline);
      return false;
    }
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
