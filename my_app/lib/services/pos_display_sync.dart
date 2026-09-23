import 'dart:convert';

import 'package:http/http.dart' as http;

/// Mirrors the in-progress POS cart to the customer display for a terminal.
/// Same API as web POS: POST push, DELETE clear on `/api/v1/displays/sync/...`.
class PosDisplaySync {
  PosDisplaySync({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String _normalizeServerUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri _syncUri(String serverUrl, int branchId, String terminalCode) {
    final base = _normalizeServerUrl(serverUrl);
    return Uri.parse(
      '$base/api/v1/displays/sync/$branchId/${Uri.encodeComponent(terminalCode.toUpperCase())}',
    );
  }

  Map<String, String> _headers(String syncToken) => {
        'Accept': 'application/json',
        'X-Terminal-Token': syncToken,
      };

  Future<void> pushCart({
    required String serverUrl,
    required int branchId,
    required String terminalCode,
    required String syncToken,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _client.post(
        _syncUri(serverUrl, branchId, terminalCode),
        headers: {
          ..._headers(syncToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } catch (_) {
      // Best-effort mirror — same as web POS (.catch(() => {})).
    }
  }

  Future<void> clearCart({
    required String serverUrl,
    required int branchId,
    required String terminalCode,
    required String syncToken,
  }) async {
    try {
      await _client.delete(
        _syncUri(serverUrl, branchId, terminalCode),
        headers: _headers(syncToken),
      );
    } catch (_) {}
  }
}
