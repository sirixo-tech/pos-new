import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;

import '../config/platform_config.dart';
import '../config/pos_app_info.dart';
import '../l10n/pos_translation_store.dart';
import '../models/admin_models.dart';
import '../models/billing_models.dart';
import '../models/kitchen_models.dart';
import '../models/pos_models.dart';
import '../utils/json_parse.dart';
import '../utils/kitchen_board.dart';
import '../utils/platform_info.dart';

class PosApiException implements Exception {
  PosApiException(
    this.message, {
    this.statusCode,
    this.retryAfter,
    this.trialExpired = false,
    this.subscriptionInactive = false,
    this.canManageBilling = false,
    this.billingSelfServe = false,
    this.coveredByOrganization = false,
  });

  final String message;
  final int? statusCode;
  final Duration? retryAfter;
  final bool trialExpired;
  final bool subscriptionInactive;
  final bool canManageBilling;
  final bool billingSelfServe;
  final bool coveredByOrganization;

  bool get isSubscriptionBlocked => trialExpired || subscriptionInactive;

  bool get isPrintingDisabled {
    if (statusCode == 401 || statusCode == 403) return false;
    if (statusCode != null &&
        (statusCode! < 400 || statusCode! >= 500) &&
        statusCode != 404) {
      return false;
    }
    final text = message.toLowerCase();
    if (text.contains('no print object') ||
        text.contains('no printable content')) {
      return true;
    }
    return text.contains('nothing to print') &&
        text.contains('disabled') &&
        (text.contains('receipt') ||
            text.contains('kot') ||
            text.contains('kitchen'));
  }

  @override
  String toString() => message;
}

class StaffLoginResult {
  StaffLoginResult({required this.session, required this.profile});

  final PosSession session;
  final StaffProfile profile;
}

class PosApi {
  PosApi({http.Client? client}) : _client = client ?? http.Client();

  static String get appVersion => PosAppInfo.version;

  final http.Client _client;

  String _normalizeServerUrl(String url) => PlatformConfig.normalizeServerUrl(url);

  String get _defaultBase => _normalizeServerUrl(PlatformConfig.platformUrl);

  Map<String, String> _jsonHeaders({
    String? token,
    int? restaurantId,
    int? branchId,
  }) =>
      {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Pos-Platform': posPlatformLabel(),
        'X-Pos-App-Version': appVersion,
        if (token != null) 'Authorization': 'Bearer $token',
        if (restaurantId != null) 'X-Restaurant-Id': '$restaurantId',
        if (branchId != null) 'X-Branch-Id': '$branchId',
      };

  Future<StaffLoginResult> login({
    required String serverUrl,
    required String email,
    required String password,
    int? restaurantId,
    int? branchId,
  }) async {
    final base = _normalizeServerUrl(serverUrl);
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$base/api/v1/auth/login'),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
          'token_ability': 'pos',
          'device_name': '${PosAppInfo.displayName} (${posPlatformLabel()})',
          if (restaurantId != null) 'restaurant_id': restaurantId,
          if (branchId != null) 'branch_id': branchId,
        }),
      );
    } catch (e) {
      throw PosApiException(_networkErrorMessage(e));
    }

    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'authLoginNoToken',
          'Login did not return a token.',
        ),
      );
    }

    final profile = StaffProfile.fromJson(data);
    final restaurantIdResolved = profile.currentRestaurantId;
    final branchIdResolved = profile.currentBranchId;

    if (restaurantIdResolved == null || branchIdResolved == null) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'authNoRestaurantBranch',
          'No restaurant or branch assigned to this account.',
        ),
      );
    }

    return StaffLoginResult(
      session: PosSession(
        serverUrl: base,
        token: token,
        restaurantId: restaurantIdResolved,
        branchId: branchIdResolved,
        userId: profile.user.id,
        userName: profile.user.name,
        userEmail: profile.user.email,
        hasPosPin: profile.user.hasPosPin,
      ),
      profile: profile,
    );
  }

  Future<StaffProfile> fetchMe(PosSession session) async {
    final response = await _client.get(
      Uri.parse('${session.authBaseUrl}/me'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return StaffProfile.fromJson(data);
  }

  Future<StaffProfile> switchRestaurant(PosSession session, int restaurantId) async {
    final response = await _client.post(
      Uri.parse('${session.authBaseUrl}/switch-restaurant'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({'restaurant_id': restaurantId}),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return StaffProfile.fromJson(data);
  }

  Future<StaffProfile> switchBranch(PosSession session, int branchId) async {
    final response = await _client.post(
      Uri.parse('${session.authBaseUrl}/switch-branch'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({'branch_id': branchId}),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return StaffProfile.fromJson(data);
  }

  Future<void> verifyPosPin(PosSession session, String pin) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${session.authBaseUrl}/verify-pos-pin'),
            headers: _jsonHeaders(
              token: session.token,
              restaurantId: session.restaurantId,
              branchId: session.branchId,
            ),
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw PosApiException(
        _networkErrorMessage(Exception('timeout')),
      );
    } catch (e) {
      throw PosApiException(_networkErrorMessage(e));
    }
    await _decode(response);
  }

  Future<void> setPosPin(
    PosSession session, {
    required String pin,
    required String currentPassword,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.authBaseUrl}/set-pos-pin'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'pin': pin,
        'current_password': currentPassword,
      }),
    );
    await _decode(response);
  }

  Future<PosPairingStartResult> startPairing(String serverUrl) async {
    final base = _normalizeServerUrl(serverUrl);
    final response = await _client.post(
      Uri.parse('$base/api/v1/pos/pairing/start'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'platform': posPlatformLabel(),
        'app_version': appVersion,
      }),
    );
    final json = await _decode(response);
    return PosPairingStartResult.fromJson(json);
  }

  Future<Map<String, dynamic>> pollPairing(
    String serverUrl,
    String deviceUuid,
  ) async {
    final base = _normalizeServerUrl(serverUrl);
    final uri = Uri.parse('$base/api/v1/pos/pairing/status').replace(
      queryParameters: {'device_uuid': deviceUuid},
    );
    final response = await _client.get(uri, headers: _jsonHeaders());
    return _decode(response);
  }

  Future<void> logout(PosSession session) async {
    await _client.post(
      Uri.parse('${session.authBaseUrl}/logout'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
  }

  Map<String, String> get _clientVersionQuery => {
        'platform': posPlatformLabel(),
        'app_version': PosAppInfo.version,
        'build_number': PosAppInfo.buildNumber,
      };

  Future<PosBootstrap> bootstrap(PosSession session) async {
    final uri = Uri.parse('${session.apiBaseUrl}/bootstrap').replace(
      queryParameters: _clientVersionQuery,
    );
    final response = await _client.get(
      uri,
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return PosBootstrap.fromJson(data);
  }

  Future<PosBillingCatalog> fetchBilling(PosSession session) async {
    final response = await _client.get(
      Uri.parse('${session.v1BaseUrl}/billing'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    return PosBillingCatalog.fromJson(_unwrapData(await _decode(response)));
  }

  Future<PosBillingCheckoutResult> checkoutBilling(
    PosSession session, {
    required int planId,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.v1BaseUrl}/billing/checkout'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({'plan_id': planId}),
    );
    final data = _unwrapData(await _decode(response));
    return PosBillingCheckoutResult(
      activated: data['activated'] == true,
      checkoutUrl: data['checkout_url']?.toString(),
    );
  }

  Future<PosSyncStatus> fetchSync(PosSession session) async {
    final uri = Uri.parse('${session.apiBaseUrl}/sync').replace(
      queryParameters: _clientVersionQuery,
    );
    final response = await _client.get(
      uri,
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return PosSyncStatus.fromJson(data);
  }

  Future<List<MenuItem>> fetchCheckoutUpsells(
    PosSession session, {
    required List<int> menuItemIds,
  }) async {
    if (menuItemIds.isEmpty) {
      return [];
    }
    final query = menuItemIds.map((id) => 'menu_item_ids[]=$id').join('&');
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/checkout-upsells?$query'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return (data['items'] as List<dynamic>? ?? [])
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PosShift> openShift(
    PosSession session, {
    required double openingFloat,
    String? notes,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/shift/open'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'opening_float': openingFloat,
        if (notes != null && notes.isNotEmpty) 'notes_opening': notes,
      }),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final shift = data['shift'] as Map<String, dynamic>?;
    if (shift == null) {
      throw PosApiException('Shift open did not return shift data.');
    }
    return PosShift.fromJson(shift);
  }

  Future<PosShiftCloseSummary> fetchShiftCloseSummary(PosSession session) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/shift/summary'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final summary = data['summary'] as Map<String, dynamic>?;
    if (summary == null) {
      throw PosApiException('Could not load shift close summary.');
    }
    return PosShiftCloseSummary.fromJson(summary);
  }

  Future<void> closeShift(
    PosSession session, {
    required double closingCash,
    String? notes,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/shift/close'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'closing_cash': closingCash,
        if (notes != null && notes.isNotEmpty) 'notes_closing': notes,
      }),
    );
    await _decode(response);
  }

  Future<Map<String, dynamic>> fetchTables(PosSession session) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/tables'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<Map<String, dynamic>> updateTableStatus(
    PosSession session, {
    required int tableId,
    required String status,
  }) async {
    final response = await _client.patch(
      Uri.parse('${session.apiBaseUrl}/tables/$tableId/status'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({'status': status}),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<List<Map<String, dynamic>>> searchCustomers(
    PosSession session, {
    String query = '',
  }) async {
    final uri = Uri.parse('${session.apiBaseUrl}/customers/search').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final response = await _client.get(
      uri,
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return (data['customers'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const [];
  }

  Future<Map<String, dynamic>> createCustomer(
    PosSession session, {
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/customers'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'name': name.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      }),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final customer = data['customer'];
    if (customer is Map) {
      return Map<String, dynamic>.from(customer);
    }
    throw PosApiException('Customer was created but the response was empty.');
  }

  Future<PlacedPosOrder> createOrder(
    PosSession session, {
    required List<Map<String, dynamic>> items,
    required String type,
    required Map<String, dynamic> payment,
    int? posTerminalId,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
    String? idempotencyKey,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/orders'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'items': items,
        'type': type,
        if (posTerminalId != null) 'pos_terminal_id': posTerminalId,
        if (tableId != null) 'table_id': tableId,
        if (customerId != null) 'customer_id': customerId,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (discount != null) 'discount': discount,
        'pos_register_payment': payment,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      }),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final order = data['order'] as Map<String, dynamic>?;
    if (order == null) {
      throw PosApiException('Order response missing order payload.');
    }
    final paymentPayload = data['payment'];
    return PlacedPosOrder.fromJson({
      ...order,
      if (paymentPayload is Map<String, dynamic>) 'payment': paymentPayload,
    });
  }

  /// Recent branch orders for the in-POS orders list.
  Future<Map<String, dynamic>> fetchRecentOrders(
    PosSession session, {
    String filter = 'today',
    String? query,
    String? status,
    String? source,
    int page = 1,
    int perPage = 10,
  }) async {
    final uri = Uri.parse('${session.apiBaseUrl}/recent-orders').replace(
      queryParameters: {
        'filter': filter,
        'page': '$page',
        'per_page': '$perPage',
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (source != null && source.isNotEmpty) 'source': source,
      },
    );
    final response = await _client.get(
      uri,
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  /// Held / parked POS draft tickets waiting to be resumed.
  Future<List<Map<String, dynamic>>> fetchOpenOrders(PosSession session) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/open-orders'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return (data['orders'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const [];
  }

  /// Unpaid floor / captain tickets (separate from register Held).
  Future<List<Map<String, dynamic>>> fetchFloorOrders(PosSession session) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/floor-orders'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return (data['orders'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const [];
  }

  /// New-order poll (baseline or since_id), same idea as admin web POS alerts.
  Future<Map<String, dynamic>> fetchNewOrders(
    PosSession session, {
    int? sinceId,
    bool baseline = false,
  }) async {
    final params = <String, String>{};
    if (baseline) {
      params['baseline'] = '1';
    } else if (sinceId != null) {
      params['since_id'] = '$sinceId';
    }
    final uri = Uri.parse('${session.apiBaseUrl}/new-orders').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await _client.get(
      uri,
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  /// Full held-ticket payload for resume (cart + form).
  Future<Map<String, dynamic>> fetchOrderForResume(
    PosSession session, {
    required int orderId,
    bool forAppend = false,
  }) async {
    final uri = Uri.parse('${session.apiBaseUrl}/orders/$orderId').replace(
      queryParameters: forAppend ? const {'purpose': 'append'} : null,
    );
    final response = await _client.get(
      uri,
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  /// Read-only order detail for the POS order detail modal (admin-shaped).
  Future<Map<String, dynamic>> fetchOrderForView(
    PosSession session, {
    required int orderId,
  }) async {
    final uri = Uri.parse('${session.apiBaseUrl}/orders/$orderId').replace(
      queryParameters: const {'purpose': 'view'},
    );
    final response = await _client.get(
      uri,
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final order = data['order'];
    if (order is Map) {
      return Map<String, dynamic>.from(order);
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    PosSession session, {
    required int orderId,
    required String status,
    bool refund = false,
    String? cancelReason,
    String? cancelNote,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (status == 'cancelled' && refund) {
      body['refund'] = true;
    }
    if (status == 'cancelled' && cancelReason != null && cancelReason.isNotEmpty) {
      body['cancel_reason'] = cancelReason;
    }
    if (status == 'cancelled' && cancelNote != null && cancelNote.isNotEmpty) {
      body['cancel_note'] = cancelNote;
    }
    final response = await _client.patch(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/status'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode(body),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<Map<String, dynamic>> fetchOrderPayments(
    PosSession session, {
    required int orderId,
  }) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/payments'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<Map<String, dynamic>> addOrderPayment(
    PosSession session, {
    required int orderId,
    required double amount,
    required String method,
    String? note,
    double? cashTendered,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/payments'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'amount': amount,
        'method': method,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (cashTendered != null) 'cash_tendered': cashTendered,
      }),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<Map<String, dynamic>> payOrder(
    PosSession session, {
    required int orderId,
    required Map<String, dynamic> payment,
    List<Map<String, dynamic>>? items,
    String? type,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/pay'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'pos_register_payment': payment,
        if (items != null) 'items': items,
        if (type != null && type.isNotEmpty) 'type': type,
        if (tableId != null) 'table_id': tableId,
        if (customerId != null) 'customer_id': customerId,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (discount != null) 'discount': discount,
      }),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<PosOrderPaymentInfo> fetchPaymentQr(
    PosSession session, {
    required int orderId,
  }) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/payment/qr'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return PosOrderPaymentInfo.fromJson({
      'type': 'dynamic_qr',
      'gateway': data['gateway'],
      'timeout_seconds': data['timeout_seconds'],
      'amount': data['amount'] ?? data['amount_due'],
      'qr': data['qr'],
    });
  }

  Future<Map<String, dynamic>> fetchPaymentStatus(
    PosSession session, {
    required int orderId,
  }) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/payment/status'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<Map<String, dynamic>> fetchPaymentQrPrintObject(
    PosSession session, {
    required int orderId,
  }) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/payment/qr/print'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<Map<String, dynamic>> fetchReceipt(
    PosSession session, {
    required int orderId,
  }) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/receipt'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return data;
  }

  /// Receipt by order number (scan-to-print) — same endpoint as [fetchReceipt].
  Future<Map<String, dynamic>> fetchReceiptByOrderNumber(
    PosSession session, {
    required String orderNumber,
    bool handoff = false,
  }) async {
    var uri = Uri.parse('${session.apiBaseUrl}/orders/$orderNumber/receipt');
    if (handoff) {
      uri = uri.replace(queryParameters: const {'handoff': '1'});
    }
    final response = await _client.get(
      uri,
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return data;
  }

  /// KOT slips by order number — print_object per kitchen for local thermal.
  Future<Map<String, dynamic>> fetchKotByOrderNumber(
    PosSession session, {
    required String orderNumber,
  }) async {
    final response = await _client.get(
      Uri.parse('${session.apiBaseUrl}/orders/$orderNumber/kot'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return data;
  }

  Future<PlacedPosOrder> parkOrder(
    PosSession session, {
    required List<Map<String, dynamic>> items,
    required String type,
    int? posTerminalId,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/orders/park'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'items': items,
        'type': type,
        if (posTerminalId != null) 'pos_terminal_id': posTerminalId,
        if (tableId != null) 'table_id': tableId,
        if (customerId != null) 'customer_id': customerId,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (discount != null) 'discount': discount,
      }),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final order = data['order'] as Map<String, dynamic>?;
    if (order == null) {
      throw PosApiException('Park response missing order payload.');
    }
    return PlacedPosOrder.fromJson(order);
  }

  Future<PlacedPosOrder> sendToKitchen(
    PosSession session, {
    required List<Map<String, dynamic>> items,
    required String type,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/orders/send-to-kitchen'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'items': items,
        'type': type,
        if (tableId != null) 'table_id': tableId,
        if (customerId != null) 'customer_id': customerId,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (discount != null) 'discount': discount,
      }),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final order = data['order'] as Map<String, dynamic>?;
    if (order == null) {
      throw PosApiException('Send to kitchen response missing order payload.');
    }
    return PlacedPosOrder.fromJson(order);
  }

  Future<PlacedPosOrder> appendToKitchen(
    PosSession session, {
    required int orderId,
    required List<Map<String, dynamic>> items,
    required String type,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/send-to-kitchen'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'items': items,
        'type': type,
        if (tableId != null) 'table_id': tableId,
        if (customerId != null) 'customer_id': customerId,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (discount != null) 'discount': discount,
      }),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final order = data['order'] as Map<String, dynamic>?;
    if (order == null) {
      throw PosApiException('Append to kitchen response missing order payload.');
    }
    return PlacedPosOrder.fromJson(order);
  }

  Future<Map<String, dynamic>> requestBill(
    PosSession session, {
    required int orderId,
    String mode = 'full',
    List<int>? orderItemIds,
    int? parts,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'mode': mode,
      if (orderItemIds != null && orderItemIds.isNotEmpty)
        'order_item_ids': orderItemIds,
      if (parts != null) 'parts': parts,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/request-bill'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode(body),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<Map<String, dynamic>> clearBillRequest(
    PosSession session, {
    required int orderId,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/clear-bill-request'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode(const {}),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  /// Captain run-food: mark ready kitchen ticket(s) as served/delivered.
  Future<Map<String, dynamic>> markServed(
    PosSession session, {
    required int orderId,
    int? kitchenTicketId,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId/mark-served'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        if (kitchenTicketId != null) 'kitchen_ticket_id': kitchenTicketId,
      }),
    );
    final json = await _decode(response);
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  /// Update an existing held / open POS ticket (append items to same table session).
  Future<PlacedPosOrder> syncOpenOrder(
    PosSession session, {
    required int orderId,
    required List<Map<String, dynamic>> items,
    required String type,
    int? tableId,
    int? customerId,
    String? customerName,
    String? notes,
    Map<String, dynamic>? discount,
  }) async {
    final response = await _client.put(
      Uri.parse('${session.apiBaseUrl}/orders/$orderId'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'items': items,
        'type': type,
        if (tableId != null) 'table_id': tableId,
        if (customerId != null) 'customer_id': customerId,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (discount != null) 'discount': discount,
      }),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final order = data['order'] as Map<String, dynamic>?;
    if (order == null) {
      throw PosApiException('Sync response missing order payload.');
    }
    return PlacedPosOrder.fromJson(order);
  }

  // —— POS Admin (privilege-gated manage UI) ——

  Map<String, String> _adminHeaders(PosSession session) => _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      );

  /// Multipart must not set Content-Type (boundary is set by the client).
  Map<String, String> _adminAuthHeaders(PosSession session) => {
        'Accept': 'application/json',
        'X-Pos-Platform': posPlatformLabel(),
        'X-Pos-App-Version': appVersion,
        'Authorization': 'Bearer ${session.token}',
        'X-Restaurant-Id': '${session.restaurantId}',
        'X-Branch-Id': '${session.branchId}',
      };

  String _adminUrl(PosSession session, String path) =>
      '${session.apiBaseUrl}/admin$path';

  Map<String, dynamic> _unwrapData(Map<String, dynamic> json) =>
      json['data'] as Map<String, dynamic>? ?? json;

  String _multipartFieldValue(dynamic value) {
    if (value is bool) return value ? '1' : '0';
    if (value is List || value is Map) return jsonEncode(value);
    return '$value';
  }

  Future<Map<String, dynamic>> _sendAdminJson(
    PosSession session, {
    required String method,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(_adminUrl(session, path));
    final headers = _adminHeaders(session);
    final encoded = jsonEncode(body);
    final http.Response response;
    switch (method) {
      case 'POST':
        response = await _client.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        response = await _client.patch(uri, headers: headers, body: encoded);
      case 'PUT':
        response = await _client.put(uri, headers: headers, body: encoded);
      default:
        throw ArgumentError('Unsupported method $method');
    }
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> _sendAdminMenuWrite(
    PosSession session, {
    required String method,
    required String path,
    required Map<String, dynamic> body,
    XFile? imageFile,
  }) async {
    if (imageFile == null) {
      return _sendAdminJson(
        session,
        method: method,
        path: path,
        body: body,
      );
    }

    final request = http.MultipartRequest(
      method,
      Uri.parse(_adminUrl(session, path)),
    );
    request.headers.addAll(_adminAuthHeaders(session));
    body.forEach((key, value) {
      if (value == null) return;
      request.fields[key] = _multipartFieldValue(value);
    });
    final bytes = await imageFile.readAsBytes();
    final filename =
        imageFile.name.isNotEmpty ? imageFile.name : 'menu-image.jpg';
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _unwrapData(await _decode(response));
  }

  Future<AdminMenuPayload> fetchAdminMenu(PosSession session) async {
    final response = await _client.get(
      Uri.parse(_adminUrl(session, '/menu')),
      headers: _adminHeaders(session),
    );
    final json = await _decode(response);
    return AdminMenuPayload.fromJson(_unwrapData(json));
  }

  Future<PosOpeningHoursPayload> fetchOpeningHours(PosSession session) async {
    final response = await _client.get(
      Uri.parse(_adminUrl(session, '/opening-hours')),
      headers: _adminHeaders(session),
    );
    final json = await _decode(response);
    return PosOpeningHoursPayload.fromJson(_unwrapData(json));
  }

  Future<PosOpeningHoursPayload> setGuestOrderingOpen(
    PosSession session, {
    required bool acceptOnlineOrders,
  }) async {
    final data = await _sendAdminJson(
      session,
      method: 'PATCH',
      path: '/guest-ordering',
      body: {'accept_online_orders': acceptOnlineOrders},
    );
    return PosOpeningHoursPayload.fromJson(data);
  }

  Future<PosOpeningHoursPayload> updateOpeningHours(
    PosSession session, {
    required bool acceptOnlineOrders,
    required bool openingHoursEnabled,
    required String timezone,
    required Map<String, dynamic> schedule,
    required String closedMessage,
  }) async {
    final data = await _sendAdminJson(
      session,
      method: 'PUT',
      path: '/opening-hours',
      body: {
        'accept_online_orders': acceptOnlineOrders,
        'opening_hours_enabled': openingHoursEnabled,
        'opening_hours_timezone': timezone,
        'opening_hours_schedule': schedule,
        'opening_hours_closed_message': closedMessage,
      },
    );
    return PosOpeningHoursPayload.fromJson(data);
  }

  Future<Map<String, dynamic>> createAdminMenuItem(
    PosSession session, {
    required Map<String, dynamic> body,
    XFile? imageFile,
  }) {
    return _sendAdminMenuWrite(
      session,
      method: 'POST',
      path: '/menu-items',
      body: body,
      imageFile: imageFile,
    );
  }

  Future<Map<String, dynamic>> updateAdminMenuItem(
    PosSession session, {
    required int id,
    required Map<String, dynamic> body,
    XFile? imageFile,
  }) {
    return _sendAdminMenuWrite(
      session,
      method: 'PATCH',
      path: '/menu-items/$id',
      body: body,
      imageFile: imageFile,
    );
  }

  Future<bool> toggleAdminMenuItemAvailable(
    PosSession session, {
    required int id,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/menu-items/$id/toggle-available')),
      headers: _adminHeaders(session),
    );
    final data = _unwrapData(await _decode(response));
    return data['is_available'] == true;
  }

  Future<void> deleteAdminMenuItem(
    PosSession session, {
    required int id,
  }) async {
    final response = await _client.delete(
      Uri.parse(_adminUrl(session, '/menu-items/$id')),
      headers: _adminHeaders(session),
    );
    await _decode(response);
  }

  Future<Map<String, dynamic>> createAdminMenuCategory(
    PosSession session, {
    required Map<String, dynamic> body,
    XFile? imageFile,
  }) {
    return _sendAdminMenuWrite(
      session,
      method: 'POST',
      path: '/menu-categories',
      body: body,
      imageFile: imageFile,
    );
  }

  Future<Map<String, dynamic>> updateAdminMenuCategory(
    PosSession session, {
    required int id,
    required Map<String, dynamic> body,
    XFile? imageFile,
  }) {
    return _sendAdminMenuWrite(
      session,
      method: 'PATCH',
      path: '/menu-categories/$id',
      body: body,
      imageFile: imageFile,
    );
  }

  Future<bool> toggleAdminMenuCategoryActive(
    PosSession session, {
    required int id,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/menu-categories/$id/toggle-active')),
      headers: _adminHeaders(session),
    );
    final data = _unwrapData(await _decode(response));
    return data['is_active'] == true;
  }

  Future<void> deleteAdminMenuCategory(
    PosSession session, {
    required int id,
  }) async {
    final response = await _client.delete(
      Uri.parse(_adminUrl(session, '/menu-categories/$id')),
      headers: _adminHeaders(session),
    );
    await _decode(response);
  }

  Future<void> reorderAdminMenuCategories(
    PosSession session, {
    required List<int> order,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/menu-categories/reorder')),
      headers: _adminHeaders(session),
      body: jsonEncode({'order': order}),
    );
    await _decode(response);
  }

  Future<void> reorderAdminMenuItems(
    PosSession session, {
    required int categoryId,
    required List<int> order,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/menu-items/reorder')),
      headers: _adminHeaders(session),
      body: jsonEncode({
        'menu_category_id': categoryId,
        'order': order,
      }),
    );
    await _decode(response);
  }

  Future<List<AdminMenuModifier>> fetchAdminModifiers(PosSession session) async {
    final response = await _client.get(
      Uri.parse(_adminUrl(session, '/menu-modifiers')),
      headers: _adminHeaders(session),
    );
    final data = _unwrapData(await _decode(response));
    return (data['modifiers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => AdminMenuModifier.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> createAdminModifier(
    PosSession session, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/menu-modifiers')),
      headers: _adminHeaders(session),
      body: jsonEncode(body),
    );
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> updateAdminModifier(
    PosSession session, {
    required int id,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.patch(
      Uri.parse(_adminUrl(session, '/menu-modifiers/$id')),
      headers: _adminHeaders(session),
      body: jsonEncode(body),
    );
    return _unwrapData(await _decode(response));
  }

  Future<void> deleteAdminModifier(
    PosSession session, {
    required int id,
  }) async {
    final response = await _client.delete(
      Uri.parse(_adminUrl(session, '/menu-modifiers/$id')),
      headers: _adminHeaders(session),
    );
    await _decode(response);
  }

  Future<List<AdminMenuTimeSlot>> fetchAdminTimeSlots(
    PosSession session,
  ) async {
    final response = await _client.get(
      Uri.parse(_adminUrl(session, '/menu-time-slots')),
      headers: _adminHeaders(session),
    );
    final data = _unwrapData(await _decode(response));
    return (data['time_slots'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => AdminMenuTimeSlot.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> createAdminTimeSlot(
    PosSession session, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/menu-time-slots')),
      headers: _adminHeaders(session),
      body: jsonEncode(body),
    );
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> updateAdminTimeSlot(
    PosSession session, {
    required int id,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.patch(
      Uri.parse(_adminUrl(session, '/menu-time-slots/$id')),
      headers: _adminHeaders(session),
      body: jsonEncode(body),
    );
    return _unwrapData(await _decode(response));
  }

  Future<void> deleteAdminTimeSlot(
    PosSession session, {
    required int id,
  }) async {
    final response = await _client.delete(
      Uri.parse(_adminUrl(session, '/menu-time-slots/$id')),
      headers: _adminHeaders(session),
    );
    await _decode(response);
  }

  Future<AdminTablesPayload> fetchAdminTables(PosSession session) async {
    final response = await _client.get(
      Uri.parse(_adminUrl(session, '/tables')),
      headers: _adminHeaders(session),
    );
    return AdminTablesPayload.fromJson(_unwrapData(await _decode(response)));
  }

  Future<Map<String, dynamic>> createAdminTable(
    PosSession session, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/tables')),
      headers: _adminHeaders(session),
      body: jsonEncode(body),
    );
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> updateAdminTable(
    PosSession session, {
    required int id,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.patch(
      Uri.parse(_adminUrl(session, '/tables/$id')),
      headers: _adminHeaders(session),
      body: jsonEncode(body),
    );
    return _unwrapData(await _decode(response));
  }

  Future<void> deleteAdminTable(
    PosSession session, {
    required int id,
  }) async {
    final response = await _client.delete(
      Uri.parse(_adminUrl(session, '/tables/$id')),
      headers: _adminHeaders(session),
    );
    await _decode(response);
  }

  Future<Map<String, dynamic>> updateAdminTableStatus(
    PosSession session, {
    required int id,
    required String status,
  }) async {
    final response = await _client.patch(
      Uri.parse(_adminUrl(session, '/tables/$id/status')),
      headers: _adminHeaders(session),
      body: jsonEncode({'status': status}),
    );
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> createAdminTableArea(
    PosSession session, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/table-areas')),
      headers: _adminHeaders(session),
      body: jsonEncode(body),
    );
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> updateAdminTableArea(
    PosSession session, {
    required int id,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.patch(
      Uri.parse(_adminUrl(session, '/table-areas/$id')),
      headers: _adminHeaders(session),
      body: jsonEncode(body),
    );
    return _unwrapData(await _decode(response));
  }

  Future<void> deleteAdminTableArea(
    PosSession session, {
    required int id,
  }) async {
    final response = await _client.delete(
      Uri.parse(_adminUrl(session, '/table-areas/$id')),
      headers: _adminHeaders(session),
    );
    await _decode(response);
  }

  Future<void> updateAdminFloorPlan(
    PosSession session, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.put(
      Uri.parse(_adminUrl(session, '/floor-plan')),
      headers: _adminHeaders(session),
      body: jsonEncode(body),
    );
    await _decode(response);
  }

  Future<AdminOrdersPage> fetchAdminOrders(
    PosSession session, {
    String? q,
    String? status,
    String? source,
    String period = 'today',
    String payment = 'all',
    int page = 1,
  }) async {
    if (status == 'draft') {
      return _fetchDraftAdminOrders(
        session,
        q: q,
        source: source,
        period: period,
        payment: payment,
        page: page,
      );
    }

    final uri = Uri.parse(_adminUrl(session, '/orders')).replace(
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (source != null && source.isNotEmpty) 'source': source,
        'period': period,
        'payment': payment,
        'page': '$page',
      },
    );
    final response = await _client.get(uri, headers: _adminHeaders(session));
    return _adminOrdersPage(await _decode(response));
  }

  /// Draft orders use the same date range as the web admin list.
  /// The POS status filter rejects `draft`, so this tries the admin orders
  /// API and then keeps only draft rows from the normal list.
  Future<AdminOrdersPage> _fetchDraftAdminOrders(
    PosSession session, {
    String? q,
    String? source,
    required String period,
    required String payment,
    required int page,
  }) async {
    final range = _adminOrderDateRange(period);
    final query = <String, String>{
      'status': 'draft',
      'branch': '${session.branchId}',
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (source != null && source.isNotEmpty) 'source': source,
      if (range.from != null) 'date_from': range.from!,
      if (range.to != null) 'date_to': range.to!,
      if (payment != 'all') 'payment': payment,
      'page': '$page',
    };
    final headers = _adminHeaders(session);
    final uris = [
      Uri.parse('${session.v1BaseUrl}/admin/orders').replace(queryParameters: query),
      Uri.parse(_adminUrl(session, '/orders')).replace(queryParameters: query),
    ];
    for (final uri in uris) {
      try {
        final response = await _client.get(uri, headers: headers);
        final loaded = _adminOrdersPage(await _decode(response));
        final drafts = _onlyDraftOrders(loaded);
        if (drafts.orders.isNotEmpty || loaded.orders.isEmpty) {
          return drafts;
        }
      } on Object {
        // This route does not accept draft, or it is not available.
      }
    }

    try {
      final recent = await fetchRecentOrders(
        session,
        filter: period == 'all' ? 'all' : 'today',
        query: q,
        page: page,
        perPage: 50,
      );
      final rows = (recent['orders'] as List?)
              ?.whereType<Map>()
              .map((row) => AdminOrderSummary.fromJson(Map<String, dynamic>.from(row)))
              .where((order) => order.status.toLowerCase() == 'draft')
              .toList() ??
          const <AdminOrderSummary>[];
      if (rows.isNotEmpty) {
        final meta = recent['meta'] is Map
            ? Map<String, dynamic>.from(recent['meta'] as Map)
            : const <String, dynamic>{};
        return AdminOrdersPage(
          orders: rows,
          currentPage: meta['current_page'] as int? ?? page,
          lastPage: meta['last_page'] as int? ?? 1,
          total: rows.length,
        );
      }
    } on Object {
      // Recent orders can omit drafts. The period list is the last source.
    }

    final fallback = await _client.get(
      Uri.parse(_adminUrl(session, '/orders')).replace(
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (source != null && source.isNotEmpty) 'source': source,
          'period': period,
          'payment': payment,
          'page': '$page',
        },
      ),
      headers: headers,
    );
    return _onlyDraftOrders(_adminOrdersPage(await _decode(fallback)));
  }

  AdminOrdersPage _onlyDraftOrders(AdminOrdersPage page) {
    final drafts = page.orders
        .where((order) => order.status.toLowerCase() == 'draft')
        .toList();
    return AdminOrdersPage(
      orders: drafts,
      currentPage: page.currentPage,
      lastPage: page.lastPage,
      total: drafts.length,
    );
  }

  ({String? from, String? to}) _adminOrderDateRange(String period) {
    final now = DateTime.now();
    String day(DateTime date) {
      final month = date.month.toString().padLeft(2, '0');
      final value = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$value';
    }

    return switch (period) {
      'yesterday' => () {
          final date = day(now.subtract(const Duration(days: 1)));
          return (from: date, to: date);
        }(),
      'last_7_days' => (
          from: day(now.subtract(const Duration(days: 6))),
          to: day(now),
        ),
      'all' => (from: null, to: null),
      _ => () {
          final date = day(now);
          return (from: date, to: date);
        }(),
    };
  }

  AdminOrdersPage _adminOrdersPage(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) {
      return AdminOrdersPage.fromJson(Map<String, dynamic>.from(data));
    }
    if (data is List) {
      final meta = json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : <String, dynamic>{};
      return AdminOrdersPage.fromJson({
        'data': data,
        'meta': meta,
      });
    }
    final orders = json['orders'];
    if (orders is List) {
      final meta = json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : <String, dynamic>{};
      return AdminOrdersPage.fromJson({
        'data': orders,
        'meta': meta,
      });
    }
    return AdminOrdersPage.fromJson(json);
  }

  Future<Map<String, dynamic>> fetchAdminOrder(
    PosSession session, {
    required String orderKey,
  }) async {
    final response = await _client.get(
      Uri.parse(_adminUrl(session, '/orders/$orderKey')),
      headers: _adminHeaders(session),
    );
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> updateAdminOrderStatus(
    PosSession session, {
    required String orderKey,
    required String status,
    bool refund = false,
    String? cancelReason,
    String? cancelNote,
  }) async {
    final response = await _client.patch(
      Uri.parse(_adminUrl(session, '/orders/$orderKey/status')),
      headers: _adminHeaders(session),
      body: jsonEncode({
        'status': status,
        if (refund) 'refund': true,
        if (cancelReason != null && cancelReason.isNotEmpty)
          'cancel_reason': cancelReason,
        if (cancelNote != null && cancelNote.isNotEmpty) 'cancel_note': cancelNote,
      }),
    );
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> reopenAdminOrder(
    PosSession session, {
    required String orderKey,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/orders/$orderKey/reopen')),
      headers: _adminHeaders(session),
      body: jsonEncode(const <String, dynamic>{}),
    );
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> markAdminOrderPaid(
    PosSession session, {
    required String orderKey,
    String? method,
    bool complete = false,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/orders/$orderKey/mark-paid')),
      headers: _adminHeaders(session),
      body: jsonEncode({
        if (method != null && method.isNotEmpty) 'method': method,
        if (complete) 'complete': true,
      }),
    );
    return _unwrapData(await _decode(response));
  }

  Future<Map<String, dynamic>> updateAdminOrderPaymentStatus(
    PosSession session, {
    required String orderKey,
    required String paymentStatus,
    String? paymentMethod,
    String? transactionId,
  }) async {
    final response = await _client.patch(
      Uri.parse(_adminUrl(session, '/orders/$orderKey/payment-status')),
      headers: _adminHeaders(session),
      body: jsonEncode({
        'payment_status': paymentStatus,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (transactionId != null) 'transaction_id': transactionId,
      }),
    );
    return _unwrapData(await _decode(response));
  }

  Future<AdminPaymentCheckResult> checkAdminOrderPayment(
    PosSession session, {
    required String orderKey,
  }) async {
    final response = await _client.post(
      Uri.parse(_adminUrl(session, '/orders/$orderKey/check-payment')),
      headers: _adminHeaders(session),
    );
    return AdminPaymentCheckResult.fromJson(
      _unwrapData(await _decode(response)),
    );
  }

  /// Mint a narrowly-scoped token (e.g. kitchen KDS) without re-login.
  Future<String> issueScopedToken(
    PosSession session, {
    required String ability,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.authBaseUrl}/scoped-token'),
      headers: _jsonHeaders(
        token: session.token,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({
        'token_ability': ability,
        'device_name': '${PosAppInfo.displayName} ($ability)',
      }),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw PosApiException('Scoped token was not returned.');
    }
    return token;
  }

  Future<KitchenBootstrap> fetchKitchenBootstrap({
    required PosSession session,
    required String kitchenToken,
  }) async {
    final response = await _client.get(
      Uri.parse('${session.v1BaseUrl}/kitchen/bootstrap'),
      headers: _jsonHeaders(
        token: kitchenToken,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return KitchenBootstrap.fromJson(data);
  }

  Future<({KitchenBoard board, int? selectedKitchenId})> fetchKitchenOrders({
    required PosSession session,
    required String kitchenToken,
    int? kitchenId,
  }) async {
    final query = kitchenId == null ? '' : '?kitchen=$kitchenId';
    final response = await _client.get(
      Uri.parse('${session.v1BaseUrl}/kitchen/orders$query'),
      headers: _jsonHeaders(
        token: kitchenToken,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    final json = await _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final boardRaw = data['orders_by_status'] as Map<String, dynamic>?;
    return (
      board: parseKitchenBoard(boardRaw),
      selectedKitchenId: parseJsonIntOrNull(data['selected_kitchen_id']),
    );
  }

  Future<void> updateKitchenTicketStatus({
    required PosSession session,
    required String kitchenToken,
    required int ticketId,
    required String status,
  }) async {
    final response = await _client.patch(
      Uri.parse('${session.v1BaseUrl}/kitchen/tickets/$ticketId/status'),
      headers: _jsonHeaders(
        token: kitchenToken,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({'status': status}),
    );
    await _decode(response);
  }

  Future<void> updateKitchenItemStatus({
    required PosSession session,
    required String kitchenToken,
    required int itemId,
    required String status,
  }) async {
    final response = await _client.patch(
      Uri.parse('${session.v1BaseUrl}/kitchen/items/$itemId/status'),
      headers: _jsonHeaders(
        token: kitchenToken,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
      body: jsonEncode({'status': status}),
    );
    await _decode(response);
  }

  Future<void> bumpKitchenPriority({
    required PosSession session,
    required String kitchenToken,
    required int orderId,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.v1BaseUrl}/kitchen/orders/$orderId/priority'),
      headers: _jsonHeaders(
        token: kitchenToken,
        restaurantId: session.restaurantId,
        branchId: session.branchId,
      ),
    );
    await _decode(response);
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw PosApiException(
        'Invalid server response (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body['message'] as String? ??
        body['error'] as String? ??
        (body['errors'] is Map
            ? (body['errors'] as Map).values.first?.first?.toString()
            : null) ??
        'Request failed (${response.statusCode}).';

    throw PosApiException(
      message,
      statusCode: response.statusCode,
      retryAfter: _retryAfter(response, body),
      trialExpired: body['trial_expired'] == true,
      subscriptionInactive: body['subscription_inactive'] == true,
      canManageBilling: body['can_manage_billing'] == true,
      billingSelfServe: body['billing_self_serve'] == true,
      coveredByOrganization: body['covered_by_organization'] == true,
    );
  }

  Duration? _retryAfter(http.Response response, Map<String, dynamic> body) {
    final header = response.headers['retry-after'];
    final fromHeader = int.tryParse(header ?? '');
    final fromBody = parseJsonIntOrNull(body['retry_after']) ??
        parseJsonIntOrNull(body['retryAfter']);
    final seconds = fromHeader ?? fromBody;
    if (seconds == null || seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  String _networkErrorMessage(Object error) {
    final store = PosTranslationStore.instance;
    final detail = error.toString();
    if (detail.contains('Operation not permitted')) {
      return store.text(
        'netBlocked',
        'Network access blocked. Check permissions and try again.',
      );
    }
    return store.text(
      'errorNetwork',
      'Could not reach the server. Check your connection and try again.',
    );
  }

  String get defaultServerUrl => _defaultBase;
}
