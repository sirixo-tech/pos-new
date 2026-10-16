import 'dart:convert';

import 'package:customer_display_android/customer_display_protocol_v2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> validPayload() => {
    'type': 'SELFX_CUSTOMER_DISPLAY',
    'version': customerDisplayProtocolVersion,
    'host': '192.168.1.25',
    'port': 8081,
    'transport': 'wifi',
    'pairingToken': base64UrlEncode(
      List<int>.filled(32, 7),
    ).replaceAll('=', ''),
    'expiresAt': '2030-01-01T00:00:00.000Z',
    'certificateFingerprint': List<String>.filled(64, 'a').join(),
  };

  test('decodes a plain POS pairing payload', () {
    final decoded = decodePairingPayload(jsonEncode(validPayload()));

    expect(validatePairingPayload(decoded, now: DateTime.utc(2029)), isNull);
  });

  test('recovers JSON surrounded by Android scanner transport text', () {
    final raw = '\uFEFFQR_RESULT\u0000${jsonEncode(validPayload())}\u0000END';

    final decoded = decodePairingPayload(raw);

    expect(decoded['type'], 'SELFX_CUSTOMER_DISPLAY');
    expect(decoded['host'], '192.168.1.25');
  });
}
