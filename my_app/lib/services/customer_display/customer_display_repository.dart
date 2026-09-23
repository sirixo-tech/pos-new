import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/platform_config.dart';
import '../../config/pos_app_info.dart';
import '../../models/pos_models.dart';
import '../../utils/platform_info.dart';
import 'customer_display_models.dart';

class CustomerDisplayException implements Exception {
  const CustomerDisplayException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CustomerDisplayRepository {
  CustomerDisplayRepository({http.Client? client})
      : _client = client ?? http.Client();

  static const _slugKey = 'customer_display_slug';
  static const _branchKey = 'customer_display_branch_id';
  static const _terminalKey = 'customer_display_terminal_code';
  static const _tokenKey = 'customer_display_sync_token';

  final http.Client _client;

  Future<CustomerDisplaySetup> readSetup({
    PosSession? session,
    PosBootstrap? bootstrap,
    PosTerminalInfo? terminal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final restaurant = bootstrap?.restaurant;
    final branch = bootstrap?.branch;
    return CustomerDisplaySetup(
      restaurantName: restaurant?.name.trim() ?? '',
      restaurantSlug: _firstNonEmpty([
        prefs.getString(_slugKey),
        _slugFrom(restaurant?.name ?? ''),
      ]),
      branchName: branch?.name.trim() ?? '',
      branchId: int.tryParse(prefs.getString(_branchKey) ?? '') ??
          session?.branchId ??
          branch?.id ??
          0,
      terminalCode: _firstNonEmpty([
        prefs.getString(_terminalKey),
        terminal?.code,
      ]),
      syncToken: _firstNonEmpty([
        prefs.getString(_tokenKey),
        terminal?.syncToken,
      ]),
    );
  }

  Future<void> saveSetup({
    required String restaurantSlug,
    required int branchId,
    required String terminalCode,
    required String syncToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_slugKey, _slugFrom(restaurantSlug));
    await prefs.setString(_branchKey, branchId.toString());
    await prefs.setString(_terminalKey, terminalCode.trim());
    await prefs.setString(_tokenKey, syncToken.trim());
  }

  Future<CustomerBoardSnapshot> pollBoard({
    required String serverUrl,
    required PosSession? session,
    required String restaurantSlug,
    required int branchId,
    required String terminalCode,
  }) async {
    final base = PlatformConfig.normalizeServerUrl(serverUrl);
    final encodedTerminal = Uri.encodeComponent(terminalCode);
    final authed = session == null
        ? null
        : _headers(session: session);
    final attempts = <Uri, Map<String, String>?>{
      Uri.parse('$base/api/v1/display/$branchId/$encodedTerminal/bootstrap'):
          authed,
      if (session != null)
        Uri.parse('${session.v1BaseUrl}/pos/recent-orders'): authed,
      if (session != null) Uri.parse('${session.v1BaseUrl}/board/orders'): authed,
      Uri.parse(
        '$base/api/v1/public/${Uri.encodeComponent(_slugFrom(restaurantSlug))}'
        '/board/$branchId/poll',
      ): <String, String>{
        'Accept': 'application/json',
        'X-Pos-Platform': posPlatformLabel(),
        'X-Pos-App-Version': PosAppInfo.version,
      },
    };

    Object? lastError;
    for (final entry in attempts.entries) {
      try {
        final response = await _client.get(entry.key, headers: entry.value);
        if (response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 404 ||
            response.statusCode == 405) {
          continue;
        }
        return CustomerBoardSnapshot.fromJson(_decode(response));
      } catch (error) {
        lastError = error;
      }
    }
    throw CustomerDisplayException(
      lastError?.toString() ??
          'Customer display is waiting for the server.',
    );
  }

  Future<CustomerCart> pollCart({
    required String serverUrl,
    required int branchId,
    required String terminalCode,
    required String syncToken,
  }) async {
    if (syncToken.trim().isEmpty) {
      throw const CustomerDisplayException(
        'Customer display terminal token is missing.',
      );
    }
    final base = PlatformConfig.normalizeServerUrl(serverUrl);
    final response = await _client.get(
      Uri.parse(
        '$base/api/v1/displays/sync/$branchId/'
        '${Uri.encodeComponent(terminalCode)}',
      ),
      headers: {
        'Accept': 'application/json',
        'X-Terminal-Token': syncToken.trim(),
        'X-Pos-Platform': posPlatformLabel(),
        'X-Pos-App-Version': PosAppInfo.version,
      },
    );
    return CustomerCart.fromJson(_decode(response));
  }

  Map<String, String> _headers({required PosSession session}) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${session.token}',
        'X-Restaurant-Id': '${session.restaurantId}',
        'X-Branch-Id': '${session.branchId}',
        'X-Pos-Platform': posPlatformLabel(),
        'X-Pos-App-Version': PosAppInfo.version,
      };

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      throw CustomerDisplayException(
        'Invalid server response (${response.statusCode}).',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw CustomerDisplayException(
      (body['message'] ?? body['error'] ?? 'Request failed (${response.statusCode}).')
          .toString(),
    );
  }
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _slugFrom(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
