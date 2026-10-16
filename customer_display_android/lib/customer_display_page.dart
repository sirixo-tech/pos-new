import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import 'customer_display_protocol_v2.dart';

class AndroidCustomerDisplayPage extends StatefulWidget {
  const AndroidCustomerDisplayPage({super.key});

  static const routePath = '/android-customer-display';

  @override
  State<AndroidCustomerDisplayPage> createState() =>
      _AndroidCustomerDisplayPageState();
}

class _AndroidCustomerDisplayPageState extends State<AndroidCustomerDisplayPage>
    with WidgetsBindingObserver {
  static const _savedPairingKey = 'android_customer_display_pairing';
  static const _securePairingKey = 'customer_display_v2_pairing';
  static const _displayLockKey = 'android_customer_display_locked';
  static const _kioskChannel = MethodChannel('selfx_qr_display/kiosk');
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  WebSocketChannel? _channel;
  HttpClient? _webSocketHttpClient;
  StreamSubscription<Object?>? _subscription;
  Timer? _reconnectTimer;
  Timer? _authenticationTimer;
  Timer? _protocolHeartbeatTimer;
  Timer? _reconnectPresentationTimer;
  Timer? _displayResetTimer;
  Map<String, dynamic>? _pairing;
  Map<String, dynamic>? _display;
  Map<String, dynamic> _branding = const {};
  String _status = 'Not paired';
  bool _connecting = false;
  bool _scannerOpen = false;
  bool _fullscreen = false;
  bool _displayLocked = false;
  bool _kioskTransitioning = false;
  int _unlockTapCount = 0;
  Timer? _unlockTapResetTimer;
  Orientation? _stableInsetOrientation;
  EdgeInsets _stableViewPadding = EdgeInsets.zero;
  int _lastSequence = -1;
  int _clientSequence = 0;
  String? _clientNonce;
  bool _authenticated = false;
  bool _showReconnectPage = true;
  bool _requiresRepair = false;
  int _connectionGeneration = 0;
  String? _lastAnnouncedPaymentKey;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
    unawaited(_configureSpeech());
    unawaited(_restoreDisplayLock());
    unawaited(_restore());
  }

  Future<void> _restoreDisplayLock() async {
    final prefs = await SharedPreferences.getInstance();
    final locked = prefs.getBool(_displayLockKey) ?? false;
    if (!locked) return;
    await _setDisplayLocked(true);
  }

  void _handleDisplayLock() {
    if (!_displayLocked) {
      if (!_kioskTransitioning) {
        unawaited(_setDisplayLocked(true));
      }
      return;
    }

    // Count locked-state taps synchronously. Do not reject them while a native
    // transition is settling, otherwise quick taps can be silently dropped.
    _unlockTapCount += 1;
    if (_unlockTapCount >= 5) {
      _unlockTapResetTimer?.cancel();
      _unlockTapCount = 0;
      unawaited(_unlockAfterTransition());
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    if (_unlockTapCount == 1) {
      _unlockTapResetTimer?.cancel();
      _unlockTapResetTimer = Timer(const Duration(seconds: 2), () {
        _unlockTapCount = 0;
      });
    }
  }

  Future<void> _unlockAfterTransition() async {
    while (_kioskTransitioning && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    if (mounted && _displayLocked) {
      await _setDisplayLocked(false);
    }
  }

  Future<void> _setDisplayLocked(bool locked) async {
    if (_kioskTransitioning) return;
    _kioskTransitioning = true;
    _unlockTapResetTimer?.cancel();
    _unlockTapCount = 0;
    final prefs = await SharedPreferences.getInstance();
    try {
      await _kioskChannel.invokeMethod<void>(
        locked ? 'enterKiosk' : 'exitKiosk',
      );
      await prefs.setBool(_displayLockKey, locked);
      if (mounted) setState(() => _displayLocked = locked);
      await _setFullscreen(locked, applySystemUi: false);
    } on PlatformException catch (error) {
      if (locked) {
        await prefs.setBool(_displayLockKey, false);
        if (mounted) setState(() => _displayLocked = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message ?? 'Could not change Customer Display lock mode.',
            ),
          ),
        );
      }
    } finally {
      _kioskTransitioning = false;
    }
  }

  Future<void> _setFullscreen(bool enabled, {bool applySystemUi = true}) async {
    if (applySystemUi) {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
    if (mounted && _fullscreen != enabled) {
      setState(() => _fullscreen = enabled);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlockTapResetTimer?.cancel();
    _reconnectTimer?.cancel();
    _authenticationTimer?.cancel();
    _protocolHeartbeatTimer?.cancel();
    _reconnectPresentationTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _webSocketHttpClient?.close(force: true);
    unawaited(_tts.stop());
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _pairing != null &&
        !_authenticated &&
        !_requiresRepair) {
      _reconnectTimer?.cancel();
      unawaited(_connect());
    }
  }

  Future<void> _configureSpeech() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.43);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _announcePayment(Map<String, dynamic> message) async {
    final announcementKey =
        message['paymentSessionId']?.toString() ??
        message['orderId']?.toString() ??
        message['transactionId']?.toString();
    if (announcementKey != null &&
        announcementKey.isNotEmpty &&
        announcementKey == _lastAnnouncedPaymentKey) {
      return;
    }
    // Record the payment before awaiting TTS. The POS can repeat a success
    // frame while reconnecting; only the first frame should be spoken.
    if (announcementKey != null && announcementKey.isNotEmpty) {
      _lastAnnouncedPaymentKey = announcementKey;
    }
    final raw =
        message['amount'] ??
        message['total'] ??
        message['orderTotal'] ??
        message['paidAmount'];
    final amount = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    await _tts.stop();
    await _tts.speak(
      'Thank you, Boss! You paid \u20B9${amount.toStringAsFixed(2)}. Enjoy your meal!',
    );
  }

  Future<void> _restore() async {
    // Protocol v1 stored a predictable bearer token in SharedPreferences.
    // It is deliberately deleted and never migrated into protocol v2.
    final prefs = await SharedPreferences.getInstance();
    final hadLegacyPairing = prefs.containsKey(_savedPairingKey);
    await prefs.remove(_savedPairingKey);
    final saved = await _secureStorage.read(key: _securePairingKey);
    if (saved == null) {
      if (hadLegacyPairing && mounted) {
        setState(() => _status = 'Security upgrade: scan the POS code again');
      }
      return;
    }
    try {
      final value = jsonDecode(saved);
      if (value is Map<String, dynamic> && _validStoredPairing(value)) {
        _pairing = value;
        await _connect();
      } else {
        await _secureStorage.delete(key: _securePairingKey);
      }
    } on Object {
      await _secureStorage.delete(key: _securePairingKey);
    }
    if (hadLegacyPairing && mounted && _pairing == null) {
      setState(() => _status = 'Security upgrade: scan the POS code again');
    }
  }

  Future<bool> _acceptPairing(String raw) async {
    try {
      final value = decodePairingPayload(raw);
      final error = validatePairingPayload(value);
      if (error != null) throw FormatException(error);
      // Invalidate callbacks from the old socket before replacing its pairing.
      _connectionGeneration += 1;
      await _closeConnection();
      _connecting = false;
      await _secureStorage.delete(key: _securePairingKey);
      _pairing = <String, dynamic>{
        ...value,
        'deviceId': secureRandomBase64Url(bytes: 24),
        'deviceName': 'SELFX QR Connect',
      };
      _requiresRepair = false;
      _scannerOpen = false;
      if (mounted) setState(() {});
      await _connect();
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pair: $error')));
      return false;
    }
  }

  List<({String host, String transport})> _connectionCandidates() {
    final fallbackHost = _pairing?['host']?.toString().trim();
    if (fallbackHost?.isNotEmpty != true) return const [];
    return [
      (
        host: fallbackHost!,
        transport:
            _pairing?['transport']?.toString().trim().toLowerCase() ?? 'lan',
      ),
    ];
  }

  Future<void> _connect() async {
    if (_connecting || _pairing == null || _requiresRepair) return;
    _connecting = true;
    final generation = ++_connectionGeneration;
    _reconnectTimer?.cancel();
    await _closeConnection();
    if (!mounted || generation != _connectionGeneration || _pairing == null) {
      _connecting = false;
      return;
    }
    final port = (_pairing!['port'] as num?)?.toInt() ?? 8081;
    final expectedFingerprint = normalizeCertificateFingerprint(
      _pairing!['certificateFingerprint']?.toString() ?? '',
    );
    Object? lastError;
    try {
      for (final option in _connectionCandidates()) {
        if (!mounted) return;
        final label = switch (option.transport) {
          'usb' => 'USB tethering',
          'wifi' => 'Wi-Fi',
          _ => 'local network',
        };
        setState(
          () =>
              _status = 'Opening secure $label connection (${option.host})...',
        );
        WebSocketChannel? candidate;
        try {
          final securityContext = SecurityContext(withTrustedRoots: false);
          final httpClient = HttpClient(context: securityContext);
          httpClient.badCertificateCallback = (certificate, host, certPort) {
            if (host != option.host || certPort != port) return false;
            final actual = certificateSha256Fingerprint(certificate.der);
            return constantTimeStringEquals(actual, expectedFingerprint);
          };
          _webSocketHttpClient = httpClient;
          candidate = IOWebSocketChannel.connect(
            Uri(
              scheme: 'wss',
              host: option.host,
              port: port,
              path: '/customer-display',
            ),
            customClient: httpClient,
            connectTimeout: const Duration(seconds: 4),
          );
          await candidate.ready.timeout(const Duration(seconds: 4));
          if (!mounted || generation != _connectionGeneration) {
            await candidate.sink.close();
            return;
          }
          _channel = candidate;
          _lastSequence = -1;
          _clientSequence = 0;
          _authenticated = false;
          _subscription = candidate.stream.listen(
            (data) => _onMessage(data, generation),
            onDone: () =>
                _disconnected(_socketCloseDescription(candidate!), generation),
            onError: (error) => _disconnected(error, generation),
            cancelOnError: true,
          );
          final credential = _pairing!['deviceCredential']?.toString();
          if (credential?.isNotEmpty == true) {
            _clientNonce = secureRandomBase64Url(bytes: 32);
            _sendClientMessage('AUTH_HELLO', {
              'deviceId': _pairing!['deviceId']?.toString(),
              'clientNonce': _clientNonce,
            });
          } else {
            _sendClientMessage('PAIR_REQUEST', {
              'deviceId': _pairing!['deviceId']?.toString(),
              'deviceName': _pairing!['deviceName']?.toString(),
              'pairingToken': _pairing!['pairingToken']?.toString(),
            });
          }
          _authenticationTimer?.cancel();
          _authenticationTimer = Timer(const Duration(seconds: 10), () {
            if (!_authenticated && generation == _connectionGeneration) {
              _disconnected('Secure authentication timeout', generation);
            }
          });
          if (mounted) setState(() => _status = 'Authenticating via $label...');
          return;
        } on Object catch (error) {
          lastError = error;
          try {
            await candidate?.sink.close().timeout(const Duration(seconds: 1));
          } on Object {
            // Continue with the next advertised adapter.
          }
          _webSocketHttpClient?.close(force: true);
          _webSocketHttpClient = null;
        }
      }
      if (generation == _connectionGeneration) {
        _disconnected(lastError, generation);
      }
    } finally {
      if (generation == _connectionGeneration) {
        _connecting = false;
        if (mounted) setState(() {});
      }
    }
  }

  void _onMessage(Object? data, int generation) {
    if (generation != _connectionGeneration) return;
    if (data is! String ||
        utf8.encode(data).length > customerDisplayMaximumMessageBytes) {
      _disconnected('Rejected oversized secure message', generation);
      return;
    }
    try {
      final value = jsonDecode(data);
      if (value is! Map<String, dynamic>) return;
      final validation = validateProtocolEnvelope(
        value,
        allowedTypes: customerDisplayServerMessageTypes,
        lastSequence: _lastSequence,
      );
      if (validation != null) {
        _disconnected('Rejected message: $validation', generation);
        return;
      }
      _lastSequence = value['sequence'] as int;
      final type = value['type'] as String;
      if (type == 'PAIR_ACCEPT') {
        unawaited(_completeSecurePairing(value));
        return;
      }
      if (type == 'AUTH_CHALLENGE') {
        _answerAuthenticationChallenge(value);
        return;
      }
      if (type == 'AUTH_OK') {
        _markAuthenticated();
        return;
      }
      if (type == 'AUTH_ERROR') {
        unawaited(
          _invalidatePairing('Pairing rejected - scan the POS code again'),
        );
        return;
      }
      if (type == 'PING') {
        if (_authenticated) _sendClientMessage('PONG', const {});
        return;
      }
      if (!_authenticated ||
          !isValidPaymentMessage(
            value,
            currentPaymentSessionId: _display?['paymentSessionId']?.toString(),
          )) {
        _disconnected('Rejected invalid payment message', generation);
        return;
      }
      if (type == 'CLEAR') {
        _displayResetTimer?.cancel();
        final currentSession = _display?['paymentSessionId']?.toString();
        final clearedSession = value['paymentSessionId']?.toString();
        if (clearedSession != null &&
            currentSession != null &&
            clearedSession != currentSession) {
          return;
        }
        if (mounted) {
          setState(() {
            _display = null;
            if (value['restaurantName'] != null ||
                value['restaurantLogoUrl'] != null) {
              _branding = {
                'restaurantName': value['restaurantName'],
                'restaurantLogoUrl': value['restaurantLogoUrl'],
              };
            }
          });
        }
      } else if (type == 'SHOW_QR' ||
          type == 'PAYMENT_SUCCESS' ||
          type == 'PAYMENT_FAILED' ||
          type == 'PAYMENT_EXPIRED') {
        _displayResetTimer?.cancel();
        if (mounted) {
          setState(() {
            _display = type == 'PAYMENT_EXPIRED' ? null : value;
            if (value['restaurantName'] != null ||
                value['restaurantLogoUrl'] != null) {
              _branding = {
                'restaurantName': value['restaurantName'],
                'restaurantLogoUrl': value['restaurantLogoUrl'],
              };
            }
          });
          if (type == 'PAYMENT_SUCCESS') {
            unawaited(_announcePayment(value));
          }
          if (type == 'PAYMENT_SUCCESS' || type == 'PAYMENT_FAILED') {
            _scheduleReturnToWaiting();
          }
        }
      }
    } on FormatException {
      _disconnected('Rejected malformed secure message', generation);
    }
  }

  Future<void> _completeSecurePairing(Map<String, dynamic> message) async {
    final deviceId = message['deviceId']?.toString() ?? '';
    final credential = message['deviceCredential']?.toString() ?? '';
    if (deviceId != _pairing?['deviceId'] || !_validCredential(credential)) {
      await _invalidatePairing('Invalid pairing response - scan again');
      return;
    }
    final stored = <String, dynamic>{
      'type': 'SELFX_CUSTOMER_DISPLAY',
      'version': customerDisplayProtocolVersion,
      'host': _pairing!['host'],
      'port': _pairing!['port'],
      'transport': _pairing!['transport'],
      'interface': _pairing!['interface'],
      'certificateFingerprint': _pairing!['certificateFingerprint'],
      'deviceId': deviceId,
      'deviceName': _pairing!['deviceName'],
      'deviceCredential': credential,
    };
    // The server sends the current display immediately after PAIR_ACCEPT.
    // Mark this in-memory session authenticated before awaiting platform secure
    // storage, otherwise that next valid message can arrive first and be
    // incorrectly rejected as unauthenticated.
    _pairing = stored;
    _markAuthenticated();
    try {
      await _secureStorage.write(
        key: _securePairingKey,
        value: jsonEncode(stored),
      );
    } on Object {
      await _invalidatePairing(
        'Could not save secure pairing - scan the POS code again',
      );
    }
  }

  void _answerAuthenticationChallenge(Map<String, dynamic> message) {
    final deviceId = _pairing?['deviceId']?.toString() ?? '';
    final credential = _pairing?['deviceCredential']?.toString() ?? '';
    final clientNonce = _clientNonce;
    final serverNonce = message['serverNonce']?.toString() ?? '';
    final challengeTimestamp = message['challengeTimestamp']?.toString() ?? '';
    if (message['deviceId'] != deviceId ||
        message['clientNonce'] != clientNonce ||
        clientNonce == null ||
        !_validCredential(credential) ||
        !_validCredential(serverNonce) ||
        DateTime.tryParse(challengeTimestamp) == null) {
      _disconnected('Invalid authentication challenge');
      return;
    }
    final proof = createDeviceAuthProof(
      secret: credential,
      deviceId: deviceId,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      challengeTimestamp: challengeTimestamp,
    );
    _sendClientMessage('AUTH_RESPONSE', {
      'deviceId': deviceId,
      'clientNonce': clientNonce,
      'serverNonce': serverNonce,
      'challengeTimestamp': challengeTimestamp,
      'proof': proof,
    });
  }

  void _markAuthenticated() {
    _authenticated = true;
    _authenticationTimer?.cancel();
    _authenticationTimer = null;
    // Keep NAT/Wi-Fi mappings and the POS idle timer alive with the secured
    // v2 protocol. Do not use IOWebSocketChannel.pingInterval here: some
    // Android network stacks close otherwise healthy pinned-TLS sockets when
    // the transport-level pong is delayed while the app is briefly inactive.
    _protocolHeartbeatTimer?.cancel();
    _protocolHeartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_authenticated && _channel != null) {
        _sendClientMessage('PONG', const {});
      }
    });
    _reconnectPresentationTimer?.cancel();
    _reconnectPresentationTimer = null;
    if (mounted) {
      setState(() {
        _showReconnectPage = false;
        _status = 'Securely connected';
      });
    }
  }

  String _socketCloseDescription(WebSocketChannel channel) {
    final code = channel.closeCode;
    final reason = channel.closeReason?.trim();
    if (code == null && (reason == null || reason.isEmpty)) {
      return 'Secure connection closed';
    }
    return 'Secure connection closed'
        '${code == null ? '' : ' ($code)'}'
        '${reason == null || reason.isEmpty ? '' : ': $reason'}';
  }

  void _sendClientMessage(String type, Map<String, Object?> fields) {
    final channel = _channel;
    if (channel == null) return;
    final payload = jsonEncode(
      protocolEnvelope(type: type, sequence: ++_clientSequence, fields: fields),
    );
    if (utf8.encode(payload).length <= customerDisplayMaximumMessageBytes) {
      channel.sink.add(payload);
    }
  }

  Future<void> _invalidatePairing(String status) async {
    _requiresRepair = true;
    _connectionGeneration += 1;
    _connecting = false;
    _reconnectTimer?.cancel();
    await _secureStorage.delete(key: _securePairingKey);
    await _closeConnection();
    if (mounted) {
      setState(() {
        _pairing = null;
        _display = null;
        _showReconnectPage = true;
        _status = status;
      });
    }
  }

  bool _validStoredPairing(Map<String, dynamic> value) {
    return value['type'] == 'SELFX_CUSTOMER_DISPLAY' &&
        value['version'] == customerDisplayProtocolVersion &&
        value['host']?.toString().isNotEmpty == true &&
        normalizeCertificateFingerprint(
              value['certificateFingerprint']?.toString() ?? '',
            ).length ==
            64 &&
        value['deviceId']?.toString().isNotEmpty == true &&
        _validCredential(value['deviceCredential']?.toString() ?? '');
  }

  bool _validCredential(String value) {
    try {
      return base64Url.decode(base64Url.normalize(value)).length >= 24;
    } on FormatException {
      return false;
    }
  }

  void _scheduleReturnToWaiting() {
    _displayResetTimer?.cancel();
    _displayResetTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _display = null);
    });
  }

  Future<void> _closeConnection() async {
    _authenticationTimer?.cancel();
    _authenticationTimer = null;
    _protocolHeartbeatTimer?.cancel();
    _protocolHeartbeatTimer = null;
    _authenticated = false;
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    if (subscription != null) {
      try {
        await subscription.cancel().timeout(const Duration(seconds: 2));
      } on Object {
        // A stale socket must not block reconnecting the display.
      }
    }
    if (channel != null) {
      try {
        await channel.sink.close().timeout(const Duration(seconds: 2));
      } on Object {
        // The peer may already be unreachable.
      }
    }
    _webSocketHttpClient?.close(force: true);
    _webSocketHttpClient = null;
  }

  void _disconnected([Object? error, int? generation]) {
    if (!mounted ||
        (generation != null && generation != _connectionGeneration)) {
      return;
    }
    _authenticated = false;
    _authenticationTimer?.cancel();
    _protocolHeartbeatTimer?.cancel();
    _protocolHeartbeatTimer = null;
    final detail = error == null ? '' : ': ${error.toString()}';
    setState(() => _status = 'Connection lost - retrying$detail');
    // Short Wi-Fi hand-offs should not flash the entire customer-facing UI.
    // If reconnection has not succeeded after the grace period, reveal the
    // full retry/re-pair screen. The header badge remains truthful meanwhile.
    _reconnectPresentationTimer?.cancel();
    _reconnectPresentationTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || _authenticated) return;
      setState(() => _showReconnectPage = true);
    });
    _reconnectTimer?.cancel();
    if (!_requiresRepair) {
      _reconnectTimer = Timer(const Duration(seconds: 2), _connect);
    }
  }

  Future<void> _confirmForget() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.link_off_rounded),
        title: const Text('Unlink this display?'),
        content: const Text(
          'This phone will stop receiving payment QR codes. You will need to scan the Windows POS pairing code again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _forget();
    }
  }

  Future<void> _forget() async {
    _reconnectTimer?.cancel();
    _connectionGeneration += 1;
    _connecting = false;
    await _closeConnection();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPairingKey);
    await _secureStorage.delete(key: _securePairingKey);
    _requiresRepair = false;
    if (mounted) {
      setState(() {
        _pairing = null;
        _display = null;
        _showReconnectPage = true;
        _status = 'Not paired';
      });
    }
  }

  Map<String, dynamic> _resolvedBranding([Map<String, dynamic>? source]) {
    final result = <String, dynamic>{..._branding, ...?source};
    final raw = result['restaurantLogoUrl']?.toString().trim();
    if (raw == null || raw.isEmpty || Uri.tryParse(raw)?.hasScheme == true) {
      return result;
    }
    // Relative local images cannot be loaded through Flutter's global image
    // client with the connection-specific certificate pin, so reject them.
    result.remove('restaurantLogoUrl');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (_stableInsetOrientation != mediaQuery.orientation) {
      _stableInsetOrientation = mediaQuery.orientation;
      _stableViewPadding = mediaQuery.viewPadding;
    } else {
      _stableViewPadding = EdgeInsets.fromLTRB(
        math.max(_stableViewPadding.left, mediaQuery.viewPadding.left),
        math.max(_stableViewPadding.top, mediaQuery.viewPadding.top),
        math.max(_stableViewPadding.right, mediaQuery.viewPadding.right),
        math.max(_stableViewPadding.bottom, mediaQuery.viewPadding.bottom),
      );
    }
    final display = _display;
    // Authentication is the source of truth. Status text is presentation only
    // and must never decide whether the socket is connected.
    final connected = _authenticated && _channel != null;
    // Keep all customer-facing connection controls stable during the same
    // short automatic-reconnect grace period used by the page body. A brief
    // Wi-Fi hand-off must not flash the badge or reveal unlink actions.
    final presentedConnected = connected || !_showReconnectPage;
    final paired = _validCredential(
      _pairing?['deviceCredential']?.toString() ?? '',
    );
    final isPairingHome = _pairing == null && !_scannerOpen;
    return MediaQuery(
      data: mediaQuery.copyWith(padding: _stableViewPadding),
      child: PopScope(
        canPop: !_displayLocked,
        child: Scaffold(
          backgroundColor: isPairingHome
              ? const Color(0xFFFF7A00)
              : const Color(0xFF050B18),
          appBar: AppBar(
            backgroundColor: isPairingHome
                ? const Color(0xFFFF7A00)
                : const Color(0xFF050B18),
            foregroundColor: Colors.white,
            title: const Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/images/mainlogo.png'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SELFX QR Connect',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            actions: [
              if (paired || _displayLocked)
                IconButton(
                  tooltip: _displayLocked
                      ? 'Tap five times to unlock'
                      : 'Lock customer display',
                  onPressed: _handleDisplayLock,
                  color: _displayLocked
                      ? const Color(0xFFF59E0B)
                      : Colors.white,
                  icon: Icon(_displayLocked ? Icons.lock : Icons.lock_outline),
                ),
              if (!_displayLocked && paired)
                IconButton(
                  tooltip: _fullscreen
                      ? 'Exit full screen'
                      : 'Enter full screen',
                  onPressed: () => _setFullscreen(!_fullscreen),
                  icon: Icon(
                    _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
              if (!_displayLocked && paired)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _ConnectionBadge(connected: presentedConnected),
                ),
              if (!_displayLocked && paired && !presentedConnected)
                IconButton(
                  tooltip: 'Scan a new POS pairing code',
                  onPressed: () => setState(() => _scannerOpen = true),
                  icon: const Icon(Icons.link),
                ),
              if (!_displayLocked && paired && !presentedConnected)
                IconButton(
                  tooltip: 'Forget POS',
                  onPressed: _confirmForget,
                  icon: const Icon(Icons.link_off),
                ),
            ],
          ),
          body: AbsorbPointer(
            // Keep pairing/scanner actions usable while the launcher lock is on.
            absorbing: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPairingHome
                      ? const [
                          Color(0xFFFFFBF7),
                          Color(0xFFFFF4EA),
                          Colors.white,
                        ]
                      : const [
                          Color(0xFF071426),
                          Color(0xFF07111F),
                          Color(0xFF0B1020),
                        ],
                ),
              ),
              child: SafeArea(
                child: _scannerOpen
                    ? _Scanner(
                        onCode: _acceptPairing,
                        onCancel: () => setState(() => _scannerOpen = false),
                      )
                    : _pairing == null
                    ? _PairPrompt(
                        onScan: () => setState(() => _scannerOpen = true),
                      )
                    : display?['type'] == 'SHOW_QR'
                    ? _QrDisplay(
                        key: ValueKey(
                          '${display!['paymentSessionId']}:${display['sequence']}:${display['qrData']}',
                        ),
                        data: _resolvedBranding(display),
                        onExpired: () {
                          if (!mounted || !identical(_display, display)) return;
                          setState(() => _display = null);
                        },
                      )
                    : display?['type'] == 'PAYMENT_SUCCESS'
                    ? _SuccessDisplay(
                        data: display!,
                        branding: _resolvedBranding(display),
                      )
                    : display?['type'] == 'PAYMENT_FAILED'
                    ? _PaymentStateDisplay(
                        branding: _resolvedBranding(display),
                        title: 'Payment Failed',
                        message: 'Please try again or ask the cashier.',
                        icon: Icons.cancel_rounded,
                        color: const Color(0xFFEF4444),
                      )
                    : display?['type'] == 'PAYMENT_EXPIRED'
                    ? _PaymentStateDisplay(
                        branding: _resolvedBranding(display),
                        title: 'Payment Expired',
                        message: 'Please ask the cashier for a new QR code.',
                        icon: Icons.timer_off_rounded,
                        color: const Color(0xFFF59E0B),
                      )
                    : _WaitingDisplay(
                        connected: presentedConnected,
                        branding: _resolvedBranding(),
                        connectionLabel: switch (_pairing?['transport']
                            ?.toString()
                            .toLowerCase()) {
                          'usb' => 'USB tethering',
                          'wifi' => 'Wi-Fi',
                          _ => 'LAN',
                        },
                        onRetry: _connecting ? null : _connect,
                        onScan: () => setState(() => _scannerOpen = true),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF34D399) : const Color(0xFFEF4444);
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PairPrompt extends StatelessWidget {
  const _PairPrompt({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 400,
                height: 724,
                child: Column(
                  children: [
                    const _PairHero(),
                    const SizedBox(height: 8),
                    _ScanPairingButton(onPressed: onScan),
                    const SizedBox(height: 8),
                    _PairCard(
                      number: 1,
                      title: 'Login to POS',
                      description:
                          'Open the POS software and log in with your credentials.',
                      visual: const _LoginVisual(),
                    ),
                    const SizedBox(height: 8),
                    _PairCard(
                      number: 2,
                      title: 'Show Pairing QR',
                      description:
                          'Click the phone icon at the top. A pairing QR code will appear.',
                      visual: const _QrVisual(),
                    ),
                    const SizedBox(height: 8),
                    _PairCard(
                      number: 3,
                      title: 'Scan & Pair',
                      description:
                          'Scan the pairing QR. Payment QR codes will appear here.',
                      visual: const _ScanVisual(),
                      onTap: onScan,
                    ),
                    const SizedBox(height: 8),
                    const _OneTimeNotice(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PairHero extends StatelessWidget {
  const _PairHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 174,
      child: Column(
        children: [
          SizedBox(
            width: 92,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF7A00).withValues(alpha: .55),
                    ),
                  ),
                ),
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF7A00).withValues(alpha: .4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A00).withValues(alpha: .14),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.phone_android_rounded,
                  color: Color(0xFFFF7A00),
                  size: 46,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect to POS',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Follow the simple steps below to connect\nyour device with POS.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 16,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Container(width: 40, height: 3, color: const Color(0xFFFF7A00)),
        ],
      ),
    );
  }
}

class _ScanPairingButton extends StatelessWidget {
  const _ScanPairingButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8A00), Color(0xFFFF6500)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFDE63)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB800).withValues(alpha: .24),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
          label: const Text(
            'Scan Pairing QR',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({
    required this.number,
    required this.title,
    required this.description,
    required this.visual,
    this.onTap,
  });
  final int number;
  final String title;
  final String description;
  final Widget visual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 124,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFDCC8), width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF7A00),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Color(0xFF111622),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFFF7A00),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 15.5,
                        height: 1.25,
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Tap here to scan',
                        style: TextStyle(
                          color: Color(0xFFFF7A00),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 92,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(width: 180, height: 140, child: visual),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginVisual extends StatelessWidget {
  const _LoginVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(
          Icons.desktop_windows_rounded,
          color: Color(0xFF778294),
          size: 125,
        ),
        Positioned(
          right: 5,
          top: 4,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF111A29),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF7A00), width: 2),
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              color: Color(0xFFFF7A00),
              size: 27,
            ),
          ),
        ),
      ],
    );
  }
}

class _QrVisual extends StatelessWidget {
  const _QrVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF7A00), width: 3),
      ),
      child: const Icon(
        Icons.qr_code_2_rounded,
        color: Colors.black,
        size: 105,
      ),
    );
  }
}

class _ScanVisual extends StatelessWidget {
  const _ScanVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(
          Icons.phone_android_rounded,
          color: Color(0xFF768195),
          size: 145,
        ),
        Container(
          width: 83,
          height: 83,
          color: Colors.white,
          child: const Icon(
            Icons.qr_code_2_rounded,
            color: Colors.black,
            size: 78,
          ),
        ),
        Container(width: 105, height: 2, color: const Color(0xFFFF7A00)),
      ],
    );
  }
}

class _OneTimeNotice extends StatelessWidget {
  const _OneTimeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFDCC8), width: 1.3),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFFF7A00), size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pairing is required only once.',
                  style: TextStyle(
                    color: Color(0xFFFF7A00),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Reconnect anytime on the same network.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Scanner extends StatefulWidget {
  const _Scanner({required this.onCode, required this.onCancel});
  final Future<bool> Function(String) onCode;
  final VoidCallback onCancel;

  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) async {
            if (_handled) return;
            final raw = capture.barcodes
                .map((barcode) => barcode.rawValue?.trim())
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .firstOrNull;
            if (raw == null) return;
            _handled = true;
            final accepted = await widget.onCode(raw);
            if (mounted && !accepted) _handled = false;
          },
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: FilledButton.tonalIcon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

class _RestaurantBrand extends StatelessWidget {
  const _RestaurantBrand({
    required this.branding,
    this.compact = false,
    this.darkText = false,
  });

  final Map<String, dynamic> branding;
  final bool compact;
  final bool darkText;

  @override
  Widget build(BuildContext context) {
    final name = branding['restaurantName']?.toString().trim();
    final logoUrl = branding['restaurantLogoUrl']?.toString().trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 130 : 220,
          height: compact ? 88 : 145,
          padding: EdgeInsets.all(compact ? 10 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 14 : 20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: logoUrl != null && logoUrl.isNotEmpty
              ? Image.network(
                  logoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Image.asset(
                    'assets/images/mainlogo.png',
                    fit: BoxFit.contain,
                  ),
                )
              : Image.asset('assets/images/mainlogo.png', fit: BoxFit.contain),
        ),
        if (name != null && name.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkText ? const Color(0xFF0F172A) : Colors.white,
              fontSize: compact ? 20 : 30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

class _UpiAppsRow extends StatelessWidget {
  const _UpiAppsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _PaymentIcon(Icons.account_balance, Color(0xFF097969)),
        SizedBox(width: 10),
        _PaymentIcon(Icons.g_mobiledata_rounded, Color(0xFF4285F4)),
        SizedBox(width: 10),
        _PaymentIcon(Icons.phone_android_rounded, Color(0xFF5F259F)),
        SizedBox(width: 10),
        _PaymentIcon(Icons.wallet_rounded, Color(0xFF00A8E0)),
        SizedBox(width: 10),
        _PaymentIcon(Icons.currency_rupee_rounded, Color(0xFFF58220)),
      ],
    );
  }
}

class _PaymentIcon extends StatelessWidget {
  const _PaymentIcon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 27),
    );
  }
}

class _StaticDisplay extends StatelessWidget {
  const _StaticDisplay({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(width: constraints.maxWidth, child: child),
          ),
        ),
      ),
    );
  }
}

class _WaitingDisplay extends StatelessWidget {
  const _WaitingDisplay({
    required this.connected,
    required this.branding,
    required this.connectionLabel,
    required this.onRetry,
    required this.onScan,
  });
  final bool connected;
  final Map<String, dynamic> branding;
  final String connectionLabel;
  final VoidCallback? onRetry;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: _StaticDisplay(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 104),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RestaurantBrand(branding: branding),
                const SizedBox(height: 34),
                Icon(
                  connected ? Icons.hourglass_top_rounded : Icons.sync_rounded,
                  color: connected
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF60A5FA),
                  size: 58,
                ),
                const SizedBox(height: 16),
                Text(
                  connected ? 'Scan to Pay' : 'Reconnecting...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  connected
                      ? 'Your payment QR will appear automatically.'
                      : 'Restoring the connection to the cashier POS',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 18,
                    height: 1.45,
                  ),
                ),
                if (!connected) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry connection'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onScan,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF60A5FA)),
                        ),
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Scan new pairing QR'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (connected)
          Positioned(
            left: 16,
            right: 16,
            bottom: 22,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                const _StatusChip(
                  icon: Icons.shield_outlined,
                  label: 'Encrypted',
                ),
                _StatusChip(icon: Icons.wifi_rounded, label: connectionLabel),
                const _StatusChip(
                  icon: Icons.sync_rounded,
                  label: 'Auto display',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF071426),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF294461)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF60A5FA), size: 17),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE5EDF7),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrDisplay extends StatefulWidget {
  const _QrDisplay({super.key, required this.data, required this.onExpired});
  final Map<String, dynamic> data;
  final VoidCallback onExpired;

  @override
  State<_QrDisplay> createState() => _QrDisplayState();
}

class _QrDisplayState extends State<_QrDisplay> {
  Timer? _timer;
  late DateTime _expiresAt;
  Duration _remaining = Duration.zero;
  bool _expiryReported = false;

  @override
  void initState() {
    super.initState();
    _setExpiry();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _QrDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data['expiresAt'] != widget.data['expiresAt'] ||
        oldWidget.data['sequence'] != widget.data['sequence'] ||
        oldWidget.data['paymentSessionId'] != widget.data['paymentSessionId'] ||
        oldWidget.data['qrData'] != widget.data['qrData']) {
      _expiryReported = false;
      _setExpiry();
    }
  }

  void _setExpiry() {
    final suppliedExpiry = DateTime.tryParse(
      widget.data['expiresAt']?.toString() ?? '',
    );
    final suppliedServerNow = DateTime.tryParse(
      widget.data['serverNow']?.toString() ?? '',
    );
    final seconds = (widget.data['timeoutSeconds'] as num?)?.toInt() ?? 120;
    final fallback = Duration(seconds: seconds.clamp(1, 900));
    final serverRemaining = suppliedExpiry != null && suppliedServerNow != null
        ? suppliedExpiry.difference(suppliedServerNow)
        : fallback;
    final remaining = serverRemaining.isNegative
        ? Duration.zero
        : serverRemaining > fallback
        ? fallback
        : serverRemaining;
    _expiresAt = DateTime.now().add(remaining);
    _updateRemaining();
  }

  void _tick() {
    if (!mounted) return;
    setState(_updateRemaining);
    if (_remaining == Duration.zero && !_expiryReported) {
      _expiryReported = true;
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onExpired());
    }
  }

  void _updateRemaining() {
    final value = _expiresAt.difference(DateTime.now());
    _remaining = value.isNegative ? Duration.zero : value;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final seconds = _remaining.inSeconds;
    final time =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final orderId = data['orderId']?.toString() ?? '';
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: _StaticDisplay(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RestaurantBrand(branding: data, compact: true, darkText: true),
                const SizedBox(height: 12),
                const Text(
                  'SCAN TO PAY',
                  style: TextStyle(
                    color: Color(0xFF071426),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD7C2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PaymentInfo(label: 'ORDER ID', value: orderId),
                      ),
                      const SizedBox(
                        height: 42,
                        child: VerticalDivider(width: 18),
                      ),
                      Expanded(
                        child: _PaymentInfo(
                          label: 'AMOUNT',
                          value:
                              '${String.fromCharCode(0x20B9)}${amount.toStringAsFixed(2)}',
                          valueColor: Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(
                        height: 42,
                        child: VerticalDivider(width: 18),
                      ),
                      Expanded(
                        child: _PaymentInfo(
                          label: 'EXPIRES IN',
                          value: time,
                          valueColor: Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
                if (seconds > 0 && seconds <= 30) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF97316)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFEA580C),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'QR code expires in $seconds seconds. Please complete payment now.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF9A3412),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFF7A00),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x160F172A),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      QrImageView(data: data['qrData'].toString(), size: 286),
                      const SizedBox(height: 8),
                      const Text(
                        'Scan with any UPI app',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PAY USING ANY UPI APP',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 10),
                const _UpiAppsRow(),
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TrustItem(Icons.verified_user_outlined, 'Secure Payments'),
                    _TrustItem(Icons.bolt_rounded, 'Instant & Easy'),
                    _TrustItem(Icons.lock_outline_rounded, '100% Safe'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentInfo extends StatelessWidget {
  const _PaymentInfo({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF0F172A),
  });
  final String label;
  final String value;
  final Color valueColor;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      FittedBox(
        child: Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Color(0xFF64748B)),
      SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _SuccessDisplay extends StatelessWidget {
  const _SuccessDisplay({required this.data, required this.branding});
  final Map<String, dynamic> data;
  final Map<String, dynamic> branding;

  @override
  Widget build(BuildContext context) {
    final amount = (data['amount'] as num?)?.toDouble();
    final order = data['orderId']?.toString().trim();
    return Center(
      child: _StaticDisplay(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RestaurantBrand(branding: branding, compact: true),
            const SizedBox(height: 28),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.25, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Opacity(
                opacity: value.clamp(0, 1),
                child: Transform.scale(scale: value, child: child),
              ),
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 92,
                  color: Color(0xFF34D399),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Payment Successful',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              '\u20B9${(amount ?? 0.0).toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF34D399),
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (order?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Order #$order',
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Thank You!\nPreparing your order...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentStateDisplay extends StatelessWidget {
  const _PaymentStateDisplay({
    required this.branding,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final Map<String, dynamic> branding;
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _StaticDisplay(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RestaurantBrand(branding: branding, compact: true),
            const SizedBox(height: 30),
            Icon(icon, size: 96, color: color),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 19,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
