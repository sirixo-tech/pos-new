import '../l10n/pos_translation_store.dart';
import '../services/pos_api.dart';

/// Staff-safe error copy for toasts and banners.
///
/// Never surfaces URLs, `/api/` paths, stack traces, or raw exception types.
String posUserFacingError(Object? error, {String? fallback}) {
  final store = PosTranslationStore.instance;
  final generic = fallback ??
      store.text(
        'errorGeneric',
        'Something went wrong. Please try again.',
      );
  final network = store.text(
    'errorNetwork',
    'Could not reach the server. Check your connection and try again.',
  );
  final badResponse = store.text(
    'errorBadResponse',
    'The server returned an unexpected response. Try again, or check the server URL.',
  );

  if (error == null) return generic;

  final statusCode = error is PosApiException ? error.statusCode : null;
  final message = error is PosApiException
      ? error.message.trim()
      : error
          .toString()
          .replaceFirst(RegExp(r'^(Exception|Error|Bad state):\s*'), '')
          .trim();

  if (message.isEmpty) return generic;
  if (_isNetworkFailureMessage(message)) return network;

  final httpStatus = statusCode ?? _statusFromMessage(message);
  if (httpStatus != null) {
    if (httpStatus == 401 || httpStatus == 422) {
      // Prefer the API's own validation / auth copy when it is staff-safe.
      if (message.isNotEmpty &&
          !_leaksInternalDetails(message) &&
          !_looksTechnical(message) &&
          message.length <= 160) {
        return message;
      }
      return store.text(
        'authFailed',
        'Sign-in failed. Check your email and password.',
      );
    }
    if (httpStatus == 403) {
      if (message.isNotEmpty &&
          !_leaksInternalDetails(message) &&
          !_looksTechnical(message) &&
          message.length <= 160) {
        return message;
      }
      return store.text(
        'errorForbidden',
        'You do not have access to this restaurant on the POS.',
      );
    }
    if (httpStatus == 404) {
      return store.text(
        'errorNotFound',
        'Server endpoint not found. Check the server URL and app version.',
      );
    }
    if (httpStatus >= 500) {
      return store.text(
        'errorServer',
        'The server had a problem. Please try again in a moment.',
      );
    }
    if (_isOpaqueHttpFailureMessage(message)) {
      return badResponse;
    }
  }

  if (_isOpaqueHttpFailureMessage(message)) return badResponse;
  if (_leaksInternalDetails(message)) return generic;

  // Short human validation / business messages from the API are OK.
  if (message.length <= 160 && !_looksTechnical(message)) {
    return message;
  }

  return generic;
}

bool _isOpaqueHttpFailureMessage(String message) {
  final m = message.toLowerCase();
  return RegExp(r'request failed\s*\(\d{3}\)').hasMatch(m) ||
      RegExp(r'invalid server response\s*\(\d{3}\)').hasMatch(m);
}

int? _statusFromMessage(String message) {
  final match = RegExp(
    r'(?:request failed|invalid server response)\s*\((\d{3})\)',
    caseSensitive: false,
  ).firstMatch(message);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

bool _isNetworkFailureMessage(String message) {
  final m = message.toLowerCase();
  return m.contains('socketexception') ||
      m.contains('clientexception') ||
      m.contains('handshakeexception') ||
      m.contains('certificate') ||
      m.contains('ssl') ||
      m.contains('tls') ||
      m.contains('failed host lookup') ||
      m.contains('connection refused') ||
      m.contains('connection reset') ||
      m.contains('network is unreachable') ||
      m.contains('network access blocked') ||
      m.contains('operation not permitted') ||
      m.contains('timed out') ||
      m.contains('timeout') ||
      m.contains('cannot reach') ||
      m.contains('cannot connect') ||
      m.contains('could not reach') ||
      m.contains('could not connect') ||
      m.contains('check your network') ||
      m.contains('check your connection');
}

bool _leaksInternalDetails(String message) {
  final m = message.toLowerCase();
  return m.contains('http://') ||
      m.contains('https://') ||
      m.contains('/api/') ||
      m.contains('api/v1') ||
      m.contains('localhost') ||
      m.contains('127.0.0.1') ||
      m.contains('socketexception') ||
      m.contains('clientexception') ||
      m.contains('handshakeexception') ||
      m.contains('sqlstate') ||
      m.contains('stack trace') ||
      m.contains('fluttererror') ||
      m.contains('#0 ') ||
      m.contains('posapiexception') ||
      RegExp(r'request failed\s*\(\d{3}\)').hasMatch(m) ||
      RegExp(r'invalid server response\s*\(\d{3}\)').hasMatch(m) ||
      (m.contains('{') && m.contains('}'));
}

bool _looksTechnical(String message) {
  final m = message.toLowerCase();
  return m.contains('exception') ||
      m.contains('error:') ||
      m.contains('null check') ||
      m.contains('typeerror') ||
      m.contains('formatexception') ||
      m.contains('nosuchmethod') ||
      RegExp(r'\bat\s+\S+\.\S+').hasMatch(m);
}
