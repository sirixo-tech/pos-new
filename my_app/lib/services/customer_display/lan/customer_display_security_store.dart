import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'customer_display_tls_material.dart';

export 'customer_display_tls_material.dart';

class PairedDisplayCredential {
  const PairedDisplayCredential({
    required this.deviceId,
    required this.deviceName,
    required this.secret,
    required this.pairedAt,
  });

  final String deviceId;
  final String deviceName;
  final String secret;
  final DateTime pairedAt;

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'secret': secret,
    'pairedAt': pairedAt.toUtc().toIso8601String(),
  };

  factory PairedDisplayCredential.fromJson(Map<String, dynamic> json) {
    return PairedDisplayCredential(
      deviceId: json['deviceId']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? 'QR Display',
      secret: json['secret']?.toString() ?? '',
      pairedAt:
          DateTime.tryParse(json['pairedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class CustomerDisplaySecurityStore {
  CustomerDisplaySecurityStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _certificateKey = 'customer_display_v2_tls_certificate';
  static const _privateKeyKey = 'customer_display_v2_tls_private_key';
  static const _pairedDevicesKey = 'customer_display_v2_paired_devices';

  final FlutterSecureStorage _storage;

  Future<CustomerDisplayTlsMaterial> loadOrCreateTlsMaterial() async {
    final values = await Future.wait([
      _storage.read(key: _certificateKey),
      _storage.read(key: _privateKeyKey),
    ]);
    final certificate = values[0];
    final privateKey = values[1];
    if (certificate != null &&
        certificate.isNotEmpty &&
        privateKey != null &&
        privateKey.isNotEmpty) {
      return CustomerDisplayTlsMaterial(
        certificatePem: certificate,
        privateKeyPem: privateKey,
        fingerprint: customerDisplayCertificateFingerprint(certificate),
      );
    }

    final generated = await Isolate.run(generateCustomerDisplayTlsMaterial);
    await _storage.write(key: _certificateKey, value: generated.certificatePem);
    await _storage.write(key: _privateKeyKey, value: generated.privateKeyPem);
    // A regenerated certificate invalidates every previous certificate pin.
    await _storage.delete(key: _pairedDevicesKey);
    return generated;
  }

  Future<Map<String, PairedDisplayCredential>> loadPairedDevices() async {
    final raw = await _storage.read(key: _pairedDevicesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, PairedDisplayCredential>{};
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final credential = PairedDisplayCredential.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (credential.deviceId.isNotEmpty && credential.secret.isNotEmpty) {
          result[entry.key.toString()] = credential;
        }
      }
      return result;
    } on Object {
      await _storage.delete(key: _pairedDevicesKey);
      return {};
    }
  }

  Future<void> savePairedDevices(Map<String, PairedDisplayCredential> devices) {
    return _storage.write(
      key: _pairedDevicesKey,
      value: jsonEncode({
        for (final entry in devices.entries) entry.key: entry.value.toJson(),
      }),
    );
  }

  Future<void> removePairedDevice(String deviceId) async {
    final devices = await loadPairedDevices();
    if (devices.remove(deviceId) != null) {
      await savePairedDevices(devices);
    }
  }
}
