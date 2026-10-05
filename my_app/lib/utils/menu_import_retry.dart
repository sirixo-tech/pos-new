import 'dart:async';
import 'package:http/http.dart' as http;
import '../services/pos_api.dart';

/// Retry read-only status checks. Never retry upload/confirm mutations.
Duration? menuImportRetryDelay(Object error, int failures) {
  if (error is PosApiException) {
    final code = error.statusCode;
    if (code == 429) return error.retryAfter ?? const Duration(seconds: 45);
    if (code != 408 && (code == null || code < 500)) return null;
  } else if (error is! TimeoutException && error is! http.ClientException) {
    final text = error.toString().toLowerCase();
    if (!text.contains('socketexception') &&
        !text.contains('handshakeexception')) {
      return null;
    }
  }
  final exponent = failures.clamp(1, 4);
  return Duration(seconds: (3 * (1 << (exponent - 1))).clamp(3, 24));
}
