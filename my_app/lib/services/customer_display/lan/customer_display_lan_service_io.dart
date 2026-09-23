import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'customer_display_protocol_v2.dart';
import 'customer_display_security_store.dart';
import 'models/customer_display_device.dart';

typedef CustomerDisplayConnection = ({
  String name,
  String address,
  String transport,
});

class CustomerDisplayLanService extends ChangeNotifier {
  CustomerDisplayLanService._();

  static final instance = CustomerDisplayLanService._();
  static const int _port = 8081;
  static const int _maximumAuthenticatedConnections = 2;
  static const int _maximumPendingConnections = 3;
  static const int _maximumPairedDevices = 8;
  static const int _maximumFailuresPerWindow = 5;
  static const Duration _authenticationTimeout = Duration(seconds: 10);
  static const Duration _idleTimeout = Duration(minutes: 10);
  static const Duration _heartbeatInterval = Duration(seconds: 20);
  static const Duration _failureWindow = Duration(minutes: 5);
  static const Duration _blockedDuration = Duration(minutes: 5);

  final CustomerDisplaySecurityStore _securityStore =
      CustomerDisplaySecurityStore();
  final Map<String, _SocketSession> _sessions = {};
  final Map<String, WebSocket> _sockets = {};
  final Map<String, CustomerDisplayDevice> _devices = {};
  final Map<String, _FailureState> _failures = {};
  Map<String, PairedDisplayCredential> _pairedCredentials = {};

  HttpServer? _server;
  Timer? _pairingRotationTimer;
  Timer? _maintenanceTimer;
  String? _selectedAddress;
  List<CustomerDisplayConnection> _connections = const [];
  String? _errorMessage;
  CustomerDisplayTlsMaterial? _tlsMaterial;
  String? _pairingToken;
  String? _pairingTokenHash;
  DateTime? _pairingExpiresAt;
  bool _pairingTokenConsumed = true;
  Map<String, Object?>? _lastDisplayMessage;
  Map<String, Object?> _branding = const {};
  int _sequence = 0;
  String? _activePaymentSessionId;

  bool get isRunning => _server != null;
  int get port => _port;
  String? get errorMessage => _errorMessage;
  String? get activePaymentSessionId => _activePaymentSessionId;
  String? get selectedAddress => _selectedAddress;
  List<CustomerDisplayConnection> get connections =>
      List.unmodifiable(_connections);
  List<CustomerDisplayDevice> get devices => List.unmodifiable(_devices.values);
  List<String> get connectionOptions => [
    for (final item in _connections)
      '${item.transport.toUpperCase()}  ${item.address} (${item.name})',
  ];

  String? get pairingData {
    final address = _selectedAddress;
    final tls = _tlsMaterial;
    final token = _pairingToken;
    final expiry = _pairingExpiresAt;
    if (_server == null ||
        address == null ||
        tls == null ||
        token == null ||
        expiry == null ||
        _pairingTokenConsumed ||
        !expiry.isAfter(DateTime.now().toUtc())) {
      return null;
    }
    final selected = _connections.where((item) => item.address == address);
    final connection = selected.isEmpty ? null : selected.first;
    return jsonEncode({
      'type': 'SELFX_CUSTOMER_DISPLAY',
      'version': customerDisplayProtocolVersion,
      'host': address,
      'port': _port,
      'transport': connection?.transport ?? 'lan',
      'pairingToken': token,
      'expiresAt': expiry.toIso8601String(),
      'certificateFingerprint': tls.fingerprint,
    });
  }

  Future<void> start() async {
    if ((!Platform.isWindows && !Platform.isAndroid) || _server != null) return;
    try {
      _tlsMaterial ??= await _securityStore.loadOrCreateTlsMaterial();
      _pairedCredentials = await _securityStore.loadPairedDevices();
      _connections = await _findLanAddresses();
      if (_connections.isEmpty) {
        throw const SocketException(
          'No private LAN, Wi-Fi, or USB tethering address found.',
        );
      }
      if (!_connections.any((item) => item.address == _selectedAddress)) {
        _selectedAddress = _connections.first.address;
      }
      final securityContext = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(_tlsMaterial!.certificatePem))
        ..usePrivateKeyBytes(utf8.encode(_tlsMaterial!.privateKeyPem));
      _server = await HttpServer.bindSecure(
        InternetAddress(_selectedAddress!),
        _port,
        securityContext,
        shared: false,
      );
      _issuePairingToken();
      _maintenanceTimer?.cancel();
      _maintenanceTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _performMaintenance(),
      );
      _errorMessage = null;
      unawaited(_server!.forEach(_handleRequest));
    } on Object catch (error) {
      _errorMessage = 'Could not start secure customer display server: $error';
      await _server?.close(force: true);
      _server = null;
    }
    notifyListeners();
  }

  Future<void> restart() async {
    await _stopServer();
    await start();
  }

  Future<void> refreshPairingCode() async {
    if (_server == null) await start();
    if (_server != null) {
      _issuePairingToken();
      notifyListeners();
    }
  }

  Future<void> selectConnection(String address) async {
    if (address == _selectedAddress) return;
    if (!_connections.any((item) => item.address == address)) {
      throw ArgumentError.value(
        address,
        'address',
        'Unknown network interface',
      );
    }
    _selectedAddress = address;
    await restart();
  }

  Future<void> _stopServer() async {
    _pairingRotationTimer?.cancel();
    _maintenanceTimer?.cancel();
    _pairingRotationTimer = null;
    _maintenanceTimer = null;
    await _server?.close(force: true);
    _server = null;
    for (final session in List<_SocketSession>.of(_sessions.values)) {
      await session.socket.close(WebSocketStatus.goingAway, 'Server restart');
      session.authenticationTimer?.cancel();
    }
    _sessions.clear();
    _sockets.clear();
    _devices.clear();
  }

  void _issuePairingToken() {
    final token = secureRandomBase64Url(bytes: 32);
    _pairingToken = token;
    _pairingTokenHash = sha256Base64Url(token);
    _pairingExpiresAt = DateTime.now().toUtc().add(
      customerDisplayPairingLifetime,
    );
    _pairingTokenConsumed = false;
    _pairingRotationTimer?.cancel();
    _pairingRotationTimer = Timer(customerDisplayPairingLifetime, () {
      if (_server == null || _pairingTokenConsumed) return;
      _issuePairingToken();
      notifyListeners();
    });
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final remoteAddress =
        request.connectionInfo?.remoteAddress.address ?? 'unknown';
    if (_isBlocked(remoteAddress)) {
      await _rejectRequest(request, HttpStatus.tooManyRequests);
      return;
    }
    if (request.uri.path != '/customer-display' ||
        request.uri.hasQuery ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      _recordFailure(remoteAddress);
      await _rejectRequest(request, HttpStatus.forbidden);
      return;
    }
    final pendingCount = _sessions.values
        .where((session) => !session.authenticated)
        .length;
    if (_sockets.length >= _maximumAuthenticatedConnections ||
        pendingCount >= _maximumPendingConnections) {
      await _rejectRequest(request, HttpStatus.serviceUnavailable);
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    final sessionId = secureRandomBase64Url(bytes: 18);
    final session = _SocketSession(
      id: sessionId,
      socket: socket,
      remoteAddress: remoteAddress,
      lastActivityAt: DateTime.now().toUtc(),
    );
    _sessions[sessionId] = session;
    session.authenticationTimer = Timer(_authenticationTimeout, () {
      if (!session.authenticated) {
        _recordFailure(remoteAddress);
        unawaited(_closeSession(session, 'Authentication timeout'));
      }
    });
    socket.listen(
      (data) => _handleSocketData(session, data),
      onDone: () => _removeSession(session),
      onError: (_) => _removeSession(session),
      cancelOnError: true,
    );
  }

  Future<void> _rejectRequest(HttpRequest request, int status) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.text;
    request.response.write('Secure customer display connection rejected.');
    await request.response.close();
  }

  Future<void> _handleSocketData(_SocketSession session, Object? data) async {
    if (data is! String ||
        utf8.encode(data).length > customerDisplayMaximumMessageBytes) {
      _recordFailure(session.remoteAddress);
      await _closeSession(session, 'Invalid message size');
      return;
    }
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) throw const FormatException();
      message = Map<String, dynamic>.from(decoded);
    } on FormatException {
      _recordFailure(session.remoteAddress);
      await _closeSession(session, 'Malformed message');
      return;
    }
    final validation = validateProtocolEnvelope(
      message,
      allowedTypes: customerDisplayClientMessageTypes,
      lastSequence: session.lastClientSequence,
    );
    if (validation != null) {
      _recordFailure(session.remoteAddress);
      await _closeSession(session, validation);
      return;
    }
    session.lastClientSequence = message['sequence'] as int;
    session.lastActivityAt = DateTime.now().toUtc();

    switch (message['type']) {
      case 'PAIR_REQUEST':
        await _handlePairRequest(session, message);
        return;
      case 'AUTH_HELLO':
        await _handleAuthHello(session, message);
        return;
      case 'AUTH_RESPONSE':
        await _handleAuthResponse(session, message);
        return;
      case 'PONG':
        if (!session.authenticated) {
          await _closeSession(session, 'Authentication required');
        }
        return;
    }
  }

  Future<void> _handlePairRequest(
    _SocketSession session,
    Map<String, dynamic> message,
  ) async {
    if (session.authenticated ||
        _pairingTokenConsumed ||
        _pairingExpiresAt == null ||
        !_pairingExpiresAt!.isAfter(DateTime.now().toUtc())) {
      await _authenticationFailed(session, 'Pairing code expired or used');
      return;
    }
    final suppliedToken = message['pairingToken']?.toString() ?? '';
    final suppliedHash = sha256Base64Url(suppliedToken);
    if (_pairingTokenHash == null ||
        !constantTimeStringEquals(suppliedHash, _pairingTokenHash!)) {
      await _authenticationFailed(session, 'Invalid pairing credential');
      return;
    }
    final deviceId = message['deviceId']?.toString().trim() ?? '';
    final deviceName = message['deviceName']?.toString().trim() ?? '';
    if (!_validIdentifier(deviceId) ||
        deviceName.isEmpty ||
        deviceName.length > 80) {
      await _authenticationFailed(session, 'Invalid device identity');
      return;
    }

    final secret = secureRandomBase64Url(bytes: 32);
    final credential = PairedDisplayCredential(
      deviceId: deviceId,
      deviceName: deviceName,
      secret: secret,
      pairedAt: DateTime.now().toUtc(),
    );
    if (!_pairedCredentials.containsKey(deviceId) &&
        _pairedCredentials.length >= _maximumPairedDevices) {
      final removable =
          _pairedCredentials.values
              .where((item) => !_sockets.containsKey(item.deviceId))
              .toList()
            ..sort((a, b) => a.pairedAt.compareTo(b.pairedAt));
      if (removable.isEmpty) {
        await _authenticationFailed(session, 'Paired-device limit reached');
        return;
      }
      _pairedCredentials.remove(removable.first.deviceId);
    }
    _pairedCredentials[deviceId] = credential;
    try {
      await _securityStore.savePairedDevices(_pairedCredentials);
    } on Object {
      _pairedCredentials.remove(deviceId);
      await _authenticationFailed(
        session,
        'Could not secure device credential',
      );
      return;
    }
    _pairingTokenConsumed = true;
    _pairingToken = null;
    _pairingTokenHash = null;
    _pairingRotationTimer?.cancel();
    _pairingRotationTimer = null;
    await _authenticateSession(session, credential);
    _send(session.socket, 'PAIR_ACCEPT', {
      'deviceId': deviceId,
      'deviceCredential': secret,
      'server': Platform.localHostname,
    });
    _sendCurrentDisplay(session.socket);
    notifyListeners();
  }

  Future<void> _handleAuthHello(
    _SocketSession session,
    Map<String, dynamic> message,
  ) async {
    if (session.authenticated || session.serverNonce != null) {
      await _authenticationFailed(session, 'Invalid authentication state');
      return;
    }
    final deviceId = message['deviceId']?.toString().trim() ?? '';
    final clientNonce = message['clientNonce']?.toString() ?? '';
    final credential = _pairedCredentials[deviceId];
    if (credential == null || !_validNonce(clientNonce)) {
      await _authenticationFailed(session, 'Unknown paired display');
      return;
    }
    session.deviceId = deviceId;
    session.clientNonce = clientNonce;
    session.serverNonce = secureRandomBase64Url(bytes: 32);
    session.challengeTimestamp = DateTime.now().toUtc().toIso8601String();
    _send(session.socket, 'AUTH_CHALLENGE', {
      'deviceId': deviceId,
      'clientNonce': clientNonce,
      'serverNonce': session.serverNonce,
      'challengeTimestamp': session.challengeTimestamp,
    });
  }

  Future<void> _handleAuthResponse(
    _SocketSession session,
    Map<String, dynamic> message,
  ) async {
    final deviceId = session.deviceId;
    final clientNonce = session.clientNonce;
    final serverNonce = session.serverNonce;
    final challengeTimestamp = session.challengeTimestamp;
    final credential = deviceId == null ? null : _pairedCredentials[deviceId];
    if (credential == null ||
        clientNonce == null ||
        serverNonce == null ||
        challengeTimestamp == null ||
        message['deviceId'] != deviceId ||
        message['clientNonce'] != clientNonce ||
        message['serverNonce'] != serverNonce ||
        message['challengeTimestamp'] != challengeTimestamp) {
      await _authenticationFailed(session, 'Invalid authentication challenge');
      return;
    }
    final expected = createDeviceAuthProof(
      secret: credential.secret,
      deviceId: deviceId!,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      challengeTimestamp: challengeTimestamp,
    );
    final supplied = message['proof']?.toString() ?? '';
    if (!constantTimeStringEquals(expected, supplied)) {
      await _authenticationFailed(session, 'Authentication proof rejected');
      return;
    }
    await _authenticateSession(session, credential);
    _send(session.socket, 'AUTH_OK', {
      'deviceId': deviceId,
      'server': Platform.localHostname,
    });
    _sendCurrentDisplay(session.socket);
  }

  Future<void> _authenticateSession(
    _SocketSession session,
    PairedDisplayCredential credential,
  ) async {
    final previous = _sockets[credential.deviceId];
    if (previous != null && previous != session.socket) {
      await previous.close(WebSocketStatus.policyViolation, 'Reconnected');
    }
    session.authenticationTimer?.cancel();
    session.authenticationTimer = null;
    session.authenticated = true;
    session.deviceId = credential.deviceId;
    _sockets[credential.deviceId] = session.socket;
    _devices[credential.deviceId] = CustomerDisplayDevice(
      id: credential.deviceId,
      name: credential.deviceName,
      address: session.remoteAddress,
      connectedAt: DateTime.now(),
    );
    _failures.remove(session.remoteAddress);
    notifyListeners();
  }

  Future<void> _authenticationFailed(
    _SocketSession session,
    String reason,
  ) async {
    _recordFailure(session.remoteAddress);
    _send(session.socket, 'AUTH_ERROR', {'message': 'Authentication failed.'});
    await _closeSession(session, reason);
  }

  void _performMaintenance() {
    final now = DateTime.now().toUtc();
    for (final session in List<_SocketSession>.of(_sessions.values)) {
      if (now.difference(session.lastActivityAt) > _idleTimeout) {
        unawaited(_closeSession(session, 'Idle timeout'));
        continue;
      }
      if (session.authenticated &&
          now.difference(session.lastHeartbeatAt) >= _heartbeatInterval) {
        session.lastHeartbeatAt = now;
        _send(session.socket, 'PING', const {});
      }
    }
    _failures.removeWhere((_, state) {
      final blockedUntil = state.blockedUntil;
      return blockedUntil != null && now.isAfter(blockedUntil);
    });
  }

  bool _isBlocked(String address) {
    final until = _failures[address]?.blockedUntil;
    return until != null && until.isAfter(DateTime.now().toUtc());
  }

  void _recordFailure(String address) {
    final now = DateTime.now().toUtc();
    final current = _failures[address];
    final withinWindow =
        current != null &&
        now.difference(current.windowStartedAt) <= _failureWindow;
    final count = withinWindow ? current.count + 1 : 1;
    _failures[address] = _FailureState(
      count: count,
      windowStartedAt: withinWindow ? current.windowStartedAt : now,
      blockedUntil: count >= _maximumFailuresPerWindow
          ? now.add(_blockedDuration)
          : null,
    );
  }

  void showQr({
    required String paymentSessionId,
    required String qrData,
    required String orderNumber,
    required double amount,
    String? merchant,
    int? timeoutSeconds,
    String? restaurantName,
    String? restaurantLogoUrl,
  }) {
    final displayTimeoutSeconds = (timeoutSeconds ?? 120).clamp(1, 900);
    _activePaymentSessionId = paymentSessionId;
    _branding = {
      if (restaurantName != null) 'restaurantName': restaurantName,
      if (restaurantLogoUrl != null) 'restaurantLogoUrl': restaurantLogoUrl,
    };
    _lastDisplayMessage = {
      'type': 'SHOW_QR',
      'paymentSessionId': paymentSessionId,
      'orderId': orderNumber,
      'amount': amount,
      'qrData': qrData,
      ..._branding,
      'timeoutSeconds': displayTimeoutSeconds,
      'expiresAt': DateTime.now()
          .add(Duration(seconds: displayTimeoutSeconds))
          .toUtc()
          .toIso8601String(),
      if (merchant != null) 'merchant': merchant,
    };
    _broadcastCurrentDisplay();
  }

  void paymentSuccess(String orderNumber, {required String paymentSessionId}) {
    _showTerminalState(
      type: 'PAYMENT_SUCCESS',
      orderNumber: orderNumber,
      paymentSessionId: paymentSessionId,
    );
  }

  void paymentFailed(String orderNumber, {required String paymentSessionId}) {
    _showTerminalState(
      type: 'PAYMENT_FAILED',
      orderNumber: orderNumber,
      paymentSessionId: paymentSessionId,
      releaseDisplay: true,
    );
  }

  void paymentExpired(String orderNumber, {required String paymentSessionId}) {
    _showTerminalState(
      type: 'PAYMENT_EXPIRED',
      orderNumber: orderNumber,
      paymentSessionId: paymentSessionId,
      releaseDisplay: true,
    );
  }

  void _showTerminalState({
    required String type,
    required String orderNumber,
    required String paymentSessionId,
    bool releaseDisplay = false,
  }) {
    if (_activePaymentSessionId != paymentSessionId) return;
    final previous = _lastDisplayMessage;
    if (releaseDisplay) _activePaymentSessionId = null;
    _lastDisplayMessage = {
      'type': type,
      'paymentSessionId': paymentSessionId,
      'orderId': orderNumber,
      if (previous?['amount'] != null) 'amount': previous!['amount'],
      ..._branding,
    };
    _broadcastCurrentDisplay();
    notifyListeners();
  }

  void releaseExpired(String paymentSessionId) {
    if (_activePaymentSessionId != paymentSessionId) return;
    _activePaymentSessionId = null;
    notifyListeners();
  }

  void clear({String? paymentSessionId, String reason = 'cleared'}) {
    final displayedSessionId = _lastDisplayMessage?['paymentSessionId']
        ?.toString();
    if (paymentSessionId != null &&
        _activePaymentSessionId != paymentSessionId &&
        displayedSessionId != paymentSessionId) {
      return;
    }
    final clearedSessionId = _activePaymentSessionId ?? displayedSessionId;
    _activePaymentSessionId = null;
    _lastDisplayMessage = {
      'type': 'CLEAR',
      if (clearedSessionId != null) 'paymentSessionId': clearedSessionId,
      'reason': reason,
      ..._branding,
    };
    _broadcastCurrentDisplay();
    notifyListeners();
  }

  Future<void> disconnect(String id) async {
    await _sockets[id]?.close(WebSocketStatus.normalClosure, 'Disconnected');
    _removeDevice(id);
  }

  void _broadcastCurrentDisplay() {
    final message = _lastDisplayMessage;
    if (message == null) return;
    for (final socket in List<WebSocket>.of(_sockets.values)) {
      _sendApplication(socket, message);
    }
  }

  void _sendCurrentDisplay(WebSocket socket) {
    final message = _lastDisplayMessage;
    if (message != null) _sendApplication(socket, message);
  }

  void _sendApplication(WebSocket socket, Map<String, Object?> message) {
    final type = message['type']?.toString();
    if (type == null || !customerDisplayServerMessageTypes.contains(type)) {
      return;
    }
    final fields = <String, Object?>{...message}..remove('type');
    if (type == 'SHOW_QR') {
      fields['serverNow'] = DateTime.now().toUtc().toIso8601String();
    }
    _send(socket, type, fields);
  }

  void _send(WebSocket socket, String type, Map<String, Object?> fields) {
    try {
      final payload = jsonEncode(
        protocolEnvelope(type: type, sequence: ++_sequence, fields: fields),
      );
      if (utf8.encode(payload).length > customerDisplayMaximumMessageBytes) {
        unawaited(
          socket.close(WebSocketStatus.messageTooBig, 'Message too large'),
        );
        return;
      }
      socket.add(payload);
    } on Object {
      // Socket cleanup is handled by the listener.
    }
  }

  Future<void> _closeSession(_SocketSession session, String reason) async {
    session.authenticationTimer?.cancel();
    await session.socket.close(WebSocketStatus.policyViolation, reason);
    _removeSession(session);
  }

  void _removeSession(_SocketSession session) {
    session.authenticationTimer?.cancel();
    _sessions.remove(session.id);
    final deviceId = session.deviceId;
    if (deviceId != null && identical(_sockets[deviceId], session.socket)) {
      _sockets.remove(deviceId);
      _removeDevice(deviceId);
    }
  }

  void _removeDevice(String deviceId) {
    if (_devices.remove(deviceId) == null) return;
    // A v2 pairing token is one-time. Once the last phone disconnects, issue a
    // new short-lived code so the setup page never remains on an endless QR
    // loader. Existing paired phones still reconnect with their stored device
    // credential and do not need to scan this new token.
    if (_devices.isEmpty && _server != null && _pairingTokenConsumed) {
      _issuePairingToken();
    }
    notifyListeners();
  }

  static bool _validIdentifier(String value) {
    return value.length >= 20 &&
        value.length <= 128 &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
  }

  static bool _validNonce(String value) => _validIdentifier(value);

  static Future<List<CustomerDisplayConnection>> _findLanAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final candidates = <CustomerDisplayConnection>[];
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      if (_isVirtualInterface(name)) continue;
      for (final address in interface.addresses) {
        final value = address.address;
        if (!_isPrivateAddress(value) || value.startsWith('169.254.')) continue;
        candidates.add((
          name: interface.name,
          address: value,
          transport: _transportFor(name),
        ));
      }
    }
    const priority = {'usb': 0, 'wifi': 1, 'lan': 2};
    candidates.sort((a, b) {
      final byTransport = (priority[a.transport] ?? 9).compareTo(
        priority[b.transport] ?? 9,
      );
      return byTransport != 0 ? byTransport : a.address.compareTo(b.address);
    });
    final seen = <String>{};
    return candidates.where((item) => seen.add(item.address)).toList();
  }

  static String _transportFor(String name) {
    if (name.contains('usb') ||
        name.contains('rndis') ||
        name.contains('tether')) {
      return 'usb';
    }
    if (name.contains('wlan') ||
        name.contains('wi-fi') ||
        name.contains('wifi')) {
      return 'wifi';
    }
    return 'lan';
  }

  static bool _isVirtualInterface(String name) {
    return name.contains('vethernet') ||
        name.contains('virtual') ||
        name.contains('vmware') ||
        name.contains('virtualbox') ||
        name.contains('hyper-v') ||
        name.contains('docker') ||
        name.contains('wsl') ||
        name.contains('bluetooth');
  }

  static bool _isPrivateAddress(String value) {
    if (value.startsWith('10.') || value.startsWith('192.168.')) return true;
    final parts = value.split('.');
    if (parts.length != 4 || parts.first != '172') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }
}

class _SocketSession {
  _SocketSession({
    required this.id,
    required this.socket,
    required this.remoteAddress,
    required this.lastActivityAt,
  }) : lastHeartbeatAt = lastActivityAt;

  final String id;
  final WebSocket socket;
  final String remoteAddress;
  DateTime lastActivityAt;
  DateTime lastHeartbeatAt;
  Timer? authenticationTimer;
  bool authenticated = false;
  int lastClientSequence = 0;
  String? deviceId;
  String? clientNonce;
  String? serverNonce;
  String? challengeTimestamp;
}

class _FailureState {
  const _FailureState({
    required this.count,
    required this.windowStartedAt,
    this.blockedUntil,
  });

  final int count;
  final DateTime windowStartedAt;
  final DateTime? blockedUntil;
}
