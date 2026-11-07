import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  Uri? _workingUri;
  Map<String, String>? _workingHeaders;

  Future<CustomerDisplaySetup> readSetup({
    PosSession? session,
    StaffProfile? profile,
    PosBootstrap? bootstrap,
    PosTerminalInfo? terminal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bootstrapRestaurant = bootstrap?.restaurant;
    final bootstrapBranch = bootstrap?.branch;

    final selectedRestaurantId =
        session?.restaurantId ?? profile?.currentRestaurantId;
    final profileRestaurant = selectedRestaurantId != null
        ? profile?.restaurantOption(selectedRestaurantId)
        : (profile?.restaurants.isNotEmpty == true
            ? profile!.restaurants.first
            : null);

    final restaurantName = _firstNonEmpty([
      bootstrapRestaurant?.name,
      profileRestaurant?.name,
    ]);

    final restaurantSlug = _firstNonEmpty([
      prefs.getString(_slugKey),
      profileRestaurant?.slug,
      _slugFrom(restaurantName),
    ]);

    final selectedBranchId = int.tryParse(prefs.getString(_branchKey) ?? '') ??
        session?.branchId ??
        bootstrapBranch?.id ??
        profile?.currentBranchId ??
        0;

    StaffBranchOption? profileBranch;
    if (profileRestaurant != null) {
      for (final b in profileRestaurant.branches) {
        if (b.id == selectedBranchId) {
          profileBranch = b;
          break;
        }
      }
      profileBranch ??= profileRestaurant.branches.isNotEmpty
          ? profileRestaurant.branches.first
          : null;
    }

    final branchName = _firstNonEmpty([
      bootstrapBranch?.name,
      profileBranch?.name,
    ]);

    final finalBranchId = selectedBranchId > 0
        ? selectedBranchId
        : (profileBranch?.id ?? 0);

    return CustomerDisplaySetup(
      restaurantName: restaurantName,
      restaurantSlug: restaurantSlug,
      branchName: branchName,
      branchId: finalBranchId,
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

  void resetWorkingEndpoint() {
    _workingUri = null;
    _workingHeaders = null;
  }

  Future<void> saveSetup({
    required String restaurantSlug,
    required int branchId,
    required String terminalCode,
    required String syncToken,
  }) async {
    resetWorkingEndpoint();
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
    String? boardToken,
    String? kitchenToken,
  }) async {
    final base = PlatformConfig.normalizeServerUrl(serverUrl);
    final encodedTerminal = Uri.encodeComponent(terminalCode);
    final targetBranch = branchId > 0 ? branchId : session?.branchId ?? 0;
    final authed = session == null
        ? null
        : _headers(session: session);
    final boardHeaders = session == null
        ? null
        : (boardToken != null && boardToken.trim().isNotEmpty
            ? {
                ..._headers(session: session),
                'Authorization': 'Bearer ${boardToken.trim()}',
              }
            : authed);
    final kitchenHeaders = session == null
        ? null
        : (kitchenToken != null && kitchenToken.trim().isNotEmpty
            ? {
                ..._headers(session: session),
                'Authorization': 'Bearer ${kitchenToken.trim()}',
              }
            : authed);

    final normalizedSlug = restaurantSlug.trim().isNotEmpty
        ? _slugFrom(restaurantSlug)
        : '';

    // Fast path: if a working board endpoint was already discovered, query it directly.
    if (_workingUri != null) {
      try {
        final response = await _client.get(_workingUri!, headers: _workingHeaders);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = _decode(response);
          return CustomerBoardSnapshot.fromJson(decoded);
        }
        // If status >= 300, clear working URI and fall through to re-discover candidates.
        _workingUri = null;
        _workingHeaders = null;
      } catch (_) {
        _workingUri = null;
        _workingHeaders = null;
      }
    }

    final attempts = <Uri, Map<String, String>?>{
      // 1. Primary dedicated Order Board / Token Display endpoints
      if (normalizedSlug.isNotEmpty && targetBranch > 0)
        Uri.parse(
          '$base/api/v1/public/${Uri.encodeComponent(normalizedSlug)}'
          '/board/$targetBranch/poll',
        ): <String, String>{
          'Accept': 'application/json',
          'X-Pos-Platform': posPlatformLabel(),
          'X-Pos-App-Version': PosAppInfo.version,
          if (session != null) 'X-Restaurant-Id': '${session.restaurantId}',
          if (session != null) 'X-Branch-Id': '${session.branchId}',
        },

      if (targetBranch > 0) ...{
        Uri.parse('$base/api/v1/public/board/$targetBranch/poll'): <String, String>{
          'Accept': 'application/json',
          'X-Pos-Platform': posPlatformLabel(),
          'X-Pos-App-Version': PosAppInfo.version,
          if (session != null) 'X-Restaurant-Id': '${session.restaurantId}',
          if (session != null) 'X-Branch-Id': '${session.branchId}',
        },
        if (session != null)
          Uri.parse('$base/api/v1/board/$targetBranch/poll'): authed,
      },

      // 2. Authenticated Board Endpoints
      if (session != null && boardHeaders != null) ...{
        Uri.parse('${session.v1BaseUrl}/board/orders'): boardHeaders,
        if (targetBranch > 0) ...{
          Uri.parse('${session.v1BaseUrl}/board/orders?branch_id=$targetBranch'):
              boardHeaders,
          Uri.parse('${session.v1BaseUrl}/board/orders?branch=$targetBranch'):
              boardHeaders,
          Uri.parse('${session.v1BaseUrl}/board/$targetBranch/orders'): boardHeaders,
        },
        if (session.restaurantId > 0 && targetBranch > 0)
          Uri.parse(
            '${session.v1BaseUrl}/board/orders?restaurant_id=${session.restaurantId}&branch_id=$targetBranch',
          ): boardHeaders,
        Uri.parse('${session.v1BaseUrl}/order-board/orders'): boardHeaders,
        if (targetBranch > 0) ...{
          Uri.parse('${session.v1BaseUrl}/order-board/orders?branch_id=$targetBranch'):
              boardHeaders,
          Uri.parse('${session.v1BaseUrl}/order-board/$targetBranch/orders'):
              boardHeaders,
        },
        Uri.parse('${session.v1BaseUrl}/token-display/orders'): boardHeaders,
        if (targetBranch > 0)
          Uri.parse('${session.v1BaseUrl}/token-display/$targetBranch/orders'):
              boardHeaders,
      },
      if (session != null && authed != null && boardHeaders != authed) ...{
        Uri.parse('${session.v1BaseUrl}/board/orders'): authed,
        if (targetBranch > 0) ...{
          Uri.parse('${session.v1BaseUrl}/board/orders?branch_id=$targetBranch'):
              authed,
          Uri.parse('${session.v1BaseUrl}/board/$targetBranch/orders'): authed,
        },
      },

      // 3. Kitchen orders (when kitchen token or kitchen access is available)
      if (session != null && kitchenHeaders != null) ...{
        Uri.parse('${session.v1BaseUrl}/kitchen/orders'): kitchenHeaders,
        if (targetBranch > 0)
          Uri.parse('${session.v1BaseUrl}/kitchen/orders?branch_id=$targetBranch'):
              kitchenHeaders,
      },
      if (session != null && authed != null && kitchenHeaders != authed) ...{
        Uri.parse('${session.v1BaseUrl}/kitchen/orders'): authed,
        if (targetBranch > 0)
          Uri.parse('${session.v1BaseUrl}/kitchen/orders?branch_id=$targetBranch'):
              authed,
      },

      // 4. Fallback to POS recent/open orders if permitted
      if (session != null) ...{
        Uri.parse('${session.v1BaseUrl}/pos/recent-orders'): authed,
        Uri.parse('${session.v1BaseUrl}/pos/open-orders'): authed,
      },

      // 5. Paired Display Terminal bootstrap
      if (targetBranch > 0 && terminalCode.trim().isNotEmpty)
        Uri.parse('$base/api/v1/display/$targetBranch/$encodedTerminal/bootstrap'):
            authed,
    };

    Object? lastError;
    final failedDiagnostics = <String>[];
    for (final entry in attempts.entries) {
      try {
        final response = await _client.get(entry.key, headers: entry.value);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final queryPart = entry.key.hasQuery ? '?${entry.key.query}' : '';
          debugPrint(
            '[CustomerDisplayRepository] poll connected via ${entry.key.path}$queryPart',
          );
          _workingUri = entry.key;
          _workingHeaders = entry.value;
          final decoded = _decode(response);
          return CustomerBoardSnapshot.fromJson(decoded);
        }
        lastError = 'HTTP ${response.statusCode} from ${entry.key.path}';
        final queryPart = entry.key.hasQuery ? '?${entry.key.query}' : '';
        failedDiagnostics.add(
          'poll attempt ${entry.key.path}$queryPart returned ${response.statusCode}: ${response.body}',
        );
      } catch (error) {
        lastError = error;
        failedDiagnostics.add('poll attempt ${entry.key.path} failed: $error');
      }
    }
    for (final diag in failedDiagnostics) {
      debugPrint('[CustomerDisplayRepository] $diag');
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
      if (decoded is List) {
        body = {'data': decoded};
      } else if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
      } else {
        body = <String, dynamic>{};
      }
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
