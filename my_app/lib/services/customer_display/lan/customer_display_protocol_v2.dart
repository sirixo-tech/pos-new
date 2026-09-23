import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const int customerDisplayProtocolVersion = 2;
const int customerDisplayMaximumMessageBytes = 16 * 1024;
const Duration customerDisplayPairingLifetime = Duration(minutes: 2);
const Duration customerDisplayTimestampTolerance = Duration(minutes: 2);

const Set<String> customerDisplayServerMessageTypes = {
  'PAIR_ACCEPT',
  'AUTH_CHALLENGE',
  'AUTH_OK',
  'AUTH_ERROR',
  'PING',
  'SHOW_QR',
  'CLEAR',
  'PAYMENT_SUCCESS',
  'PAYMENT_FAILED',
  'PAYMENT_EXPIRED',
};

const Set<String> customerDisplayClientMessageTypes = {
  'PAIR_REQUEST',
  'AUTH_HELLO',
  'AUTH_RESPONSE',
  'PONG',
};

String secureRandomBase64Url({int bytes = 32, Random? random}) {
  if (bytes < 16) throw ArgumentError.value(bytes, 'bytes');
  final source = random ?? Random.secure();
  final values = Uint8List.fromList(
    List<int>.generate(bytes, (_) => source.nextInt(256), growable: false),
  );
  return base64UrlEncode(values).replaceAll('=', '');
}

String sha256Base64Url(String value) => base64UrlEncode(
  sha256.convert(utf8.encode(value)).bytes,
).replaceAll('=', '');

String certificateSha256Fingerprint(List<int> certificateDer) =>
    sha256.convert(certificateDer).toString().toLowerCase();

String normalizeCertificateFingerprint(String value) =>
    value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();

String createDeviceAuthProof({
  required String secret,
  required String deviceId,
  required String clientNonce,
  required String serverNonce,
  required String challengeTimestamp,
}) {
  final key = base64Url.decode(base64Url.normalize(secret));
  final message = [
    'SELFX_CUSTOMER_DISPLAY_AUTH_V2',
    deviceId,
    clientNonce,
    serverNonce,
    challengeTimestamp,
  ].join('\n');
  return base64UrlEncode(
    Hmac(sha256, key).convert(utf8.encode(message)).bytes,
  ).replaceAll('=', '');
}

bool constantTimeStringEquals(String first, String second) {
  final a = utf8.encode(first);
  final b = utf8.encode(second);
  var difference = a.length ^ b.length;
  final length = max(a.length, b.length);
  for (var index = 0; index < length; index++) {
    difference |=
        (index < a.length ? a[index] : 0) ^ (index < b.length ? b[index] : 0);
  }
  return difference == 0;
}

Map<String, dynamic> protocolEnvelope({
  required String type,
  required int sequence,
  Map<String, Object?> fields = const {},
  DateTime? timestamp,
}) => <String, dynamic>{
  'version': customerDisplayProtocolVersion,
  'type': type,
  'sequence': sequence,
  'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
  ...fields,
};

String? validateProtocolEnvelope(
  Map<String, dynamic> message, {
  required Set<String> allowedTypes,
  required int lastSequence,
  DateTime? now,
}) {
  if (message['version'] != customerDisplayProtocolVersion) {
    return 'Unsupported protocol version.';
  }
  final type = message['type'];
  if (type is! String || !allowedTypes.contains(type)) {
    return 'Unsupported message type.';
  }
  final sequence = message['sequence'];
  if (sequence is! int || sequence <= lastSequence) {
    return 'Invalid or replayed sequence.';
  }
  final timestamp = DateTime.tryParse(message['timestamp']?.toString() ?? '');
  if (timestamp == null) return 'Invalid timestamp.';
  final difference = (now ?? DateTime.now()).toUtc().difference(
    timestamp.toUtc(),
  );
  if (difference.abs() > customerDisplayTimestampTolerance) {
    return 'Expired timestamp.';
  }
  return null;
}

String? validatePairingPayload(Map<String, dynamic> value, {DateTime? now}) {
  if (value['type'] != 'SELFX_CUSTOMER_DISPLAY' ||
      value['version'] != customerDisplayProtocolVersion) {
    return 'This display requires a protocol v2 pairing code.';
  }
  final host = value['host']?.toString().trim() ?? '';
  final port = value['port'];
  final token = value['pairingToken']?.toString() ?? '';
  final fingerprint = normalizeCertificateFingerprint(
    value['certificateFingerprint']?.toString() ?? '',
  );
  final expiresAt = DateTime.tryParse(value['expiresAt']?.toString() ?? '');
  if (!_isPrivateIpv4(host)) {
    return 'Pairing host is not a private IPv4 address.';
  }
  if (port is! int || port < 1024 || port > 65535) {
    return 'Invalid pairing port.';
  }
  if (_decodedLength(token) != 32) return 'Invalid pairing token.';
  if (fingerprint.length != 64) return 'Invalid certificate fingerprint.';
  if (expiresAt == null ||
      !expiresAt.toUtc().isAfter((now ?? DateTime.now()).toUtc())) {
    return 'Pairing code has expired.';
  }
  return null;
}

bool isValidPaymentMessage(
  Map<String, dynamic> message, {
  String? currentPaymentSessionId,
}) {
  final type = message['type'];
  if (type == 'SHOW_QR') {
    final session = message['paymentSessionId']?.toString().trim() ?? '';
    final qrData = message['qrData']?.toString() ?? '';
    final expiry = DateTime.tryParse(message['expiresAt']?.toString() ?? '');
    return session.isNotEmpty &&
        session.length <= 128 &&
        qrData.isNotEmpty &&
        qrData.length <= 8192 &&
        expiry != null;
  }
  if ({
    'CLEAR',
    'PAYMENT_SUCCESS',
    'PAYMENT_FAILED',
    'PAYMENT_EXPIRED',
  }.contains(type)) {
    final session = message['paymentSessionId']?.toString();
    return session == null ||
        currentPaymentSessionId == null ||
        session == currentPaymentSessionId;
  }
  return true;
}

int _decodedLength(String value) {
  try {
    return base64Url.decode(base64Url.normalize(value)).length;
  } on FormatException {
    return -1;
  }
}

bool _isPrivateIpv4(String value) {
  final parts = value.split('.').map(int.tryParse).toList();
  if (parts.length != 4 ||
      parts.any((part) => part == null || part < 0 || part > 255)) {
    return false;
  }
  if (parts[0] == 10 || (parts[0] == 192 && parts[1] == 168)) return true;
  return parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31;
}
