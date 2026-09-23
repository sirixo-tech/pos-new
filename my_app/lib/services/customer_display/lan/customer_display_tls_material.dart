import 'dart:convert';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

class CustomerDisplayTlsMaterial {
  const CustomerDisplayTlsMaterial({
    required this.certificatePem,
    required this.privateKeyPem,
    required this.fingerprint,
  });

  final String certificatePem;
  final String privateKeyPem;
  final String fingerprint;
}

CustomerDisplayTlsMaterial generateCustomerDisplayTlsMaterial() {
  final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  final privateKey = pair.privateKey as RSAPrivateKey;
  final publicKey = pair.publicKey as RSAPublicKey;
  final subject = <String, String>{'CN': 'selfx-pos.local'};
  final csr = X509Utils.generateRsaCsrPem(subject, privateKey, publicKey);
  final certificate = X509Utils.generateSelfSignedCertificate(
    privateKey,
    csr,
    3650,
    serialNumber: _securePositiveSerial().toString(),
    notBefore: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
  );
  final privatePem = CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey);
  return CustomerDisplayTlsMaterial(
    certificatePem: certificate,
    privateKeyPem: privatePem,
    fingerprint: customerDisplayCertificateFingerprint(certificate),
  );
}

BigInt _securePositiveSerial() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[0] &= 0x7f;
  bytes[0] |= 0x01;
  return BigInt.parse(
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );
}

String customerDisplayCertificateFingerprint(String pem) {
  final body = pem
      .replaceAll('-----BEGIN CERTIFICATE-----', '')
      .replaceAll('-----END CERTIFICATE-----', '')
      .replaceAll(RegExp(r'\s'), '');
  return sha256.convert(base64.decode(body)).toString().toLowerCase();
}
