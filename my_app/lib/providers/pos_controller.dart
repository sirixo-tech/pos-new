import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/platform_config.dart';
import '../l10n/pos_translation_store.dart';
import '../models/pos_app_update.dart';
import '../models/pos_models.dart';
import '../models/waiter_alert.dart';
import '../payments/payment_session.dart';
import '../payments/payment_session_manager.dart';
import '../services/offline/offline.dart';
import '../services/offline/offline_token_store.dart';
import '../services/order_fulfillment_policy.dart';
import '../services/pos_api.dart';
import '../services/pos_cart_sound.dart';
import '../services/pos_device_binding_storage.dart';
import '../services/customer_display/customer_display_broker.dart';
import '../services/pos_display_sync.dart';
import '../utils/media_url.dart';
import '../services/pos_local_pin_storage.dart';
import '../services/pos_bill_request_storage.dart';
import '../services/pos_location_storage.dart';
import '../services/pos_storage.dart';
import '../services/pos_terminal_storage.dart';
import '../services/pos_waiter_alerts_storage.dart';
import '../services/pos_work_mode_storage.dart';
import '../services/printing/print_job_coordinator.dart';
import '../utils/json_parse.dart';
import '../utils/marketplace_platform_ui.dart';
import '../utils/offline_payments.dart';
import '../utils/order_charges_calculator.dart';
import '../utils/pos_user_facing_error.dart';
import '../utils/tax_calculator.dart';

export '../services/pos_work_mode_storage.dart' show PosWorkMode;

enum PosAppPhase {
  loading,
  setup,
  pairDevice,
  login,
  contextPicker,
  modePicker,
  terminalPicker,
  ready,
  locked,
  error,
}

enum PosUpdateCheckResult {
  upToDate,
  optional,
  required,
  failed,
  unavailable,
  busy,
}

class PosController extends ChangeNotifier {
  PosController({
    PosStorage? storage,
    PosApi? api,
    PosDisplaySync? displaySync,
    ConnectivityService? connectivity,
    OrderSyncService? syncService,
    PrintJobCoordinator? printJobs,
    Future<void> Function(PosBootstrap? bootstrap)? onBootstrapChanged,
  }) : _storage = storage ?? PosStorage(),
       _api = api ?? PosApi(),
       _displaySync = displaySync ?? PosDisplaySync(),
       _connectivity = connectivity,
       _syncService = syncService,
       _printJobs = printJobs,
       _onBootstrapChanged = onBootstrapChanged;

  final PosStorage _storage;
  final PosApi _api;
  final PosDisplaySync _displaySync;
  ConnectivityService? _connectivity;
  OrderSyncService? _syncService;
  final PrintJobCoordinator? _printJobs;
  final Future<void> Function(PosBootstrap? bootstrap)? _onBootstrapChanged;
  Timer? _revisionPollTimer;
  bool _revisionSyncInProgress = false;
  String? _bootstrapRevision;
  String? _menuRevision;
  String? _dismissedOptionalLatest;

  PosAppPhase phase = PosAppPhase.loading;
  String? serverUrl;
  PosSession? session;
  // Survives register screen recreation when switching work modes.
  bool _printerSetupShownForSession = false;

  bool claimPrinterSetupForSession() {
    if (_printerSetupShownForSession) return false;
    _printerSetupShownForSession = true;
    return true;
  }

  StaffProfile? profile;
  PosBootstrap? bootstrap;
  PosAppUpdate appUpdate = PosAppUpdate.none();
  PosDeviceBinding? deviceBinding;
  String? errorMessage;
  int? lastLoginStatusCode;
  Duration? lastLoginRetryAfter;

  /// True when POS is blocked because trial/subscription is inactive.
  bool subscriptionBlocked = false;
  bool trialExpired = false;
  bool canManageBilling = false;
  bool billingSelfServe = false;
  bool checkingForUpdates = false;

  String? pairingCode;
  String? pairingDeviceUuid;
  Timer? _pairingPollTimer;
  Timer? _displaySyncTimer;

  String? selectedTerminalCode;
  PosTerminalInfo? selectedTerminal;

  /// Register (tablet) vs Waiter (phone captain) vs Kitchen KOT board.
  PosWorkMode? workMode;

  /// Scoped Sanctum token for `/api/v1/kitchen/*` (minted on demand).
  String? _kitchenApiToken;

  /// Cached floor data for waiter mode (polled).
  List<Map<String, dynamic>> waiterTables = const [];
  List<Map<String, dynamic>> waiterTableAreas = const [];
  List<Map<String, dynamic>> waiterTablesWithoutArea = const [];
  List<Map<String, dynamic>> waiterHeldOrders = const [];
  List<Map<String, dynamic>> waiterRecentOrders = const [];
  Set<int> billRequestedTableIds = {};
  List<WaiterAlert> waiterAlerts = const [];
  bool waiterRefreshing = false;
  DateTime? waiterLastRefreshedAt;
  Timer? _waiterPollTimer;
  Timer? _registerAlertPollTimer;
  Timer? _newOrderPollTimer;
  bool _waiterAlertsHydrated = false;
  bool _registerFloorPrimed = false;
  bool _newOrdersSynced = false;
  int? _newOrdersLastSeenId;
  final List<WaiterAlert> _newOrderBannerQueue = [];
  final Set<int> _selfPlacedOrderIds = <int>{};
  VoidCallback? _connectivityListener;

  /// Online-order alerts. Two seconds used about 30 requests a minute and
  /// shared the server limit with checkout, receipt, and KOT fetches.
  static const Duration _newOrderPollInterval = Duration(seconds: 8);
  List<Map<String, dynamic>> _registerFloorSnapshot = const [];
  final Set<String> _paymentSessionSignals = <String>{};
  bool _paymentSessionsBound = false;
  String? paymentSessionNotice;
  String? cashierPlacedNotice;
  Timer? _cashierPlacedNoticeTimer;

  /// Last cart pay-method pill (cash / upi / card / more). Cash by default.
  String cartQuickPayMethod = 'cash';

  /// One-shot deep-link from a notification tap → open this table sheet.
  int? waiterFocusTableId;

  /// Newest bill-request / new-order alert for register toast (consumed by PosShell).
  WaiterAlert? registerBannerAlert;

  int get waiterUnreadAlertCount => waiterAlerts.where((a) => !a.isRead).length;

  int get registerBillUnreadCount => waiterAlerts
      .where(
        (a) =>
            !a.isRead &&
            (a.type == WaiterAlertType.billRequested || a.type.isNewOrderCue),
      )
      .length;

  /// Extra unread new-order cues behind the current banner (for “+N more”).
  int get pendingNewOrderBannerExtraCount {
    final shown = registerBannerAlert;
    if (shown == null || !shown.type.isNewOrderCue) return 0;
    return _newOrderBannerQueue.length;
  }

  /// Guest count for the current waiter table session (local UX only).
  int? waiterGuestCount;

  /// Items already on the open ticket (waiter append mode). Not shown in the
  /// working cart — merged in when sending/updating the KOT.
  List<CartLine> waiterSentCart = [];

  final List<CartLine> cart = [];
  int? selectedCategoryId;
  String searchQuery = '';
  String orderType = 'dine_in';
  String? customerName;
  int? customerId;
  int? tableId;
  String? tableLabel;
  String? orderNotes;
  CartDiscount? discount;
  bool submitting = false;
  PlacedPosOrder? lastOrder;
  PendingOrder? lastOfflineOrder;

  /// When set, the cart is a resumed *server* held ticket — pay via `/orders/{id}/pay`.
  int? parkedOrderId;

  /// When set, the cart is a resumed *local* held ticket (offline park).
  String? parkedLocalUuid;

  String? parkedOrderLabel;

  /// Amount already collected on the resumed server ticket (partial payments).
  double parkedAmountPaid = 0;

  String? parkedPaymentStatus;

  /// Held / parked tickets count (sidebar Held badge) — server + local.
  int heldOrderCount = 0;
  Future<void>? _heldCountInFlight;
  bool _heldCountDirty = false;
  PosSession? _heldRowsSession;
  List<Map<String, dynamic>>? _heldRows;

  List<Map<String, dynamic>>? get cachedHeldOrders =>
      identical(_heldRowsSession, session) ? _heldRows : null;

  void _cacheHeldRows(PosSession current, List<Map<String, dynamic>> rows) {
    if (!identical(current, session)) return;
    _heldRowsSession = current;
    _heldRows = List.unmodifiable(rows);
  }

  /// Today's branch orders count (header Orders badge).
  int todayOrderCount = 0;

  /// Open (not delivered/cancelled) order counts by marketplace provider.
  Map<String, int> marketplaceOpenOrderCounts = const {};

  int marketplaceOpenCount(String provider) {
    final key = provider.toLowerCase().trim();
    if (key.isEmpty) return 0;
    return marketplaceOpenOrderCounts[key] ?? 0;
  }

  bool get hasParkedTicket => parkedOrderId != null || parkedLocalUuid != null;

  void _forgetParkedPayment() {
    parkedAmountPaid = 0;
    parkedPaymentStatus = null;
  }

  void _rememberParkedPayment(Map<String, dynamic> summary) {
    parkedAmountPaid = parseJsonDouble(summary['amount_paid']);
    final status = summary['payment_status']?.toString().trim();
    parkedPaymentStatus = (status != null && status.isNotEmpty) ? status : null;
  }

  /// Bumps whenever cart lines change — use with `context.select` to avoid
  /// rebuilding on unrelated notifies (notes, search, etc.).
  int cartEpoch = 0;

  /// UI-only: which cart line should open after an add / merge from the menu.
  int cartRevealGeneration = 0;
  int? cartRevealIndex;

  List<MenuItem>? _flatItemsCache;
  Object? _flatItemsBootstrap;
  List<MenuItem>? _popularItemsCache;
  Object? _popularItemsBootstrap;
  List<MenuItem>? _itemsToDisplayCache;
  String? _itemsToDisplayKey;
  bool _cartMapsDirty = true;
  Map<int, int> _cartQtyByMenuItemId = const {};
  Map<int, CartLine?> _simpleCartLineByMenuItemId = const {};

  /// One-shot UI hint after password login when staff has no POS PIN yet.
  bool offerSetPosPinPrompt = false;

  bool get isOffline => _connectivity?.isOffline ?? false;
  bool get isOnline => _connectivity?.isOnline ?? true;
  int get pendingOrderCount => _syncService?.pendingCount ?? 0;
  bool get updateRequired => appUpdate.isRequired;

  /// Version key for the header strip. A newer published build uses a new key.
  String? get _updateNoticeKey {
    final latest = appUpdate.latestVersion?.trim() ?? '';
    if (latest.isNotEmpty) return latest;
    final minimum = appUpdate.minVersion?.trim() ?? '';
    if (minimum.isNotEmpty) return minimum;
    if (appUpdate.isOptional || appUpdate.isRequired) return 'available';
    return null;
  }

  /// Header strip for a release newer than the running binary. Later hides it
  /// until the next launch or until Check for updates. The register is never
  /// blocked, and an older published version is not shown.
  bool get showOptionalUpdateBanner {
    if (!appUpdate.installsNewerBuild) return false;
    final key = _updateNoticeKey;
    return key != null && key != _dismissedOptionalLatest;
  }

  void setConnectivityService(ConnectivityService service) {
    if (_connectivityListener != null) {
      _connectivity?.removeListener(_connectivityListener!);
    }
    _connectivity = service;
    _connectivityListener = () {
      if (!service.isOnline) return;
      if (isRegisterMode || isWaiterMode) {
        unawaited(refreshNewOrderAlerts(silent: true));
      }
      if (isRegisterMode) {
        unawaited(refreshRegisterBillAlerts(silent: true));
      }
    };
    service.addListener(_connectivityListener!);
    service.updateServerUrl(serverUrl);
  }

  /// Call when the app returns to the foreground for faster alert delivery.
  void refreshAlertsOnResume() {
    if (session == null) return;
    if (isRegisterMode || isWaiterMode) {
      unawaited(refreshNewOrderAlerts(silent: true));
    }
    if (isRegisterMode) {
      unawaited(refreshRegisterBillAlerts(silent: true));
    }
  }

  void setSyncService(OrderSyncService service) {
    _syncService = service;
    service.onOrderSynced = (order, success) {
      if (success) {
        registerSelfPlacedOrder(order.serverOrderId);
      }
    };
    if (session != null) {
      service.configure(session);
    }
  }

  /// Orders punched on this register — skip redundant new-order modal/sound.
  void registerSelfPlacedOrder(int? orderId) {
    if (orderId == null || orderId <= 0) return;
    _selfPlacedOrderIds.add(orderId);
    if (_selfPlacedOrderIds.length > 80) {
      final extra = _selfPlacedOrderIds.length - 60;
      _selfPlacedOrderIds.removeAll(_selfPlacedOrderIds.take(extra).toList());
    }
  }

  static const List<MenuCategory> _emptyCategories = [];

  List<MenuCategory> get categories =>
      bootstrap?.categories ?? _emptyCategories;

  List<MenuItem> get flatItems {
    if (_flatItemsCache != null && identical(_flatItemsBootstrap, bootstrap)) {
      return _flatItemsCache!;
    }
    _flatItemsBootstrap = bootstrap;
    _flatItemsCache = categories
        .expand((category) => category.items)
        .toList(growable: false);
    _itemsToDisplayCache = null;
    _itemsToDisplayKey = null;
    _popularItemsCache = null;
    return _flatItemsCache!;
  }

  MenuItem? menuItemForBarcode(String code) => matchBarcode(code)?.item;

  MenuBarcodeMatch? matchBarcode(String code) {
    final needle = code.trim().toLowerCase().replaceAll(
      RegExp(r'[\u0000-\u001F]'),
      '',
    );
    if (needle.isEmpty) return null;
    for (final item in flatItems) {
      if (_sameBarcode(item.barcode, needle) ||
          _sameBarcode(item.sku, needle)) {
        return MenuBarcodeMatch(item: item);
      }
      for (final variant in item.variants) {
        if (_sameBarcode(variant.barcode, needle)) {
          return MenuBarcodeMatch(item: item, variant: variant);
        }
      }
    }
    return null;
  }

  static bool _sameBarcode(String? stored, String needle) {
    final value = stored?.trim().toLowerCase();
    if (value == null || value.isEmpty) return false;
    if (value == needle) return true;
    final compactStored = value.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final compactNeedle = needle.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return compactStored.isNotEmpty && compactStored == compactNeedle;
  }

  List<MenuItem> get popularItems {
    if (bootstrap?.showPopularItems == false) {
      return const [];
    }
    if (_popularItemsCache != null &&
        identical(_popularItemsBootstrap, bootstrap)) {
      return _popularItemsCache!;
    }
    _popularItemsBootstrap = bootstrap;
    final catalog = flatItems;
    final byId = {for (final item in catalog) item.id: item};
    final mapped = <MenuItem>[];
    for (final item in bootstrap?.popularItems ?? const <MenuItem>[]) {
      final live = byId[item.id];
      if (live != null) mapped.add(live);
    }
    _popularItemsCache = mapped.isNotEmpty
        ? List<MenuItem>.unmodifiable(mapped)
        : List<MenuItem>.unmodifiable(catalog.take(12));
    return _popularItemsCache!;
  }

  int? get activeCategoryId => selectedCategoryId;

  bool get isAllItemsView => selectedCategoryId == null;

  List<MenuItem> get itemsToDisplay {
    final q = searchQuery.toLowerCase().trim();
    final key =
        '$q|${selectedCategoryId ?? 'all'}|${identityHashCode(bootstrap)}';
    if (_itemsToDisplayCache != null && _itemsToDisplayKey == key) {
      return _itemsToDisplayCache!;
    }

    final List<MenuItem> result;
    if (q.isNotEmpty) {
      result = flatItems
          .where((item) => item.matchesSearch(q))
          .toList(growable: false);
    } else if (isAllItemsView) {
      result = flatItems;
    } else {
      final categoryId = selectedCategoryId;
      if (categoryId == null || categories.isEmpty) {
        result = const [];
      } else {
        final category = categories.firstWhere(
          (c) => c.id == categoryId,
          orElse: () => categories.first,
        );
        result = category.items;
      }
    }

    _itemsToDisplayKey = key;
    _itemsToDisplayCache = result;
    return result;
  }

  /// Qty of each menu item currently in the ticket (all variants/modifiers).
  Map<int, int> get cartQtyByMenuItemId {
    _ensureCartLookupMaps();
    return _cartQtyByMenuItemId;
  }

  /// Simple (no options / no line notes) cart lines keyed by menu item id.
  Map<int, CartLine?> get simpleCartLineByMenuItemId {
    _ensureCartLookupMaps();
    return _simpleCartLineByMenuItemId;
  }

  void _ensureCartLookupMaps() {
    if (!_cartMapsDirty) return;
    _cartMapsDirty = false;

    final qty = <int, int>{};
    final simple = <int, CartLine?>{};
    for (final line in cart) {
      final id = line.menuItem.id;
      qty[id] = (qty[id] ?? 0) + line.quantity;
      if (!line.menuItem.hasOptions &&
          line.variant == null &&
          line.selectedModifiers.isEmpty &&
          (line.notes == null || line.notes!.trim().isEmpty)) {
        simple.putIfAbsent(id, () => line);
      }
    }
    _cartQtyByMenuItemId = qty;
    _simpleCartLineByMenuItemId = simple;
  }

  void _markCartChanged() {
    cartEpoch++;
    _cartMapsDirty = true;
  }

  void _revealCartLine(int index) {
    cartRevealIndex = index;
    cartRevealGeneration++;
  }

  MenuCategory? get activeCategory {
    if (isAllItemsView || categories.isEmpty) {
      return null;
    }

    final categoryId = selectedCategoryId;
    if (categoryId == null) {
      return null;
    }

    for (final category in categories) {
      if (category.id == categoryId) {
        return category;
      }
    }

    return categories.first;
  }

  String get activeCategoryTitle {
    final t = PosTranslationStore.instance;
    return isAllItemsView
        ? t.text('menuAllItems', 'All items')
        : (activeCategory?.name ?? t.text('menuCategoryFallback', 'Category'));
  }

  String get activeCategorySubtitle {
    final t = PosTranslationStore.instance;
    return isAllItemsView
        ? t.text('menuBrowseFull', 'Browse the full menu')
        : t.text('menuCategoryItems', 'Items in this category');
  }

  List<MenuItem> get categoryItemsToDisplay => itemsToDisplay;

  bool get showPopularStrip {
    if (searchQuery.trim().isNotEmpty || popularItems.isEmpty) return false;
    if (isAllItemsView) return true;
    final first = categories.isEmpty ? null : categories.first;
    return first != null && selectedCategoryId == first.id;
  }

  bool get menuItemsEmpty {
    if (searchQuery.trim().isNotEmpty) {
      return itemsToDisplay.isEmpty;
    }

    return categoryItemsToDisplay.isEmpty && !showPopularStrip;
  }

  int get cartItemCount => cart.fold(0, (sum, line) => sum + line.quantity);

  double get cartSubtotal => cart.fold(0, (sum, line) => sum + line.lineTotal);

  double get discountAmount => discount?.amountFor(cartSubtotal) ?? 0;

  OrderTotalsPreview get cartTotalsPreview {
    final restaurant = bootstrap?.restaurant;
    final disc = discountAmount;
    if (restaurant == null) {
      final total = (cartSubtotal - disc).clamp(0, double.infinity);
      return OrderTotalsPreview(
        extraChargeLines: const [],
        extraChargesTotal: 0,
        serviceChargeAmount: 0,
        taxComputation: TaxComputation(
          breakdown: const [],
          totalTax: 0,
          total: total.toDouble(),
        ),
      );
    }

    return computeOrderTotalsPreview(
      subtotal: cartSubtotal,
      discountAmount: disc,
      cartLines: cart
          .map(
            (line) => {
              'menu_item_id': line.menuItem.id,
              'quantity': line.quantity,
              'order_type_surcharges': line.menuItem.orderTypeSurcharges,
            },
          )
          .toList(),
      orderType: orderType,
      orderTypeCharges: restaurant.orderTypeCharges,
      surchargeSettings: restaurant.orderTypeSurchargeSettings,
      serviceCharge: restaurant.serviceCharge,
      taxSettings: restaurant.taxSettings,
    );
  }

  double get cartTotal => cartTotalsPreview.total;

  bool get parkedIsPartial =>
      parkedAmountPaid > 0.001 || parkedPaymentStatus == 'partial';

  /// Remaining to collect on the current cart, after any amount already paid
  /// on a resumed ticket.
  double get cartAmountDue {
    final due = cartTotal - parkedAmountPaid;
    if (due < 0.001) return 0;
    return (due * 100).round() / 100;
  }

  Map<String, dynamic> parkedPaymentSnapshot() {
    return {
      'id': parkedOrderId,
      'order_number': parkedOrderLabel,
      'total': cartTotal,
      'amount_due': cartAmountDue,
      'amount_paid': parkedAmountPaid,
      'payment_status': parkedIsPartial ? 'partial' : 'pending',
      'can_collect_payment': true,
    };
  }

  Map<String, dynamic>? get _discountPayload {
    final current = discount;
    if (current == null || discountAmount <= 0) return null;
    return current.toApiJson();
  }

  int? get _tableIdForPayload => orderType == 'dine_in' ? tableId : null;

  String get currency => bootstrap?.restaurant.defaultCurrency ?? 'USD';

  bool get posBlocked => bootstrap?.posBlocked ?? false;

  bool get isHostedMode => !PlatformConfig.allowCustomServerUrl;

  bool get isWaiterMode => workMode == PosWorkMode.waiter;

  bool get isRegisterMode => workMode == PosWorkMode.register;

  bool get isKitchenMode => workMode == PosWorkMode.kitchen;

  /// Register POS (tablet) — permission `access_pos`.
  bool get canUseRegister {
    final fromBootstrap = bootstrap?.permissions;
    if (fromBootstrap != null && fromBootstrap.isNotEmpty) {
      return fromBootstrap.contains('access_pos');
    }
    return profile?.permissions.contains('access_pos') ?? false;
  }

  /// Captain / waiter floor — permission `access_pos_captain`.
  bool get canUseCaptain {
    final fromBootstrap = bootstrap?.permissions;
    if (fromBootstrap != null && fromBootstrap.isNotEmpty) {
      return fromBootstrap.contains('access_pos_captain');
    }
    return profile?.permissions.contains('access_pos_captain') ?? false;
  }

  /// Kitchen / KOT display — permission `access_kitchen`.
  bool get canUseKitchen {
    final fromBootstrap = bootstrap?.permissions;
    if (fromBootstrap != null && fromBootstrap.isNotEmpty) {
      return fromBootstrap.contains('access_kitchen');
    }
    return profile?.permissions.contains('access_kitchen') ?? false;
  }

  int get _allowedWorkModeCount =>
      (canUseRegister ? 1 : 0) +
      (canUseCaptain ? 1 : 0) +
      (canUseKitchen ? 1 : 0);

  bool get canChooseWorkMode => _allowedWorkModeCount > 1;

  /// True when the signed-in staffer can pick another restaurant or branch.
  bool get canChangeLocation => profile?.needsContextPicker ?? false;

  bool _isWorkModeAllowed(PosWorkMode mode) {
    return switch (mode) {
      PosWorkMode.register => canUseRegister,
      PosWorkMode.waiter => canUseCaptain,
      PosWorkMode.kitchen => canUseKitchen,
    };
  }

  String? _kitchenTokenSessionKey;

  Future<String> ensureKitchenApiToken() async {
    final current = session;
    if (current == null) {
      throw StateError('Not signed in.');
    }
    final key =
        '${current.serverUrl}|${current.restaurantId}|${current.branchId}|${current.token}';
    final cached = _kitchenTokenSessionKey == key ? _kitchenApiToken : null;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final token = await _api.issueScopedToken(current, ability: 'kitchen');
    if (identical(session, current)) {
      _kitchenApiToken = token;
      _kitchenTokenSessionKey = key;
    }
    return token;
  }

  Future<void> initialize() async {
    phase = PosAppPhase.loading;
    errorMessage = null;
    subscriptionBlocked = false;
    trialExpired = false;
    canManageBilling = false;
    billingSelfServe = false;
    notifyListeners();

    try {
      serverUrl = await _resolveServerUrl();
      _connectivity?.updateServerUrl(serverUrl);
      deviceBinding = await PosDeviceBindingStorage.read();

      if (serverUrl == null || serverUrl!.trim().isEmpty) {
        phase = PosAppPhase.setup;
        notifyListeners();
        return;
      }

      final savedSession = await _storage.getSession();
      // Debug/local URL can change while an old hosted session is still saved.
      // API calls always use session.serverUrl — drop the mismatch so staff
      // re-auth against the active host (and pull that host's language catalogs).
      if (savedSession != null &&
          !_sameServerUrl(savedSession.serverUrl, serverUrl!)) {
        await _storage.clearSession();
        session = null;
        await PosTranslationStore.instance.clear();
      } else {
        session = savedSession;
      }
      if (session == null) {
        // Pairing is optional and starts from the login page's pairing button.
        phase = PosAppPhase.login;
        notifyListeners();
        return;
      }

      _syncService?.configure(session!);
      try {
        await _resumeSession().timeout(const Duration(seconds: 8));
      } catch (e) {
        if (e is PosApiException) {
          rethrow;
        }
        final recovered = await _tryOfflineRecovery();
        if (!recovered) {
          await _storage.clearSession();
          session = null;
          phase = PosAppPhase.login;
        }
      }
    } on PosApiException catch (e) {
      if (e.statusCode == 401) {
        await _storage.clearSession();
        session = null;
        phase = PosAppPhase.login;
        errorMessage = PosTranslationStore.instance.text(
          'authSessionExpired',
          'Session expired. Please sign in again.',
        );
      } else if (e.isSubscriptionBlocked) {
        _presentSubscriptionBlock(e);
      } else {
        final recovered = await _tryOfflineRecovery();
        if (!recovered) {
          phase = PosAppPhase.error;
          errorMessage = posUserFacingError(e);
        }
      }
    } catch (e) {
      final recovered = await _tryOfflineRecovery();
      if (!recovered) {
        phase = PosAppPhase.error;
        errorMessage = posUserFacingError(e);
      }
    }

    notifyListeners();
  }

  Future<bool> _tryOfflineRecovery() async {
    final current = session;
    if (current == null) return false;

    final cached = await BootstrapCache.load(current.branchId);
    if (cached == null) return false;

    try {
      final data = cached['data'] as Map<String, dynamic>;
      bootstrap = PosBootstrap.fromJson(data);
      await _notifyBootstrapChanged();
      final next = await _resolvePostBootstrapPhase();
      phase = next;
      if (next == PosAppPhase.ready) {
        await _onEnteredReady(fromResume: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveServerUrl() async {
    final stored = await _storage.getServerUrl();
    if (stored != null && stored.trim().isNotEmpty) {
      return PlatformConfig.normalizeServerUrl(stored.trim());
    }
    return PlatformConfig.normalizeServerUrl(PlatformConfig.platformUrl.trim());
  }

  Future<void> saveServerUrl(String url) async {
    final trimmed = PlatformConfig.normalizeServerUrl(url);
    if (trimmed.isEmpty) return;
    final previous = serverUrl;
    await _storage.saveServerUrl(trimmed);
    serverUrl = trimmed;
    _connectivity?.updateServerUrl(trimmed);
    if (previous == null || !_sameServerUrl(previous, trimmed)) {
      await _storage.clearSession();
      session = null;
      await PosTranslationStore.instance.clear();
      await PosDeviceBindingStorage.clear();
      deviceBinding = null;
    }
    skipPairingToLogin();
  }

  static bool _sameServerUrl(String a, String b) {
    String norm(String value) {
      var out = value.trim().toLowerCase();
      while (out.endsWith('/')) {
        out = out.substring(0, out.length - 1);
      }
      return out;
    }

    return norm(a) == norm(b);
  }

  Future<void> login(String email, String password) async {
    final url = serverUrl;
    if (url == null || url.isEmpty) {
      phase = PlatformConfig.allowCustomServerUrl
          ? PosAppPhase.setup
          : PosAppPhase.login;
      notifyListeners();
      return;
    }

    errorMessage = null;
    lastLoginStatusCode = null;
    lastLoginRetryAfter = null;
    subscriptionBlocked = false;
    trialExpired = false;
    canManageBilling = false;
    billingSelfServe = false;
    notifyListeners();

    try {
      final binding = deviceBinding;
      StaffLoginResult result;
      try {
        result = await _api.login(
          serverUrl: url,
          email: email.trim(),
          password: password,
          restaurantId: binding?.restaurantId,
          branchId: binding?.branchId,
        );
      } on PosApiException catch (e) {
        // Stale pairing from another server/env sends a restaurant_id the
        // staffer cannot access (403). Retry unbound, then drop the binding.
        final boundRestaurantId = binding?.restaurantId;
        final shouldRetryUnbound =
            boundRestaurantId != null &&
            (e.statusCode == 403 || e.statusCode == 422);
        if (!shouldRetryUnbound) rethrow;

        result = await _api.login(
          serverUrl: url,
          email: email.trim(),
          password: password,
        );
        await PosDeviceBindingStorage.clear();
        deviceBinding = null;
      }

      session = result.session;
      profile = result.profile;
      await _storage.saveSession(session!);
      await _afterAuth(profile!);
    } on PosApiException catch (e) {
      lastLoginStatusCode = e.statusCode;
      lastLoginRetryAfter = e.retryAfter;
      if (e.isSubscriptionBlocked) {
        _presentSubscriptionBlock(e);
      } else {
        errorMessage = posUserFacingError(e);
      }
    } catch (e, stack) {
      errorMessage = e is TypeError
          ? PosTranslationStore.instance.text(
              'authAccountLoadFailed',
              'Could not load account data from server. Try again.',
            )
          : posUserFacingError(e);
      assert(() {
        // ignore: avoid_print
        print('POS login error: $e\n$stack');
        return true;
      }());
    }

    notifyListeners();
  }

  Future<void> _resumeSession() async {
    final current = session;
    if (current == null) {
      phase = PosAppPhase.login;
      return;
    }

    // Keep the last store from this device when still assigned to the staffer.
    final preferredRestaurantId = current.restaurantId;
    final preferredBranchId = current.branchId;

    profile = await _api.fetchMe(current);

    final keepPreferred = profile!.canAccessLocation(
      preferredRestaurantId,
      preferredBranchId,
    );
    session = current.copyWith(
      restaurantId: keepPreferred
          ? preferredRestaurantId
          : (profile!.currentRestaurantId ?? preferredRestaurantId),
      branchId: keepPreferred
          ? preferredBranchId
          : (profile!.currentBranchId ?? preferredBranchId),
      userId: profile!.user.id,
      userName: profile!.user.name,
      hasPosPin: profile!.user.hasPosPin,
    );
    await _storage.saveSession(session!);
    await _afterAuth(profile!, fromResume: true);
  }

  Future<void> _afterAuth(
    StaffProfile staffProfile, {
    bool fromResume = false,
  }) async {
    _syncService?.configure(session);
    if (staffProfile.needsContextPicker) {
      final preferred = await _preferredLocation(
        staffProfile,
        fromResume: fromResume,
      );
      if (preferred != null) {
        await _applyLocationAndContinue(
          restaurantId: preferred.restaurantId,
          branchId: preferred.branchId,
          fromResume: fromResume,
        );
        return;
      }
      phase = PosAppPhase.contextPicker;
      return;
    }

    await _rememberCurrentLocation();
    await _loadBootstrap();
    final next = await _resolvePostBootstrapPhase();
    phase = next;
    if (next == PosAppPhase.ready) {
      await _onEnteredReady(fromResume: fromResume);
    }
  }

  Future<PosLocationPreference?> _preferredLocation(
    StaffProfile staffProfile, {
    required bool fromResume,
  }) async {
    final current = session;
    if (current == null) return null;

    final binding = deviceBinding;
    if (binding != null &&
        staffProfile.canAccessLocation(
          binding.restaurantId,
          binding.branchId,
        )) {
      return PosLocationPreference(
        restaurantId: binding.restaurantId,
        branchId: binding.branchId,
      );
    }

    final stored = await PosLocationStorage.read(
      serverUrl: current.serverUrl,
      userId: staffProfile.user.id,
    );
    if (stored != null &&
        staffProfile.canAccessLocation(stored.restaurantId, stored.branchId)) {
      return stored;
    }

    // Cold resume: keep the store already saved on this session.
    if (fromResume &&
        staffProfile.canAccessLocation(
          current.restaurantId,
          current.branchId,
        )) {
      return PosLocationPreference(
        restaurantId: current.restaurantId,
        branchId: current.branchId,
      );
    }

    return null;
  }

  Future<void> _rememberCurrentLocation() async {
    final current = session;
    final userId = current?.userId ?? profile?.user.id;
    if (current == null || userId == null) return;
    await PosLocationStorage.write(
      serverUrl: current.serverUrl,
      userId: userId,
      restaurantId: current.restaurantId,
      branchId: current.branchId,
    );
  }

  Future<void> _applyLocationAndContinue({
    required int restaurantId,
    required int branchId,
    bool fromResume = false,
  }) async {
    final current = session;
    if (current == null) return;

    errorMessage = null;
    subscriptionBlocked = false;
    trialExpired = false;
    canManageBilling = false;
    billingSelfServe = false;

    try {
      var activeSession = current;
      var activeProfile = profile;

      if (activeProfile?.currentRestaurantId != restaurantId) {
        activeProfile = await _api.switchRestaurant(
          activeSession,
          restaurantId,
        );
        activeSession = activeSession.copyWith(
          restaurantId: activeProfile.currentRestaurantId ?? restaurantId,
          branchId: activeProfile.currentBranchId ?? activeSession.branchId,
          userId: activeProfile.user.id,
          userName: activeProfile.user.name,
          hasPosPin: activeProfile.user.hasPosPin,
        );
        session = activeSession;
        profile = activeProfile;
        await _storage.saveSession(activeSession);
      }

      if (activeProfile?.currentBranchId != branchId) {
        activeProfile = await _api.switchBranch(activeSession, branchId);
        activeSession = activeSession.copyWith(
          restaurantId:
              activeProfile.currentRestaurantId ?? activeSession.restaurantId,
          branchId: activeProfile.currentBranchId ?? branchId,
          userId: activeProfile.user.id,
          userName: activeProfile.user.name,
          hasPosPin: activeProfile.user.hasPosPin,
        );
        session = activeSession;
        profile = activeProfile;
        await _storage.saveSession(activeSession);
      }

      await _rememberCurrentLocation();
      _syncService?.configure(session);
      await _loadBootstrap();
      final next = await _resolvePostBootstrapPhase();
      phase = next;
      if (next == PosAppPhase.ready) {
        await _onEnteredReady(fromResume: fromResume);
      }
    } on PosApiException catch (e) {
      if (e.isSubscriptionBlocked) {
        _presentSubscriptionBlock(e);
      } else {
        errorMessage = posUserFacingError(e);
        phase = PosAppPhase.contextPicker;
      }
    }
  }

  Future<PosAppPhase> _resolvePostBootstrapPhase() async {
    final current = session;
    if (current == null) return PosAppPhase.login;

    if (!canUseRegister && !canUseCaptain && !canUseKitchen) {
      errorMessage =
          'Your account does not have Register, Captain, or Kitchen access.';
      return PosAppPhase.error;
    }

    var stored = await PosWorkModeStorage.read(current.branchId);
    if (stored != null && !_isWorkModeAllowed(stored)) {
      await PosWorkModeStorage.clear(current.branchId);
      stored = null;
    }

    if (stored == null) {
      final allowed = <PosWorkMode>[
        if (canUseRegister) PosWorkMode.register,
        if (canUseCaptain) PosWorkMode.waiter,
        if (canUseKitchen) PosWorkMode.kitchen,
      ];
      if (allowed.length == 1) {
        workMode = allowed.first;
        await PosWorkModeStorage.write(current.branchId, workMode!);
        return _resolveWorkModePhase(workMode!);
      }
      workMode = null;
      return PosAppPhase.modePicker;
    }

    workMode = stored;
    return _resolveWorkModePhase(stored);
  }

  Future<PosAppPhase> _resolveWorkModePhase(PosWorkMode mode) {
    return switch (mode) {
      PosWorkMode.waiter => _enterWaiterReadyPhase(),
      PosWorkMode.kitchen => _enterKitchenReadyPhase(),
      PosWorkMode.register => _resolveTerminalPhase(),
    };
  }

  Future<PosAppPhase> _enterKitchenReadyPhase() async {
    return PosAppPhase.ready;
  }

  /// Floating phone staff — terminal is optional.
  Future<PosAppPhase> _enterWaiterReadyPhase() async {
    final current = session;
    final storedCode = current == null
        ? null
        : await PosTerminalStorage.readTerminalCode(current.branchId);
    if (storedCode != null && storedCode.isNotEmpty && bootstrap != null) {
      for (final t in bootstrap!.posTerminals) {
        if (t.code == storedCode.toUpperCase()) {
          await _setTerminal(t);
          break;
        }
      }
    }
    return PosAppPhase.ready;
  }

  Future<void> _onEnteredReady({bool fromResume = false}) async {
    if (isKitchenMode) {
      _stopWaiterPolling();
      _stopRegisterAlertPolling();
      _stopNewOrderPolling();
      _stopPaymentSessionMonitoring();
      _startRevisionPolling();
      notifyListeners();
      return;
    }

    _startRevisionPolling();
    _bindCustomerDisplayBranding();
    unawaited(CustomerDisplayBroker.instance.initialize());
    _startPaymentSessionMonitoring();
    _scheduleDisplaySync();
    unawaited(refreshHeldOrderCount());
    if (isWaiterMode) {
      _stopRegisterAlertPolling();
      unawaited(refreshWaiterFloor());
      _startWaiterPolling();
      unawaited(refreshNewOrderAlerts(silent: true));
      _startNewOrderPolling();
    } else if (isRegisterMode) {
      _stopWaiterPolling();
      unawaited(refreshRegisterBillAlerts());
      _startRegisterAlertPolling();
      unawaited(refreshNewOrderAlerts(silent: true));
      _startNewOrderPolling();
      unawaited(_printJobs?.warmPrinter());
    } else {
      _stopWaiterPolling();
      _stopRegisterAlertPolling();
      _stopNewOrderPolling();
    }
    if (!fromResume && session?.hasPosPin != true) {
      offerSetPosPinPrompt = true;
    }
  }

  Future<void> selectWorkMode(PosWorkMode mode) async {
    final current = session;
    if (current == null) return;
    if (!_isWorkModeAllowed(mode)) return;

    workMode = mode;
    await PosWorkModeStorage.write(current.branchId, mode);

    if (mode == PosWorkMode.waiter || mode == PosWorkMode.kitchen) {
      phase = PosAppPhase.ready;
      await _onEnteredReady();
      notifyListeners();
      return;
    }

    final next = await _resolveTerminalPhase();
    phase = next;
    if (next == PosAppPhase.ready) {
      await _onEnteredReady();
    }
    notifyListeners();
  }

  /// Switch Register ↔ Waiter from the overflow / profile menus.
  Future<void> switchWorkMode(PosWorkMode mode) async {
    final current = session;
    if (current == null) return;
    if (workMode == mode) return;
    if (!_isWorkModeAllowed(mode)) return;

    // Changing roles is not a new login, including a first visit to POS
    // from Kitchen Display or Captain.
    _printerSetupShownForSession = true;
    workMode = mode;
    await PosWorkModeStorage.write(current.branchId, mode);

    if (mode == PosWorkMode.waiter) {
      // Always land on the waiter shell when switching from register/kitchen.
      if (phase != PosAppPhase.ready) {
        phase = PosAppPhase.ready;
      }
      await _onEnteredReady(fromResume: true);
      notifyListeners();
      return;
    }

    if (mode == PosWorkMode.kitchen) {
      _stopWaiterPolling();
      _stopRegisterAlertPolling();
      if (phase != PosAppPhase.ready) {
        phase = PosAppPhase.ready;
      }
      await _onEnteredReady(fromResume: true);
      notifyListeners();
      return;
    }

    _stopWaiterPolling();
    _stopRegisterAlertPolling();
    if (selectedTerminal == null &&
        (bootstrap?.posTerminals.isNotEmpty ?? false)) {
      phase = await _resolveTerminalPhase();
      if (phase == PosAppPhase.ready) {
        await _onEnteredReady(fromResume: true);
      }
      notifyListeners();
      return;
    }
    if (phase == PosAppPhase.ready) {
      await _onEnteredReady(fromResume: true);
    }
    notifyListeners();
  }

  Future<void> clearWorkModeAndPick() async {
    final current = session;
    if (current == null) return;
    // Only staff with both modes should see the picker.
    if (!canChooseWorkMode) return;
    await PosWorkModeStorage.clear(current.branchId);
    workMode = null;
    _stopWaiterPolling();
    _stopRegisterAlertPolling();
    phase = PosAppPhase.modePicker;
    notifyListeners();
  }

  void clearSetPosPinPrompt() {
    if (!offerSetPosPinPrompt) return;
    offerSetPosPinPrompt = false;
    notifyListeners();
  }

  Future<PosAppPhase> _resolveTerminalPhase() async {
    final current = session;
    final data = bootstrap;
    if (current == null || data == null) {
      return PosAppPhase.login;
    }

    final terminals = data.posTerminals;
    if (terminals.isEmpty) {
      selectedTerminal = null;
      selectedTerminalCode = null;
      return PosAppPhase.ready;
    }

    final storedCode = await PosTerminalStorage.readTerminalCode(
      current.branchId,
    );
    final binding = deviceBinding;
    final bindingCode = binding != null && binding.branchId == current.branchId
        ? binding.terminalCode
        : null;

    final preferredCode = (storedCode ?? bindingCode)?.toUpperCase();
    if (preferredCode != null && preferredCode.isNotEmpty) {
      PosTerminalInfo? match;
      for (final t in terminals) {
        if (t.code == preferredCode) {
          match = t;
          break;
        }
      }
      if (match != null) {
        await _setTerminal(match);
        return PosAppPhase.ready;
      }
    }

    if (terminals.length == 1) {
      await _setTerminal(terminals.first);
      return PosAppPhase.ready;
    }

    return PosAppPhase.terminalPicker;
  }

  /// Open the restaurant / branch picker without signing out.
  Future<void> openLocationPicker() async {
    final current = session;
    if (current == null) return;

    errorMessage = null;
    notifyListeners();

    try {
      profile = await _api.fetchMe(current);
      session = current.copyWith(
        restaurantId: profile!.currentRestaurantId ?? current.restaurantId,
        branchId: profile!.currentBranchId ?? current.branchId,
        userId: profile!.user.id,
        userName: profile!.user.name,
        hasPosPin: profile!.user.hasPosPin,
      );
      await _storage.saveSession(session!);
    } on PosApiException catch (e) {
      errorMessage = posUserFacingError(e);
      notifyListeners();
      return;
    }

    if (!canChangeLocation) {
      errorMessage = PosTranslationStore.instance.text(
        'contextNoOtherLocation',
        'No other restaurant or branch is available for this account.',
      );
      notifyListeners();
      return;
    }

    phase = PosAppPhase.contextPicker;
    notifyListeners();
  }

  Future<void> selectRestaurant(int restaurantId) async {
    final current = session;
    if (current == null) return;

    errorMessage = null;
    subscriptionBlocked = false;
    trialExpired = false;
    canManageBilling = false;
    billingSelfServe = false;
    notifyListeners();

    try {
      profile = await _api.switchRestaurant(current, restaurantId);
      session = current.copyWith(
        restaurantId: profile!.currentRestaurantId ?? restaurantId,
        branchId: profile!.currentBranchId ?? current.branchId,
        userName: profile!.user.name,
        hasPosPin: profile!.user.hasPosPin,
      );
      await _storage.saveSession(session!);

      final selected = profile!.restaurantOption(restaurantId);
      final branchCount = selected?.branches.length ?? 0;

      if (branchCount > 1) {
        phase = PosAppPhase.contextPicker;
        notifyListeners();
        return;
      }

      if (branchCount == 1) {
        final onlyBranchId = selected!.branches.first.id;
        if (profile!.currentBranchId != onlyBranchId) {
          await selectBranch(onlyBranchId);
          return;
        }
      }

      if (profile!.currentBranchId != null) {
        await _rememberCurrentLocation();
        await _loadBootstrap();
        phase = await _resolvePostBootstrapPhase();
        if (phase == PosAppPhase.ready) {
          await _onEnteredReady();
        }
      } else {
        phase = PosAppPhase.contextPicker;
      }
    } on PosApiException catch (e) {
      if (e.isSubscriptionBlocked) {
        _presentSubscriptionBlock(e);
      } else {
        errorMessage = posUserFacingError(e);
      }
    } catch (e) {
      errorMessage = posUserFacingError(e);
    }

    notifyListeners();
  }

  Future<void> selectBranch(int branchId) async {
    final current = session;
    if (current == null) return;

    errorMessage = null;
    subscriptionBlocked = false;
    trialExpired = false;
    canManageBilling = false;
    billingSelfServe = false;
    notifyListeners();

    try {
      profile = await _api.switchBranch(current, branchId);
      session = current.copyWith(
        restaurantId: profile!.currentRestaurantId ?? current.restaurantId,
        branchId: profile!.currentBranchId ?? branchId,
        userName: profile!.user.name,
        hasPosPin: profile!.user.hasPosPin,
      );
      await _storage.saveSession(session!);
      await _rememberCurrentLocation();
      await _loadBootstrap();
      phase = await _resolvePostBootstrapPhase();
      if (phase == PosAppPhase.ready) {
        await _onEnteredReady();
      }
    } on PosApiException catch (e) {
      if (e.isSubscriptionBlocked) {
        _presentSubscriptionBlock(e);
      } else {
        errorMessage = posUserFacingError(e);
      }
    } catch (e) {
      errorMessage = posUserFacingError(e);
    }

    notifyListeners();
  }

  Future<void> selectTerminal(PosTerminalInfo terminal) async {
    await _setTerminal(terminal);
    phase = PosAppPhase.ready;
    await _onEnteredReady();
    notifyListeners();
  }

  Future<void> _setTerminal(PosTerminalInfo terminal) async {
    final current = session;
    if (current == null) return;

    selectedTerminal = terminal;
    selectedTerminalCode = terminal.code;
    await PosTerminalStorage.writeTerminalCode(current.branchId, terminal.code);
  }

  void applyOpeningHoursPayload(PosOpeningHoursPayload payload) {
    final current = bootstrap;
    if (current == null) return;
    bootstrap = current.copyWith(
      guestOrdering: payload.guestOrdering,
      openingHours: payload.openingHours,
    );
    notifyListeners();
  }

  Future<bool> setGuestOrderingOpen(bool acceptOnlineOrders) async {
    final current = session;
    if (current == null) return false;
    errorMessage = null;
    try {
      final payload = await _api.setGuestOrderingOpen(
        current,
        acceptOnlineOrders: acceptOnlineOrders,
      );
      applyOpeningHoursPayload(payload);
      return true;
    } on PosApiException catch (e) {
      errorMessage = posUserFacingError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> startPairing() async {
    final url = serverUrl ?? PlatformConfig.platformUrl;
    errorMessage = null;
    _stopPairingPoll();
    pairingCode = null;
    pairingDeviceUuid = null;
    phase = PosAppPhase.pairDevice;
    notifyListeners();

    try {
      final result = await _api.startPairing(url);
      pairingCode = result.pairingCode;
      pairingDeviceUuid = result.deviceUuid;
      _startPairingPoll();
    } on PosApiException catch (e) {
      errorMessage = posUserFacingError(e);
    }

    notifyListeners();
  }

  void _startPairingPoll() {
    _pairingPollTimer?.cancel();
    _pairingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollPairingOnce();
    });
  }

  void _stopPairingPoll() {
    _pairingPollTimer?.cancel();
    _pairingPollTimer = null;
  }

  Future<void> _pollPairingOnce() async {
    final url = serverUrl ?? PlatformConfig.platformUrl;
    final uuid = pairingDeviceUuid;
    if (uuid == null || uuid.isEmpty) return;

    try {
      final json = await _api.pollPairing(url, uuid);
      final status = json['status'] as String? ?? '';

      if (status == 'paired') {
        final terminalJson =
            json['pos_terminal'] as Map<String, dynamic>? ?? {};
        final binding = PosDeviceBinding(
          restaurantId: parseJsonInt(json['restaurant_id']),
          branchId: parseJsonInt(json['branch_id']),
          terminalCode: (terminalJson['code'] as String? ?? '').toUpperCase(),
          restaurantName: json['restaurant_name'] as String?,
          branchName: json['branch_name'] as String?,
          terminalName: terminalJson['name'] as String?,
        );
        deviceBinding = binding;
        await PosDeviceBindingStorage.save(binding);
        _stopPairingPoll();
        pairingCode = null;
        pairingDeviceUuid = null;
        phase = PosAppPhase.login;
        errorMessage = null;
        notifyListeners();
      } else if (status == 'expired') {
        errorMessage = PosTranslationStore.instance.text(
          'pairCodeExpired',
          'Pairing code expired. Tap New code to try again.',
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshPairingCode() async {
    await startPairing();
  }

  void skipPairingToLogin() {
    _stopPairingPoll();
    pairingCode = null;
    pairingDeviceUuid = null;
    phase = PosAppPhase.login;
    notifyListeners();
  }

  void lockSession() {
    if (session?.hasPosPin == true) {
      _stopWaiterPolling();
      _stopRegisterAlertPolling();
      phase = PosAppPhase.locked;
      notifyListeners();
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final current = session;
    if (current == null) return false;

    errorMessage = null;
    notifyListeners();

    final userId = current.userId ?? profile?.user.id;

    // Only hit the API when connectivity is confidently online. Offline and
    // "checking" must use the local verifier — otherwise unlock hangs on HTTP
    // until the server comes back ("Unlocking…" forever).
    if (!isOnline) {
      return _unlockWithLocalPin(pin, userId);
    }

    try {
      await _api.verifyPosPin(current, pin).timeout(const Duration(seconds: 5));
      await _finishOnlinePinUnlock(current, pin: pin, userId: userId);
      return true;
    } on TimeoutException {
      return _unlockWithLocalPin(pin, userId);
    } on PosApiException catch (e) {
      if (_isNetworkError(e)) {
        return _unlockWithLocalPin(pin, userId);
      }
      errorMessage = posUserFacingError(e);
      notifyListeners();
      return false;
    } catch (e) {
      if (_isRawNetworkFailure(e)) {
        return _unlockWithLocalPin(pin, userId);
      }
      errorMessage = posUserFacingError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> _finishOnlinePinUnlock(
    PosSession current, {
    required String pin,
    int? userId,
  }) async {
    var resolvedUserId = userId;
    if (resolvedUserId == null || resolvedUserId <= 0) {
      try {
        profile = await _api.fetchMe(current);
        resolvedUserId = profile?.user.id;
      } catch (_) {
        // Local PIN cache is best-effort; unlock still proceeds.
      }
    }

    if (resolvedUserId != null && resolvedUserId > 0) {
      try {
        await PosLocalPinStorage.savePin(userId: resolvedUserId, pin: pin);
      } catch (_) {
        // Do not fail an otherwise valid online unlock if secure storage fails.
      }
      if (current.userId != resolvedUserId) {
        session = current.copyWith(userId: resolvedUserId);
        await _storage.saveSession(session!);
      }
    }

    phase = PosAppPhase.ready;
    errorMessage = null;
    notifyListeners();
    try {
      await _onEnteredReady(fromResume: true);
    } catch (_) {
      // Unlock already succeeded; sync can resume on the next online tick.
    }
  }

  Future<bool> _unlockWithLocalPin(String pin, int? userId) async {
    if (userId == null || userId <= 0) {
      errorMessage = PosTranslationStore.instance.text(
        'offlinePinNeedsNetwork',
        'Unlock once while online to enable offline PIN unlock on this device.',
      );
      notifyListeners();
      return false;
    }

    final hasLocal = await PosLocalPinStorage.hasPin(userId);
    if (!hasLocal) {
      errorMessage = PosTranslationStore.instance.text(
        'offlinePinNeedsNetwork',
        'Unlock once while online to enable offline PIN unlock on this device.',
      );
      notifyListeners();
      return false;
    }

    final ok = await PosLocalPinStorage.verifyPin(userId: userId, pin: pin);
    if (!ok) {
      errorMessage = PosTranslationStore.instance.text(
        'pinIncorrect',
        'Incorrect PIN',
      );
      notifyListeners();
      return false;
    }

    phase = PosAppPhase.ready;
    // Defer revision polling until we are online again.
    if (isOnline) {
      try {
        await _onEnteredReady(fromResume: true);
      } catch (_) {}
    }
    errorMessage = null;
    notifyListeners();
    return true;
  }

  Future<bool> savePosPin({
    required String pin,
    required String currentPassword,
  }) async {
    final current = session;
    if (current == null) return false;

    errorMessage = null;
    notifyListeners();

    try {
      await _api.setPosPin(current, pin: pin, currentPassword: currentPassword);
      profile = await _api.fetchMe(current);
      final userId = profile?.user.id ?? current.userId;
      session = current.copyWith(
        hasPosPin: true,
        userId: userId,
        userName: profile?.user.name ?? current.userName,
      );
      await _storage.saveSession(session!);
      if (userId != null && userId > 0) {
        await PosLocalPinStorage.savePin(userId: userId, pin: pin);
      }
      errorMessage = null;
      notifyListeners();
      return true;
    } on PosApiException catch (e) {
      errorMessage = posUserFacingError(e);
      notifyListeners();
      return false;
    }
  }

  void _presentSubscriptionBlock(PosApiException e) {
    subscriptionBlocked = true;
    trialExpired = e.trialExpired;
    canManageBilling = e.canManageBilling;
    billingSelfServe = e.billingSelfServe;
    final store = PosTranslationStore.instance;
    final fallback = e.canManageBilling
        ? (e.trialExpired
              ? store.text(
                  'billingUpgradeBody',
                  'Choose a plan to restore POS access for this restaurant.',
                )
              : store.text(
                  'billingRenewBody',
                  'Your subscription is inactive. Choose a plan to restore POS access.',
                ))
        : (e.trialExpired
              ? store.text(
                  'subscriptionTrialEndedBody',
                  'This restaurant\'s free trial has ended. Ask an owner to choose a plan to continue.',
                )
              : store.text(
                  'subscriptionEndedBody',
                  'This restaurant\'s subscription is inactive. Ask an owner to renew billing to keep using POS.',
                ));
    final apiMessage = e.message.trim();
    errorMessage = apiMessage.isNotEmpty && apiMessage.length <= 200
        ? apiMessage
        : fallback;
    phase = PosAppPhase.error;
  }

  Future<void> logout() async {
    _printerSetupShownForSession = false;
    _stopPairingPoll();
    _stopWaiterPolling();
    _stopRegisterAlertPolling();
    _stopNewOrderPolling();
    _cancelDisplaySync();
    _stopPaymentSessionMonitoring();
    await _clearDisplaySyncNow();
    final current = session;
    if (current != null) {
      try {
        await _api.logout(current);
      } catch (_) {}
    }
    await _storage.clearSession();
    session = null;
    _syncService?.configure(null);
    profile = null;
    bootstrap = null;
    workMode = null;
    _kitchenApiToken = null;
    subscriptionBlocked = false;
    trialExpired = false;
    canManageBilling = false;
    billingSelfServe = false;
    errorMessage = null;
    waiterTables = const [];
    waiterTableAreas = const [];
    waiterTablesWithoutArea = const [];
    tablesSnapshot = null;
    waiterHeldOrders = const [];
    waiterRecentOrders = const [];
    waiterAlerts = const [];
    billRequestedTableIds = {};
    waiterLastRefreshedAt = null;
    _waiterAlertsHydrated = false;
    _registerFloorPrimed = false;
    _registerFloorSnapshot = const [];
    _newOrdersSynced = false;
    _newOrdersLastSeenId = null;
    _newOrderBannerQueue.clear();
    _selfPlacedOrderIds.clear();
    marketplaceOpenOrderCounts = const {};
    waiterFocusTableId = null;
    registerBannerAlert = null;
    _newOrderBannerQueue.clear();
    _stopRegisterAlertPolling();
    appUpdate = PosAppUpdate.none();
    _dismissedOptionalLatest = null;
    selectedTerminal = null;
    selectedTerminalCode = null;
    offerSetPosPinPrompt = false;
    _stopRevisionPolling();
    clearCart();
    phase = PosAppPhase.login;
    notifyListeners();
  }

  Future<void> refreshBootstrap() async {
    await _loadBootstrap();
    _rememberSyncRevisions();
    notifyListeners();
  }

  void dismissOptionalUpdate() {
    _dismissedOptionalLatest = _updateNoticeKey;
    notifyListeners();
  }

  /// Staff-triggered update check (⋮ → Check for updates).
  Future<PosUpdateCheckResult> checkForUpdates() async {
    final current = session;
    if (current == null || phase != PosAppPhase.ready) {
      return PosUpdateCheckResult.unavailable;
    }
    if (checkingForUpdates) {
      return PosUpdateCheckResult.busy;
    }

    checkingForUpdates = true;
    notifyListeners();

    try {
      final status = await _api.fetchSync(current);
      _dismissedOptionalLatest = null;
      _applyAppUpdate(status.appUpdate, manual: true);

      final needsBootstrap =
          (status.bootstrapRevision ?? '').isNotEmpty &&
          status.bootstrapRevision != _bootstrapRevision;
      if (needsBootstrap) {
        await _loadBootstrap();
        _rememberSyncRevisions();
      }

      notifyListeners();

      if (appUpdate.isRequired) {
        return PosUpdateCheckResult.required;
      }
      if (appUpdate.isOptional) {
        return PosUpdateCheckResult.optional;
      }
      return PosUpdateCheckResult.upToDate;
    } catch (_) {
      return PosUpdateCheckResult.failed;
    } finally {
      checkingForUpdates = false;
      notifyListeners();
    }
  }

  void _applyAppUpdate(PosAppUpdate update, {bool manual = false}) {
    final resolved = update.resolvedAgainstInstalled();
    // Required and optional updates both surface as the header strip.
    // Later keeps the current version hidden until the next launch, or until
    // staff open Check for updates (that path clears the dismissal first).
    appUpdate = resolved;
    if (manual) {
      _dismissedOptionalLatest = null;
    }
  }

  void _startRevisionPolling() {
    _revisionPollTimer?.cancel();
    _rememberSyncRevisions();
    _revisionPollTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(_checkForRemoteUpdates());
    });
  }

  void _stopRevisionPolling() {
    _revisionPollTimer?.cancel();
    _revisionPollTimer = null;
  }

  void _rememberSyncRevisions() {
    _bootstrapRevision = bootstrap?.sync?.bootstrapRevision;
    _menuRevision = bootstrap?.sync?.menuRevision;
  }

  Future<void> _checkForRemoteUpdates() async {
    final current = session;
    if (current == null ||
        phase != PosAppPhase.ready ||
        _revisionSyncInProgress) {
      return;
    }

    _revisionSyncInProgress = true;
    try {
      final status = await _api.fetchSync(current);
      final previousUpdateSignature =
          '${appUpdate.latestVersion}|${appUpdate.isRequired}|${appUpdate.isOptional}|${appUpdate.hasDownload}';
      _applyAppUpdate(status.appUpdate);
      final updateSignature =
          '${appUpdate.latestVersion}|${appUpdate.isRequired}|${appUpdate.isOptional}|${appUpdate.hasDownload}';

      final needsBootstrap =
          (status.bootstrapRevision ?? '').isNotEmpty &&
          status.bootstrapRevision != _bootstrapRevision;
      final needsMenu =
          (status.menuRevision ?? '').isNotEmpty &&
          status.menuRevision != _menuRevision;

      if (!needsBootstrap && !needsMenu) {
        if (updateSignature != previousUpdateSignature) {
          notifyListeners();
        }
        return;
      }

      await _loadBootstrap();
      _rememberSyncRevisions();
      notifyListeners();
    } catch (_) {
      // Keep current bootstrap; next poll will retry.
    } finally {
      _revisionSyncInProgress = false;
    }
  }

  Future<void> openShift(double openingFloat, {String? notes}) async {
    final current = session;
    if (current == null) return;

    await _api.openShift(current, openingFloat: openingFloat, notes: notes);
    await _loadBootstrap();
    notifyListeners();
  }

  Future<PosShiftCloseSummary> fetchShiftCloseSummary() async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }
    return _api.fetchShiftCloseSummary(current);
  }

  Future<void> closeShift(double closingCash, {String? notes}) async {
    final current = session;
    if (current == null) return;

    await _api.closeShift(current, closingCash: closingCash, notes: notes);
    await _loadBootstrap();
    notifyListeners();
  }

  void selectCategory(int? categoryId) {
    if (selectedCategoryId == categoryId && searchQuery.isEmpty) return;
    selectedCategoryId = categoryId;
    searchQuery = '';
    _itemsToDisplayCache = null;
    _itemsToDisplayKey = null;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    if (searchQuery == value) return;
    searchQuery = value;
    _itemsToDisplayCache = null;
    _itemsToDisplayKey = null;
    notifyListeners();
  }

  void setOrderType(String type) {
    final allowed =
        bootstrap?.restaurant.ordering.activePosOrderTypes ?? const <String>[];
    if (allowed.isNotEmpty && !allowed.contains(type)) {
      return;
    }
    orderType = type;
    if (type != 'dine_in') {
      tableId = null;
      tableLabel = null;
    }
    _scheduleDisplaySync();
    notifyListeners();
  }

  void setTableId(int? id, {String? name}) {
    tableId = id;
    tableLabel = (id == null)
        ? null
        : (name?.trim().isNotEmpty == true ? name!.trim() : tableLabel);
    _scheduleDisplaySync();
    notifyListeners();
  }

  void setCustomer({int? id, String? name}) {
    customerId = id;
    final trimmed = name?.trim();
    customerName = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    _scheduleDisplaySync();
    notifyListeners();
  }

  void clearCustomer() {
    customerId = null;
    customerName = null;
    _scheduleDisplaySync();
    notifyListeners();
  }

  void setOrderNotes(String? notes) {
    final trimmed = notes?.trim();
    final next = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    if (orderNotes == next) return;
    orderNotes = next;
    notifyListeners();
  }

  void setDiscount(CartDiscount? value) {
    discount = value;
    _scheduleDisplaySync();
    notifyListeners();
  }

  void _ensureOrderTypeAllowed() {
    final allowed = bootstrap?.restaurant.ordering.posOrderTypes ?? const [];
    if (allowed.isEmpty) {
      return;
    }
    if (!allowed.contains(orderType)) {
      orderType = allowed.first;
    }
  }

  void addToCart(CartLine line) {
    final existing = cart.indexWhere(
      (c) =>
          c.menuItem.id == line.menuItem.id &&
          c.variant?.id == line.variant?.id &&
          _modifiersMatch(c.selectedModifiers, line.selectedModifiers) &&
          (c.notes ?? '') == (line.notes ?? ''),
    );

    if (existing >= 0) {
      cart[existing] = cart[existing].copyWith(
        quantity: cart[existing].quantity + line.quantity,
      );
      _revealCartLine(existing);
    } else {
      cart.add(line);
      _revealCartLine(cart.length - 1);
    }
    PosCartSound.instance.playAddToCart();
    _markCartChanged();
    _scheduleDisplaySync();
    notifyListeners();
  }

  bool _modifiersMatch(List<ModifierOption> a, List<ModifierOption> b) {
    if (a.length != b.length) return false;
    final aIds = a.map((m) => m.id).toSet();
    final bIds = b.map((m) => m.id).toSet();
    return aIds.length == bIds.length && aIds.containsAll(bIds);
  }

  void updateCartQty(CartLine line, int quantity) {
    if (quantity <= 0) {
      cart.remove(line);
    } else {
      final index = cart.indexOf(line);
      if (index >= 0) {
        cart[index] = line.copyWith(quantity: quantity);
      }
    }
    _markCartChanged();
    _scheduleDisplaySync();
    notifyListeners();
  }

  void updateCartLineNotes(CartLine line, String notes) {
    final index = cart.indexOf(line);
    if (index < 0) return;
    final trimmed = notes.trim();
    final next = trimmed.isEmpty
        ? line.copyWith(clearNotes: true)
        : line.copyWith(notes: notes);
    if ((cart[index].notes ?? '') == (next.notes ?? '')) return;
    cart[index] = next;
    _markCartChanged();
    notifyListeners();
  }

  int cartQuantityForMenuItem(int menuItemId) {
    return cartQtyByMenuItemId[menuItemId] ?? 0;
  }

  CartLine? simpleCartLineFor(MenuItem item) {
    if (item.hasOptions) {
      return null;
    }
    return simpleCartLineByMenuItemId[item.id];
  }

  double minDisplayPrice(MenuItem item) {
    if (item.variants.isEmpty) {
      return item.price;
    }

    var minPrice = item.price;
    for (final variant in item.variants) {
      if (variant.price < minPrice) {
        minPrice = variant.price;
      }
    }
    return minPrice;
  }

  void incrementSimpleCartLine(CartLine line) {
    final index = cart.indexOf(line);
    updateCartQty(line, line.quantity + 1);
    if (index >= 0) _revealCartLine(index);
    PosCartSound.instance.playAddToCart();
  }

  void decrementSimpleCartLine(CartLine line) {
    updateCartQty(line, line.quantity - 1);
  }

  void removeFromCart(CartLine line) {
    cart.remove(line);
    _markCartChanged();
    _scheduleDisplaySync();
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    waiterSentCart = [];
    customerName = null;
    customerId = null;
    tableId = null;
    tableLabel = null;
    orderNotes = null;
    discount = null;
    lastOrder = null;
    parkedOrderId = null;
    parkedLocalUuid = null;
    parkedOrderLabel = null;
    parkedAmountPaid = 0;
    parkedPaymentStatus = null;
    waiterGuestCount = null;
    cartQuickPayMethod = 'cash';
    cartRevealIndex = null;
    cartRevealGeneration++;
    _markCartChanged();
    _scheduleDisplaySync();
    notifyListeners();
  }

  int get waiterSentItemCount =>
      waiterSentCart.fold(0, (sum, line) => sum + line.quantity);

  bool get hasWaiterSentItems => waiterSentCart.isNotEmpty;

  /// Lines already sent + newly added (for park/sync payload).
  List<CartLine> get _waiterParkPayloadCart => [...waiterSentCart, ...cart];

  Future<List<Map<String, dynamic>>> fetchHeldOrders() async {
    final current = session;
    if (current == null) return const [];

    final local = await LocalHeldOrderStore.listForBranch(current.branchId);
    final localRows = local.map((e) => e.toListRow()).toList();

    if (!isOnline) {
      _cacheHeldRows(current, localRows);
      return localRows;
    }

    var server = const <Map<String, dynamic>>[];
    final draftsFuture = _paymentDraftRows(current);
    try {
      server = await _api.fetchOpenOrders(current);
    } catch (_) {
      server = const [];
    }
    final drafts = await draftsFuture;
    final seen = server
        .map((order) => parseJsonIntOrNull(order['id']))
        .whereType<int>()
        .toSet();
    final extra = drafts.where((order) {
      final id = parseJsonIntOrNull(order['id']);
      return id != null && seen.add(id);
    });
    final rows = [...localRows, ...server, ...extra];
    _cacheHeldRows(current, rows);
    return rows;
  }

  Future<List<Map<String, dynamic>>> fetchLocalHeldOrders() async {
    final current = session;
    if (current == null) return const [];
    final local = await LocalHeldOrderStore.listForBranch(current.branchId);
    if (!identical(current, session)) return const [];
    return local.map((order) => order.toListRow()).toList();
  }

  Future<List<Map<String, dynamic>>> _paymentDraftRows(
    PosSession current,
  ) async {
    try {
      final page = await _api.fetchAdminOrders(
        current,
        status: 'draft',
        period: 'today',
      );
      return page.orders
          .where((order) => (order.source ?? '').toLowerCase().trim() != 'pos')
          .map(
            (order) => {
              'id': order.id,
              'order_number': order.orderNumber,
              'status': 'draft',
              'payment_status': order.paymentStatus,
              'payment_method': order.paymentMethod,
              'type': order.type,
              'source': order.source,
              'total': order.total,
              'amount_due': order.total,
              'token': order.token,
              'customer_name': order.customerName,
              'table_name': order.tableName,
              'created_at': order.createdAt?.toIso8601String(),
              'payment_hint': order.paymentHint,
              'is_payment_draft': true,
            },
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> refreshHeldOrderCount() {
    if (_heldCountInFlight != null) {
      _heldCountDirty = true;
      return _heldCountInFlight!;
    }
    late final Future<void> run;
    run = _refreshHeldOrderCountNow().whenComplete(() {
      if (identical(_heldCountInFlight, run)) _heldCountInFlight = null;
      if (!_heldCountDirty) return;
      _heldCountDirty = false;
      unawaited(refreshHeldOrderCount());
    });
    _heldCountInFlight = run;
    return run;
  }

  Future<void> _refreshHeldOrderCountNow() async {
    final current = session;
    if (current == null) {
      heldOrderCount = 0;
      todayOrderCount = 0;
      marketplaceOpenOrderCounts = const {};
      notifyListeners();
      return;
    }

    final localRows = (await LocalHeldOrderStore.listForBranch(
      current.branchId,
    )).map((order) => order.toListRow()).toList();
    final localCount = localRows.length;
    var serverCount = 0;
    var todayCount = todayOrderCount;
    var partnerCounts = Map<String, int>.from(marketplaceOpenOrderCounts);
    if (isOnline) {
      try {
        final draftsFuture = _paymentDraftRows(current);
        final orders = await _api.fetchOpenOrders(current);
        for (final order in orders) {
          await _rememberOnlineToken(current, order['token']);
        }
        final drafts = await draftsFuture;
        final seen = orders
            .map((order) => parseJsonIntOrNull(order['id']))
            .whereType<int>()
            .toSet();
        serverCount =
            orders.length +
            drafts.where((order) {
              final id = parseJsonIntOrNull(order['id']);
              return id != null && !seen.contains(id);
            }).length;
        _cacheHeldRows(current, [
          ...localRows,
          ...orders,
          ...drafts.where((order) {
            final id = parseJsonIntOrNull(order['id']);
            return id != null && !seen.contains(id);
          }),
        ]);
      } catch (_) {
        // Keep local count on transient failures.
      }
      try {
        final data = await _api.fetchRecentOrders(
          current,
          filter: 'today',
          page: 1,
          perPage: 5,
        );
        final recentOrders = data['orders'];
        if (recentOrders is List) {
          for (final order in recentOrders.whereType<Map>()) {
            await _rememberOnlineToken(current, order['token']);
          }
        }
        final meta = data['meta'];
        if (meta is Map) {
          todayCount = parseJsonInt(meta['total']);
        }
      } catch (_) {
        // Keep last today count on transient failures.
      }

      final platforms = bootstrap?.marketplacePlatforms ?? const [];
      if (platforms.isNotEmpty) {
        final next = <String, int>{};
        await Future.wait(
          platforms.map((platform) async {
            final key = platform.provider.toLowerCase().trim();
            if (key.isEmpty) return;
            try {
              // API requires per_page >= 5; we only need summary.open.
              final data = await _api.fetchRecentOrders(
                current,
                filter: key,
                page: 1,
                perPage: 5,
              );
              final summary = data['summary'];
              if (summary is Map && summary['open'] != null) {
                next[key] = parseJsonInt(summary['open']);
              } else {
                // Fallback for older API builds.
                final meta = data['meta'];
                next[key] = meta is Map ? parseJsonInt(meta['total']) : 0;
              }
            } catch (_) {
              next[key] = partnerCounts[key] ?? 0;
            }
          }),
        );
        partnerCounts = next;
      } else {
        partnerCounts = {};
      }
    }
    heldOrderCount = localCount + serverCount;
    todayOrderCount = todayCount;
    marketplaceOpenOrderCounts = partnerCounts;
    notifyListeners();
  }

  void _bumpMarketplaceOpenCount(String? source) {
    if (!isMarketplaceOrderSource(source)) return;
    final key = source!.toLowerCase().trim();
    final next = Map<String, int>.from(marketplaceOpenOrderCounts);
    next[key] = (next[key] ?? 0) + 1;
    marketplaceOpenOrderCounts = next;
  }

  Map<String, dynamic>? tablesSnapshot;

  Future<Map<String, dynamic>> fetchTables() async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }
    final data = await _api.fetchTables(current);
    tablesSnapshot = data;
    return data;
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }
    return _api.searchCustomers(current, query: query);
  }

  /// Creates a restaurant customer and returns `{id, name, phone, …}`.
  Future<Map<String, dynamic>> createCustomer({
    required String name,
    String? phone,
    String? email,
  }) async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }
    return _api.createCustomer(current, name: name, phone: phone, email: email);
  }

  /// Discard a held draft (local delete or server soft-cancel).
  Future<void> discardHeldOrder({int? orderId, String? localUuid}) async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }

    if (localUuid != null && localUuid.isNotEmpty) {
      await LocalHeldOrderStore.delete(localUuid);
      if (parkedLocalUuid == localUuid) {
        parkedLocalUuid = null;
        parkedOrderId = null;
        parkedOrderLabel = null;
        clearCart();
      }
      unawaited(refreshHeldOrderCount());
      notifyListeners();
      return;
    }

    if (orderId == null) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'ordersNumberMissing',
          'Order number is missing.',
        ),
      );
    }

    await _api.updateOrderStatus(
      current,
      orderId: orderId,
      status: 'cancelled',
    );

    if (parkedOrderId == orderId) {
      parkedOrderId = null;
      parkedLocalUuid = null;
      parkedOrderLabel = null;
      clearCart();
    }

    unawaited(refreshHeldOrderCount());
    notifyListeners();
  }

  Future<void> resumeHeldOrder({int? orderId, String? localUuid}) async {
    if (localUuid != null && localUuid.isNotEmpty) {
      await _resumeLocalHeldOrder(localUuid);
      return;
    }
    if (orderId == null) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'ordersNumberMissing',
          'Order number is missing.',
        ),
      );
    }

    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }

    final payload = await _api.fetchOrderForResume(current, orderId: orderId);
    final summary = payload['order'] as Map<String, dynamic>? ?? const {};
    final form = payload['form'] as Map<String, dynamic>? ?? const {};
    final cartRows =
        (payload['cart'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];

    _applyResumeCartAndForm(
      cartRows: cartRows,
      form: form,
      discountJson: payload['discount'],
    );

    parkedOrderId = orderId;
    parkedLocalUuid = null;
    final token = summary['token'];
    parkedOrderLabel = token != null
        ? PosTranslationStore.instance.text(
            'ordersTokenLabel',
            'Token {token}',
            replacements: {'token': '$token'},
          )
        : (summary['order_number'] as String? ?? '#$orderId');
    _rememberParkedPayment(summary);

    _scheduleDisplaySync();
    unawaited(refreshHeldOrderCount());
    notifyListeners();
  }

  Future<void> _resumeLocalHeldOrder(String localUuid) async {
    final held = await LocalHeldOrderStore.get(localUuid);
    if (held == null) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlineHeldNotFound',
          'That held ticket is no longer on this device.',
        ),
      );
    }

    final payload = held.payload;
    final cartRows =
        (payload['resume_cart'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];

    _applyResumeCartAndForm(
      cartRows: cartRows,
      form: {
        'type': payload['type'],
        'customer_name': payload['customer_name'],
        'customer_id': payload['customer_id'],
        'table_id': payload['table_id'],
        'notes': payload['notes'],
      },
      discountJson: payload['discount'],
    );

    parkedOrderId = null;
    parkedLocalUuid = localUuid;
    parkedOrderLabel = held.localOrderNumber;
    _forgetParkedPayment();

    _scheduleDisplaySync();
    unawaited(refreshHeldOrderCount());
    notifyListeners();
  }

  void _applyResumeCartAndForm({
    required List<Map<String, dynamic>> cartRows,
    required Map<String, dynamic> form,
    required Object? discountJson,
  }) {
    cart
      ..clear()
      ..addAll(cartRows.map(_cartLineFromResumePayload));
    _markCartChanged();

    final type = form['type'] as String?;
    if (type != null && type.isNotEmpty) {
      orderType = type;
    }
    final name = form['customer_name'] as String?;
    customerName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : null;
    final rawCustomerId = form['customer_id'];
    customerId = rawCustomerId == null || '$rawCustomerId'.isEmpty
        ? null
        : parseJsonIntOrNull(rawCustomerId);
    final rawTableId = form['table_id'];
    tableId = rawTableId == null || '$rawTableId'.isEmpty
        ? null
        : parseJsonIntOrNull(rawTableId);
    final notes = form['notes'] as String?;
    orderNotes = (notes != null && notes.trim().isNotEmpty)
        ? notes.trim()
        : null;
    discount = discountJson is Map
        ? CartDiscount.tryParse(Map<String, dynamic>.from(discountJson))
        : null;
  }

  CartLine _cartLineFromResumePayload(Map<String, dynamic> row) {
    final menuItemId = parseJsonInt(row['menu_item_id']);
    final variantId = parseJsonIntOrNull(row['variant_id']);
    final quantity = parseJsonInt(row['quantity'], fallback: 1);
    final notes = row['notes'] as String?;
    final name = row['menu_item_name'] as String? ?? 'Item';
    final unitPrice = parseJsonDouble(row['unit_price']);

    MenuItem? live;
    for (final item in flatItems) {
      if (item.id == menuItemId) {
        live = item;
        break;
      }
    }

    final modRows =
        (row['modifiers'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];

    final selectedMods = <ModifierOption>[];
    for (final mod in modRows) {
      final optionId = parseJsonInt(mod['modifier_option_id']);
      ModifierOption? matched;
      if (live != null) {
        for (final group in live.modifiers) {
          for (final option in group.options) {
            if (option.id == optionId) {
              matched = option;
              break;
            }
          }
          if (matched != null) break;
        }
      }
      selectedMods.add(
        matched ??
            ModifierOption(
              id: optionId,
              name:
                  mod['option_name'] as String? ??
                  mod['modifier_name'] as String? ??
                  'Option',
              priceAdjustment: parseJsonDouble(mod['price_adjustment']),
            ),
      );
    }

    MenuVariant? variant;
    if (live != null && variantId != null) {
      for (final v in live.variants) {
        if (v.id == variantId) {
          variant = v;
          break;
        }
      }
    }

    final menuItem =
        live ??
        MenuItem(
          id: menuItemId,
          name: name,
          price: unitPrice,
          variants: variantId != null
              ? [MenuVariant(id: variantId, name: 'Variant', price: unitPrice)]
              : const [],
          modifiers: const [],
        );

    if (live == null && variantId != null && variant == null) {
      variant = MenuVariant(id: variantId, name: 'Variant', price: unitPrice);
    }

    return CartLine(
      menuItem: menuItem,
      variant: variant,
      selectedModifiers: selectedMods,
      quantity: quantity < 1 ? 1 : quantity,
      notes: (notes != null && notes.isNotEmpty) ? notes : null,
    );
  }

  Future<List<MenuItem>> fetchCheckoutUpsells() async {
    final current = session;
    if (current == null || cart.isEmpty) {
      return [];
    }
    final ids = cart.map((line) => line.menuItem.id).toList();
    try {
      return await _api.fetchCheckoutUpsells(current, menuItemIds: ids);
    } on PosApiException {
      return [];
    }
  }

  Future<PlacedPosOrder> submitOrder({
    required String paymentMethod,
    double? cashTendered,
    double? tip,
    bool allowOffline = true,
  }) async {
    final current = session;
    if (current == null || cart.isEmpty) {
      throw PosApiException(
        PosTranslationStore.instance.text('cartIsEmptyError', 'Cart is empty.'),
      );
    }

    final canOffline =
        allowOffline &&
        isOfflineAllowedPaymentMethod(paymentMethod) &&
        !isQrPaymentMethod(paymentMethod);

    if (isOffline && !canOffline) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlinePaymentBlocked',
          'This payment method needs a network connection. Use cash or another offline method.',
        ),
      );
    }

    submitting = true;
    notifyListeners();

    String? saleKey;
    final payment = {
      'method': paymentMethod,
      if (cashTendered != null) 'cash_tendered': cashTendered,
      if (tip != null && tip > 0) 'tip': tip,
    };

    try {
      final heldId = parkedOrderId;
      final localHeldUuid = parkedLocalUuid;

      // Server-held tickets still need the pay endpoint (not offline-queued).
      if (heldId != null && localHeldUuid == null && isOffline) {
        throw PosApiException(
          PosTranslationStore.instance.text(
            'offlineHeldPayBlocked',
            'Held tickets need a network connection to settle.',
          ),
        );
      }

      // Local held: settle offline as a queued create-order, or createOrder online.
      if (localHeldUuid != null) {
        return _settleLocalHeldTicket(
          localUuid: localHeldUuid,
          payment: payment,
          canOffline: canOffline,
        );
      }

      // Network is already down. Save cash, card, wallet, or other on this
      // register and print from that saved order. Do not wait on the server.
      if (isOffline && canOffline && heldId == null) {
        final offlineOrder = await _createOfflineOrder(payment);
        return _finishOfflineSale(offlineOrder);
      }

      final PlacedPosOrder order;
      if (heldId != null) {
        final data = await _api.payOrder(
          current,
          orderId: heldId,
          payment: payment,
          items: cart.map((line) => line.toOrderJson()).toList(),
          type: orderType,
          tableId: _tableIdForPayload,
          customerId: customerId,
          customerName: customerName,
          notes: orderNotes,
          discount: _discountPayload,
        );
        final orderJson = data['order'] as Map<String, dynamic>?;
        if (orderJson == null) {
          throw PosApiException('Pay response missing order payload.');
        }
        final paymentPayload = data['payment'];
        order = PlacedPosOrder.fromJson({
          ...orderJson,
          if (paymentPayload is Map<String, dynamic>) 'payment': paymentPayload,
        });
      } else {
        saleKey = const Uuid().v4();
        order = await _api.createOrder(
          current,
          items: cart.map((line) => line.toOrderJson()).toList(),
          type: orderType,
          posTerminalId: selectedTerminal?.id,
          tableId: _tableIdForPayload,
          customerId: customerId,
          customerName: customerName,
          notes: orderNotes,
          discount: _discountPayload,
          payment: payment,
          idempotencyKey: saleKey,
        );
      }
      lastOrder = order;
      await _rememberOnlineToken(current, order.token);
      registerSelfPlacedOrder(order.id);
      lastOfflineOrder = null;
      clearCart();
      todayOrderCount += 1;
      notifyListeners();
      return order;
    } on PosApiException catch (e) {
      if (parkedOrderId == null &&
          parkedLocalUuid == null &&
          canOffline &&
          _syncService != null &&
          _canQueueOffline(e)) {
        final offlineOrder = await _createOfflineOrder(
          payment,
          idempotencyKey: saleKey,
        );
        return _finishOfflineSale(offlineOrder);
      }
      rethrow;
    } catch (e) {
      if (parkedOrderId == null &&
          parkedLocalUuid == null &&
          canOffline &&
          _syncService != null &&
          _canQueueOffline(e)) {
        final offlineOrder = await _createOfflineOrder(
          payment,
          idempotencyKey: saleKey,
        );
        return _finishOfflineSale(offlineOrder);
      }
      rethrow;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<PlacedPosOrder> _settleLocalHeldTicket({
    required String localUuid,
    required Map<String, dynamic> payment,
    required bool canOffline,
  }) async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }

    // Persist latest cart edits onto the local held row before settle.
    await LocalHeldOrderStore.updateCart(
      localUuid: localUuid,
      cart: cart,
      orderType: orderType,
      tableId: _tableIdForPayload,
      customerId: customerId,
      customerName: customerName,
      notes: orderNotes,
      discount: _discountPayload,
    );

    if (isOnline) {
      try {
        final order = await _api.createOrder(
          current,
          items: cart.map((line) => line.toOrderJson()).toList(),
          type: orderType,
          posTerminalId: selectedTerminal?.id,
          tableId: _tableIdForPayload,
          customerId: customerId,
          customerName: customerName,
          notes: orderNotes,
          discount: _discountPayload,
          payment: payment,
          idempotencyKey: localUuid,
        );
        await LocalHeldOrderStore.delete(localUuid);
        lastOrder = order;
        await _rememberOnlineToken(current, order.token);
        registerSelfPlacedOrder(order.id);
        lastOfflineOrder = null;
        clearCart();
        unawaited(refreshHeldOrderCount());
        return order;
      } on PosApiException catch (e) {
        if (!(canOffline && _isNetworkError(e))) rethrow;
      } on TimeoutException {
        if (!canOffline) rethrow;
      }
    }

    if (!canOffline || _syncService == null) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlinePaymentBlocked',
          'This payment method needs a network connection. Use cash or another offline method.',
        ),
      );
    }

    final offlineOrder = await _createOfflineOrder(
      payment,
      idempotencyKey: localUuid,
    );
    await LocalHeldOrderStore.delete(localUuid);
    final placed = _finishOfflineSale(offlineOrder);
    unawaited(refreshHeldOrderCount());
    return placed;
  }

  /// Settle a local held ticket from the Held sheet without clobbering the cart.
  Future<PlacedPosOrder> settleLocalHeldOrder({
    required String localUuid,
    required Map<String, dynamic> payment,
  }) async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }

    final method = '${payment['method'] ?? ''}';
    final canOffline =
        isOfflineAllowedPaymentMethod(method) && !isQrPaymentMethod(method);

    if (isOffline && !canOffline) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlinePaymentBlocked',
          'This payment method needs a network connection. Use cash or another offline method.',
        ),
      );
    }

    final held = await LocalHeldOrderStore.get(localUuid);
    if (held == null) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlineHeldNotFound',
          'That held ticket is no longer on this device.',
        ),
      );
    }

    final payload = held.payload;
    final cartRows =
        (payload['resume_cart'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final lines = cartRows.map(_cartLineFromResumePayload).toList();
    if (lines.isEmpty) {
      throw PosApiException(
        PosTranslationStore.instance.text('cartIsEmptyError', 'Cart is empty.'),
      );
    }

    final orderType = payload['type'] as String? ?? 'dine_in';
    final tableId = parseJsonIntOrNull(payload['table_id']);
    final customerId = parseJsonIntOrNull(payload['customer_id']);
    final customerName = payload['customer_name'] as String?;
    final notes = payload['notes'] as String?;
    final discountRaw = payload['discount'];
    final discount = discountRaw is Map
        ? Map<String, dynamic>.from(discountRaw)
        : null;

    submitting = true;
    notifyListeners();
    try {
      if (isOnline) {
        try {
          final order = await _api.createOrder(
            current,
            items: lines.map((line) => line.toOrderJson()).toList(),
            type: orderType,
            posTerminalId: selectedTerminal?.id,
            tableId: tableId,
            customerId: customerId,
            customerName: customerName,
            notes: notes,
            discount: discount,
            payment: payment,
            idempotencyKey: localUuid,
          );
          await LocalHeldOrderStore.delete(localUuid);
          if (parkedLocalUuid == localUuid) {
            clearCart();
          }
          lastOrder = order;
          await _rememberOnlineToken(current, order.token);
          registerSelfPlacedOrder(order.id);
          lastOfflineOrder = null;
          unawaited(refreshHeldOrderCount());
          return order;
        } on PosApiException catch (e) {
          if (!(canOffline && _isNetworkError(e))) rethrow;
        } on TimeoutException {
          if (!canOffline) rethrow;
        }
      }

      if (!canOffline || _syncService == null) {
        throw PosApiException(
          PosTranslationStore.instance.text(
            'offlinePaymentBlocked',
            'This payment method needs a network connection. Use cash or another offline method.',
          ),
        );
      }

      final offlineOrder = await _syncService!.createOfflineOrder(
        cart: lines,
        orderType: orderType,
        payment: payment,
        posTerminalId: selectedTerminal?.id,
        tableId: tableId,
        customerId: customerId,
        customerName: customerName,
        notes: notes,
        discount: discount,
        idempotencyKey: localUuid,
      );
      await LocalHeldOrderStore.delete(localUuid);
      final wasOpen = parkedLocalUuid == localUuid;
      final placed = _finishOfflineSale(offlineOrder, clearOpenCart: wasOpen);
      unawaited(refreshHeldOrderCount());
      return placed;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  bool _canQueueOffline(Object error) {
    if (isOffline) return true;
    if (error is PosApiException) return _isNetworkError(error);
    return _isRawNetworkFailure(error);
  }

  bool _isNetworkError(PosApiException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('connection') ||
        msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('timed out') ||
        msg.contains('cannot reach') ||
        msg.contains('could not reach') ||
        msg.contains('check your connection') ||
        msg.contains('cannot connect') ||
        msg.contains('socketexception') ||
        msg.contains('clientexception') ||
        msg.contains('failed host lookup');
  }

  bool _isRawNetworkFailure(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('clientexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('network is unreachable') ||
        msg.contains('timed out') ||
        msg.contains('timeout');
  }

  Future<void> _rememberOnlineToken(PosSession current, Object? token) async {
    try {
      await OfflineTokenStore.instance.observe(
        OfflineTokenStore.scopeFor(current),
        token,
      );
    } catch (error) {
      // Cache failure must not turn a successful online sale into another sale.
      debugPrint('Could not cache token for offline continuation: $error');
    }
  }

  /// Cart clearing wipes lastOrder. Return the placed sale after that clear.
  PlacedPosOrder _finishOfflineSale(
    PendingOrder offlineOrder, {
    bool clearOpenCart = true,
  }) {
    final placed = PlacedPosOrder(
      id: 0,
      orderNumber: offlineOrder.localOrderNumber,
      token: offlineOrder.offlineToken?.toString(),
    );
    lastOfflineOrder = offlineOrder;
    if (clearOpenCart) {
      clearCart();
    }
    lastOrder = placed;
    return placed;
  }

  Future<PendingOrder> _createOfflineOrder(
    Map<String, dynamic> payment, {
    String? idempotencyKey,
  }) async {
    final syncService = _syncService;
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }
    if (syncService == null) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlineNotAvailable',
          'Offline mode not available',
        ),
      );
    }

    // Login does not always reach the startup configure() call. Bind the
    // signed-in session now so the local queue can store this order.
    syncService.configure(current);

    return syncService.createOfflineOrder(
      cart: cart,
      orderType: orderType,
      payment: payment,
      posTerminalId: selectedTerminal?.id,
      tableId: _tableIdForPayload,
      customerId: customerId,
      customerName: customerName,
      notes: orderNotes,
      discount: _discountPayload,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<void> syncPendingOrders() async {
    await _syncService?.syncPendingOrders(includeFailed: true);
    notifyListeners();
  }

  /// Captain / Waiter: release new cart lines to kitchen (create or append).
  Future<PlacedPosOrder> sendWaiterKot() async {
    final current = session;
    if (current == null || cart.isEmpty) {
      throw PosApiException(
        PosTranslationStore.instance.text('cartIsEmptyError', 'Cart is empty.'),
      );
    }
    if (!isOnline) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlineHeldPayBlocked',
          'Server held tickets need a network connection to settle.',
        ),
      );
    }

    submitting = true;
    notifyListeners();
    try {
      final items = cart.map((line) => line.toOrderJson()).toList();
      final PlacedPosOrder order;
      final existingServerId = parkedOrderId;
      if (existingServerId != null && parkedLocalUuid == null) {
        order = await _api.appendToKitchen(
          current,
          orderId: existingServerId,
          items: items,
          type: orderType,
          tableId: _tableIdForPayload,
          customerId: customerId,
          customerName: customerName,
          notes: orderNotes,
        );
      } else {
        order = await _api.sendToKitchen(
          current,
          items: items,
          type: orderType,
          tableId: _tableIdForPayload,
          customerId: customerId,
          customerName: customerName,
          notes: orderNotes,
        );
      }
      // A Captain ticket is released to the kitchen before payment, unlike
      // a POS checkout. Queue it here instead of relying on the new-order feed.
      unawaited(
        _printJobs?.enqueueKot(
          orderId: order.id,
          orderNumber: order.orderNumber,
          source: 'captain',
        ),
      );
      clearCart();
      unawaited(refreshWaiterFloor());
      return order;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  /// Push the current cart onto the resumed server ticket without settling.
  Future<void> syncParkedOpenOrder() async {
    final current = session;
    final heldId = parkedOrderId;
    if (current == null || heldId == null || parkedLocalUuid != null) {
      return;
    }
    if (cart.isEmpty) {
      throw PosApiException(
        PosTranslationStore.instance.text('cartIsEmptyError', 'Cart is empty.'),
      );
    }
    await _api.syncOpenOrder(
      current,
      orderId: heldId,
      items: cart.map((line) => line.toOrderJson()).toList(),
      type: orderType,
      tableId: _tableIdForPayload,
      customerId: customerId,
      customerName: customerName,
      notes: orderNotes,
      discount: _discountPayload,
    );
  }

  Future<PlacedPosOrder> parkCurrentTicket() async {
    final current = session;
    if (current == null || cart.isEmpty) {
      throw PosApiException(
        PosTranslationStore.instance.text('cartIsEmptyError', 'Cart is empty.'),
      );
    }

    // Server-held tickets must be re-parked / paid online.
    if (parkedOrderId != null && parkedLocalUuid == null && !isOnline) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlineHeldPayBlocked',
          'Server held tickets need a network connection to settle.',
        ),
      );
    }

    // Re-parking a local held ticket updates the local row.
    final existingLocal = parkedLocalUuid;
    final payloadCart = cart;
    if (payloadCart.isEmpty) {
      throw PosApiException(
        PosTranslationStore.instance.text('cartIsEmptyError', 'Cart is empty.'),
      );
    }

    if (existingLocal != null && (isOffline || !isOnline)) {
      submitting = true;
      notifyListeners();
      try {
        await LocalHeldOrderStore.updateCart(
          localUuid: existingLocal,
          cart: payloadCart,
          orderType: orderType,
          tableId: _tableIdForPayload,
          customerId: customerId,
          customerName: customerName,
          notes: orderNotes,
          discount: _discountPayload,
        );
        final held = await LocalHeldOrderStore.get(existingLocal);
        clearCart();
        unawaited(refreshHeldOrderCount());
        return PlacedPosOrder(
          id: 0,
          orderNumber: held?.localOrderNumber ?? existingLocal,
        );
      } finally {
        submitting = false;
        notifyListeners();
      }
    }

    submitting = true;
    notifyListeners();

    try {
      if (isOnline) {
        try {
          final items = payloadCart.map((line) => line.toOrderJson()).toList();
          final PlacedPosOrder order;
          final existingServerId = parkedOrderId;

          // Same table / session: update the open ticket instead of parking a new one.
          if (existingServerId != null && existingLocal == null) {
            order = await _api.syncOpenOrder(
              current,
              orderId: existingServerId,
              items: items,
              type: orderType,
              tableId: _tableIdForPayload,
              customerId: customerId,
              customerName: customerName,
              notes: orderNotes,
              discount: _discountPayload,
            );
          } else {
            // New hold, or converting a local hold to a server ticket.
            order = await _api.parkOrder(
              current,
              items: items,
              type: orderType,
              posTerminalId: selectedTerminal?.id,
              tableId: _tableIdForPayload,
              customerId: customerId,
              customerName: customerName,
              notes: orderNotes,
              discount: _discountPayload,
            );
            if (existingLocal != null) {
              await LocalHeldOrderStore.delete(existingLocal);
            }
          }
          registerSelfPlacedOrder(order.id);
          clearCart();
          unawaited(refreshHeldOrderCount());
          return order;
        } on PosApiException catch (e) {
          if (!_isNetworkError(e)) rethrow;
        } catch (e) {
          if (!_isRawNetworkFailure(e)) rethrow;
        }
      }

      final held = await _parkLocalTicket(current.branchId);
      clearCart();
      unawaited(refreshHeldOrderCount());
      return PlacedPosOrder(id: 0, orderNumber: held.localOrderNumber);
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<LocalHeldOrder> _parkLocalTicket(int branchId) async {
    final payloadCart = isWaiterMode ? _waiterParkPayloadCart : cart;
    final existingLocal = parkedLocalUuid;
    if (existingLocal != null) {
      await LocalHeldOrderStore.updateCart(
        localUuid: existingLocal,
        cart: payloadCart,
        orderType: orderType,
        tableId: _tableIdForPayload,
        customerId: customerId,
        customerName: customerName,
        notes: orderNotes,
        discount: _discountPayload,
      );
      final held = await LocalHeldOrderStore.get(existingLocal);
      if (held != null) return held;
    }

    return LocalHeldOrderStore.create(
      branchId: branchId,
      cart: payloadCart,
      orderType: orderType,
      tableId: _tableIdForPayload,
      customerId: customerId,
      customerName: customerName,
      notes: orderNotes,
      discount: _discountPayload,
    );
  }

  Future<void> resetServer() async {
    _stopPairingPoll();
    await _storage.clearAll();
    await PosDeviceBindingStorage.clear();
    serverUrl = PlatformConfig.platformUrl;
    session = null;
    profile = null;
    bootstrap = null;
    deviceBinding = null;
    selectedTerminal = null;
    selectedTerminalCode = null;
    pairingCode = null;
    pairingDeviceUuid = null;
    clearCart();
    phase = PosAppPhase.login;
    notifyListeners();
  }

  Future<void> clearDeviceBinding() async {
    await PosDeviceBindingStorage.clear();
    deviceBinding = null;
    notifyListeners();
  }

  Future<void> changeTerminal() async {
    _printerSetupShownForSession = true;
    await _clearDisplaySyncNow();
    _stopRevisionPolling();
    phase = PosAppPhase.terminalPicker;
    notifyListeners();
  }

  Future<void> skipTerminalSelection() async {
    phase = PosAppPhase.ready;
    await _onEnteredReady();
    notifyListeners();
  }

  Future<void> _loadBootstrap() async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }

    try {
      bootstrap = await _api.bootstrap(current);
      _applyAppUpdate(bootstrap!.appUpdate);
      _ensureOrderTypeAllowed();
      _refreshSelectedTerminalFromBootstrap();
      await _notifyBootstrapChanged();
      try {
        await _cacheBootstrap();
      } catch (e) {
        debugPrint('PosController _cacheBootstrap skipped: $e');
      }
    } on PosApiException catch (e) {
      // Billing blocks must not fall back to a stale offline snapshot.
      if (e.isSubscriptionBlocked) {
        rethrow;
      }
      try {
        final loaded = await _loadCachedBootstrap();
        if (!loaded) {
          rethrow;
        }
        _ensureOrderTypeAllowed();
      } catch (_) {
        rethrow;
      }
    } catch (e) {
      try {
        final loaded = await _loadCachedBootstrap();
        if (!loaded) {
          rethrow;
        }
        _ensureOrderTypeAllowed();
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<void> _notifyBootstrapChanged() async {
    final hook = _onBootstrapChanged;
    if (hook == null) return;
    try {
      await hook(bootstrap);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PosController onBootstrapChanged failed: $e\n$st');
      }
    }
  }

  Future<void> _cacheBootstrap() async {
    final current = session;
    final data = bootstrap;
    if (current == null || data == null) return;

    await BootstrapCache.save(
      branchId: current.branchId,
      data: {
        'restaurant': _restaurantToJson(data.restaurant),
        'branch': {'id': data.branch.id, 'name': data.branch.name},
        'categories': data.categories.map(_categoryToJson).toList(),
        'popular_items': data.popularItems.map(_menuItemToJson).toList(),
        'show_popular_items': data.showPopularItems,
        'require_shift_for_pos': data.requireShiftForPos,
        'pos_blocked': data.posBlocked,
        'pos_terminals': data.posTerminals.map(_terminalToJson).toList(),
        if (data.currentShift != null)
          'current_shift': _shiftToJson(data.currentShift!),
        if (data.sync != null)
          'sync': {
            'menu_revision': data.sync?.menuRevision,
            'bootstrap_revision': data.sync?.bootstrapRevision,
          },
        if (data.receiptSettings != null)
          'receipt_settings': data.receiptSettings?.toJson(),
        if (data.posReceiptPrintMode != null)
          'pos_receipt_print_mode': data.posReceiptPrintMode,
        'payment_gateways': data.paymentGateways
            .map((gateway) => gateway.toJson())
            .toList(),
        'payment_qr_timeout_seconds': data.paymentQrTimeoutSeconds,
        'platform': data.platform.toJson(),
        'permissions': data.permissions,
        'languages': {
          'show_switcher': data.showLanguageSwitcher,
          'supported': data.supportedLanguages
              .map((lang) => lang.toJson())
              .toList(),
          'catalogs': data.languageCatalogs,
        },
      },
      menuRevision: data.sync?.menuRevision,
      bootstrapRevision: data.sync?.bootstrapRevision,
    );
  }

  Future<bool> _loadCachedBootstrap() async {
    final current = session;
    if (current == null) return false;

    final cached = await BootstrapCache.load(current.branchId);
    if (cached == null) return false;

    try {
      bootstrap = PosBootstrap.fromJson(cached['data'] as Map<String, dynamic>);
      _refreshSelectedTerminalFromBootstrap();
      await _notifyBootstrapChanged();
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _restaurantToJson(PosRestaurantInfo r) => {
    'id': r.id,
    'name': r.name,
    'logo_url': r.logoUrl,
    'primary_color': r.primaryColor,
    'default_currency': r.defaultCurrency,
    'tax_settings': {
      'prices_include_tax': r.taxSettings.pricesIncludeTax,
      'tax_rate': r.taxSettings.taxRate,
      'taxes': r.taxSettings.taxes
          .map(
            (tax) => {
              'name': tax.name,
              'rate': tax.rate,
              'included': tax.included,
            },
          )
          .toList(),
    },
    'service_charge': {
      'enabled': r.serviceCharge.enabled,
      'rate': r.serviceCharge.rate,
      'label': r.serviceCharge.label,
      'taxable': r.serviceCharge.taxable,
    },
    'order_type_charges': r.orderTypeCharges,
    'order_type_surcharge_settings': r.orderTypeSurchargeSettings,
    'ordering': {
      'enable_pickup': r.ordering.enablePickup,
      'enable_delivery': r.ordering.enableDelivery,
      'enable_dine_in': r.ordering.enableDineIn,
      'pos_order_types': r.ordering.posOrderTypes,
      'allowed_order_types': r.ordering.posOrderTypes
          .map((type) => type == 'takeaway' ? 'pickup' : type)
          .toList(),
    },
    'tips': {'enabled': r.tips.enabled, 'presets': r.tips.presets},
  };

  Map<String, dynamic> _categoryToJson(MenuCategory c) => {
    'id': c.id,
    'name': c.name,
    'image_url': c.imageUrl,
    'menu_items': c.items.map(_menuItemToJson).toList(),
  };

  Map<String, dynamic> _menuItemToJson(MenuItem item) => {
    'id': item.id,
    'name': item.name,
    'price': item.price,
    'description': item.description,
    'image_url': item.imageUrl,
    'item_type': item.itemType,
    'barcode': item.barcode,
    if (item.sku != null) 'sku': item.sku,
    'is_available': item.isAvailable,
    'is_orderable': item.isOrderable,
    'order_type_surcharges': item.orderTypeSurcharges,
    'schedule': {
      'mode': item.scheduleMode,
      'is_live_now': item.isLiveNow,
      'hidden_reason': item.scheduleHiddenReason,
    },
    'variants': item.variants
        .map(
          (v) => {
            'id': v.id,
            'name': v.name,
            'price': v.price,
            if (v.barcode != null) 'barcode': v.barcode,
          },
        )
        .toList(),
    'modifiers': item.modifiers
        .map(
          (m) => {
            'id': m.id,
            'name': m.name,
            'is_required': m.isRequired,
            'min_selections': m.minSelections,
            'max_selections': m.maxSelections,
            'options': m.options
                .map(
                  (o) => {
                    'id': o.id,
                    'name': o.name,
                    'price_adjustment': o.priceAdjustment,
                  },
                )
                .toList(),
          },
        )
        .toList(),
  };

  Map<String, dynamic> _terminalToJson(PosTerminalInfo t) => {
    'id': t.id,
    'code': t.code,
    'name': t.name,
    'display_url': t.displayUrl,
    'sync_token': t.syncToken,
  };

  Map<String, dynamic> _shiftToJson(PosShift s) => {
    'id': s.id,
    'opening_float': s.openingFloat,
    'opened_at': s.openedAt,
    'opened_by': s.openedByName != null ? {'name': s.openedByName} : null,
  };

  void _refreshSelectedTerminalFromBootstrap() {
    final code = selectedTerminalCode;
    final data = bootstrap;
    if (code == null || code.isEmpty || data == null) return;

    for (final terminal in data.posTerminals) {
      if (terminal.code == code) {
        selectedTerminal = terminal;
        return;
      }
    }
  }

  PosTerminalInfo? _activeSyncTerminal() {
    final terminal = selectedTerminal;
    if (terminal == null || terminal.code.isEmpty) return null;

    final token = terminal.syncToken;
    if (token != null && token.isNotEmpty) return terminal;

    final terminals = bootstrap?.posTerminals ?? [];
    for (final t in terminals) {
      if (t.code == terminal.code &&
          t.syncToken != null &&
          t.syncToken!.isNotEmpty) {
        return t;
      }
    }

    return null;
  }

  void _scheduleDisplaySync() {
    if (phase != PosAppPhase.ready) return;
    _displaySyncTimer?.cancel();
    // Record local cart changes immediately. The DQR worker coalesces USB
    // writes, so a pending old bill is superseded even during rapid taps.
    unawaited(_pushDisplaySync(syncServer: false));
    _displaySyncTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_pushDisplaySync());
    });
  }

  void _cancelDisplaySync() {
    _displaySyncTimer?.cancel();
    _displaySyncTimer = null;
  }

  Future<void> _clearDisplaySyncNow() async {
    final terminal = _activeSyncTerminal();
    final branch = bootstrap?.branch;
    final url = serverUrl;
    if (terminal == null || branch == null || url == null) return;

    await _displaySync.clearCart(
      serverUrl: url,
      branchId: branch.id,
      terminalCode: terminal.code,
      syncToken: terminal.syncToken!,
    );
  }

  Future<void> _pushDisplaySync({bool syncServer = true}) async {
    final terminal = _activeSyncTerminal();
    final branch = bootstrap?.branch;
    final url = serverUrl;
    final syncToken = terminal?.syncToken;

    if (cart.isEmpty) {
      CustomerDisplayBroker.instance.showIdleHome();
      if (!syncServer) return;
      if (terminal == null ||
          branch == null ||
          url == null ||
          syncToken == null ||
          syncToken.isEmpty) {
        return;
      }
      await _displaySync.clearCart(
        serverUrl: url,
        branchId: branch.id,
        terminalCode: terminal.code,
        syncToken: syncToken,
      );
      return;
    }

    final preview = cartTotalsPreview;
    final serviceCharge = bootstrap?.restaurant.serviceCharge;

    final payload = <String, dynamic>{
      'items': cart
          .map(
            (line) => {
              'name': line.displayName,
              'quantity': line.quantity,
              'price': line.unitPrice,
              'modifiers': line.selectedModifiers
                  .map(
                    (mod) => {
                      'name': mod.name,
                      'price_adjustment': mod.priceAdjustment,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'subtotal': cartSubtotal,
      'discount': discountAmount > 0
          ? {
              'amount': discountAmount,
              'type': discount?.type,
              'value': discount?.value,
              'reason': discount?.reason,
            }
          : null,
      'service_charge': preview.serviceChargeAmount > 0
          ? {
              'amount': preview.serviceChargeAmount,
              'label':
                  serviceCharge?.label ??
                  PosTranslationStore.instance.text(
                    'cartServiceCharge',
                    'Service charge',
                  ),
              'taxable': serviceCharge?.taxable == true,
            }
          : null,
      'extra_charges': preview.extraChargeLines
          .map(
            (line) => {
              'label': line.label,
              'amount': line.amount,
              'taxable': line.taxable,
            },
          )
          .toList(),
      'tax': preview.totalTax,
      'tax_breakdown': [
        for (final tax in preview.taxComputation.breakdown)
          {
            'name': tax.name,
            'rate': tax.rate,
            'amount': tax.amount,
            'included': tax.included,
          },
      ],
      'total': preview.total,
      'currency': currency,
    };

    // Local USB displays work without a server display-sync subscription and
    // must not wait for a network request before showing the current cart.
    CustomerDisplayBroker.instance.showCart(payload);
    if (!syncServer) return;
    if (terminal == null ||
        branch == null ||
        url == null ||
        syncToken == null ||
        syncToken.isEmpty) {
      return;
    }
    await _displaySync.pushCart(
      serverUrl: url,
      branchId: branch.id,
      terminalCode: terminal.code,
      syncToken: syncToken,
      payload: payload,
    );
  }

  void _bindCustomerDisplayBranding() {
    final restaurant = bootstrap?.restaurant;
    CustomerDisplayBroker.instance.updateBranding(
      name: restaurant?.name,
      logoUrl: resolveMediaUrl(restaurant?.logoUrl, serverUrl: serverUrl),
    );
  }

  void startWaiterTableSession({required int tableId, int guests = 2}) {
    cart.clear();
    waiterSentCart = [];
    parkedOrderId = null;
    parkedLocalUuid = null;
    parkedOrderLabel = null;
    _forgetParkedPayment();
    discount = null;
    orderNotes = null;
    setOrderType('dine_in');
    setTableId(tableId);
    waiterGuestCount = guests;
    final branchId = session?.branchId;
    if (branchId != null) {
      unawaited(PosBillRequestStorage.remove(branchId, tableId));
    }
    billRequestedTableIds = {...billRequestedTableIds}..remove(tableId);
    _markCartChanged();
    _scheduleDisplaySync();
    notifyListeners();
  }

  /// Open an existing table session for append: keep ticket id + already-sent
  /// lines aside, start with an empty working cart for newly ordered items.
  Future<void> beginWaiterAppendSession({
    int? orderId,
    String? localUuid,
    int? fallbackTableId,
    int guests = 2,
  }) async {
    if (localUuid != null && localUuid.isNotEmpty) {
      await _beginWaiterAppendLocal(localUuid, guests: guests);
      return;
    }
    if (orderId == null) {
      if (fallbackTableId != null) {
        startWaiterTableSession(tableId: fallbackTableId, guests: guests);
        return;
      }
      throw PosApiException(
        PosTranslationStore.instance.text(
          'ordersNumberMissing',
          'Order number is missing.',
        ),
      );
    }

    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }

    final payload = await _api.fetchOrderForResume(
      current,
      orderId: orderId,
      forAppend: true,
    );
    final summary = payload['order'] as Map<String, dynamic>? ?? const {};
    final form = payload['form'] as Map<String, dynamic>? ?? const {};
    final cartRows =
        (payload['cart'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];

    waiterSentCart = cartRows
        .map(_cartLineFromResumePayload)
        .toList(growable: false);
    cart.clear();
    _markCartChanged();

    final type = form['type'] as String?;
    if (type != null && type.isNotEmpty) {
      orderType = type;
    } else {
      orderType = 'dine_in';
    }
    final name = form['customer_name'] as String?;
    customerName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : null;
    final rawCustomerId = form['customer_id'];
    customerId = rawCustomerId == null || '$rawCustomerId'.isEmpty
        ? null
        : parseJsonIntOrNull(rawCustomerId);
    final rawTableId = form['table_id'];
    tableId = rawTableId == null || '$rawTableId'.isEmpty
        ? fallbackTableId
        : parseJsonIntOrNull(rawTableId) ?? fallbackTableId;
    final notes = form['notes'] as String?;
    orderNotes = (notes != null && notes.trim().isNotEmpty)
        ? notes.trim()
        : null;
    // Captain / waiter does not apply discounts — leave billing to register.
    discount = null;

    parkedOrderId = orderId;
    parkedLocalUuid = null;
    final token = summary['token'];
    parkedOrderLabel = token != null
        ? PosTranslationStore.instance.text(
            'ordersTokenLabel',
            'Token {token}',
            replacements: {'token': '$token'},
          )
        : (summary['order_number'] as String? ?? '#$orderId');
    _rememberParkedPayment(summary);
    waiterGuestCount = guests;

    _scheduleDisplaySync();
    notifyListeners();
  }

  Future<void> _beginWaiterAppendLocal(
    String localUuid, {
    required int guests,
  }) async {
    final held = await LocalHeldOrderStore.get(localUuid);
    if (held == null) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlineHeldNotFound',
          'That held ticket is no longer on this device.',
        ),
      );
    }

    final payload = held.payload;
    final cartRows =
        (payload['resume_cart'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];

    waiterSentCart = cartRows
        .map(_cartLineFromResumePayload)
        .toList(growable: false);
    cart.clear();
    _markCartChanged();

    final type = payload['type'] as String?;
    if (type != null && type.isNotEmpty) {
      orderType = type;
    } else {
      orderType = 'dine_in';
    }
    final name = payload['customer_name'] as String?;
    customerName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : null;
    customerId = parseJsonIntOrNull(payload['customer_id']);
    tableId = parseJsonIntOrNull(payload['table_id']);
    final notes = payload['notes'] as String?;
    orderNotes = (notes != null && notes.trim().isNotEmpty)
        ? notes.trim()
        : null;
    // Captain / waiter does not apply discounts — leave billing to register.
    discount = null;

    parkedOrderId = null;
    parkedLocalUuid = localUuid;
    parkedOrderLabel = held.localOrderNumber;
    _forgetParkedPayment();
    waiterGuestCount = guests;

    _scheduleDisplaySync();
    notifyListeners();
  }

  Future<void> requestBillForTable(
    int tableId, {
    String mode = 'full',
    List<int>? orderItemIds,
    int? parts,
    String? note,
  }) async {
    final branchId = session?.branchId;
    if (branchId == null) return;

    final order = activeOrderForTable(tableId);
    final orderId = parseJsonIntOrNull(order?['id']);
    final current = session;
    if (current != null && orderId != null && isOnline) {
      // Online failures (validation, auth) should surface; offline falls through
      // so the local billing cue still appears on the floor.
      await _api.requestBill(
        current,
        orderId: orderId,
        mode: mode,
        orderItemIds: orderItemIds,
        parts: parts,
        note: note,
      );
    }

    await PosBillRequestStorage.add(branchId, tableId);
    billRequestedTableIds = {...billRequestedTableIds, tableId};

    String? tableName;
    for (final table in waiterTables) {
      if (parseJsonIntOrNull(table['id']) == tableId) {
        tableName = table['name']?.toString();
        break;
      }
    }
    final orderNumber = order?['order_number']?.toString();

    final isSplit = mode != 'full';
    _pushWaiterAlert(
      WaiterAlert(
        id: 'bill-$tableId-${DateTime.now().millisecondsSinceEpoch}',
        type: WaiterAlertType.billRequested,
        title: PosTranslationStore.instance.text(
          isSplit
              ? 'waiterNotificationSplitBillTitle'
              : 'waiterNotificationBillTitle',
          isSplit ? 'Split bill requested' : 'Bill requested',
        ),
        body: PosTranslationStore.instance.text(
          'waiterNotificationBillBody',
          '{table} is waiting for checkout',
          replacements: {
            'table': (tableName != null && tableName.isNotEmpty)
                ? tableName
                : PosTranslationStore.instance.text(
                    'cartTableNamed',
                    'Table $tableId',
                    replacements: {'name': '$tableId'},
                  ),
          },
        ),
        at: DateTime.now(),
        tableId: tableId,
        orderId: orderId,
        tableName: tableName,
        orderNumber: orderNumber,
      ),
    );
    unawaited(refreshWaiterFloor(silent: true));
    notifyListeners();
  }

  /// Mark ready kitchen ticket(s) as served (captain run-food).
  Future<int> markWaiterServed({
    required int orderId,
    int? kitchenTicketId,
  }) async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }
    if (!isOnline) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'waiterMarkServedNeedsOnline',
          'Connect to the server to mark food served.',
        ),
      );
    }

    final data = await _api.markServed(
      current,
      orderId: orderId,
      kitchenTicketId: kitchenTicketId,
    );
    final updated = data['order'];
    if (updated is Map) {
      final order = Map<String, dynamic>.from(updated);
      waiterRecentOrders = [
        for (final o in waiterRecentOrders)
          if (parseJsonIntOrNull(o['id']) == orderId) order else o,
      ];
      notifyListeners();
    }
    unawaited(refreshWaiterFloor(silent: true));
    return parseJsonInt(data['marked'], fallback: 0);
  }

  Future<void> clearBillRequest(int tableId) async {
    final branchId = session?.branchId;
    if (branchId == null) return;

    final order = activeOrderForTable(tableId);
    final orderId = parseJsonIntOrNull(order?['id']);
    final current = session;
    if (current != null && orderId != null && isOnline) {
      await _api.clearBillRequest(current, orderId: orderId);
    }

    await PosBillRequestStorage.remove(branchId, tableId);
    billRequestedTableIds = {...billRequestedTableIds}..remove(tableId);

    // Keep floor payload in sync so bill badge does not snap back on refresh.
    if (orderId != null) {
      waiterRecentOrders = [
        for (final o in waiterRecentOrders)
          if (parseJsonIntOrNull(o['id']) == orderId)
            {
              ...o,
              'bill_requested': false,
              'bill_requested_at': null,
              'bill_request': null,
            }
          else
            o,
      ];
    }

    notifyListeners();
    unawaited(refreshWaiterFloor(silent: true));
  }

  Future<void> updateWaiterTableStatus({
    required int tableId,
    required String status,
  }) async {
    final current = session;
    if (current == null) {
      throw PosApiException(
        PosTranslationStore.instance.text('authNotSignedIn', 'Not signed in'),
      );
    }
    if (!isOnline) {
      throw PosApiException(
        PosTranslationStore.instance.text(
          'offlineHeldPayBlocked',
          'Server held tickets need a network connection to settle.',
        ),
      );
    }

    await _api.updateTableStatus(current, tableId: tableId, status: status);
    if (status == 'available' || status == 'cleaning') {
      await clearBillRequest(tableId);
    }
    await refreshWaiterFloor(silent: true);
  }

  Map<String, dynamic>? heldOrderForTable(int tableId) {
    Map<String, dynamic>? best;
    String? bestCreatedAt;
    for (final order in waiterHeldOrders) {
      final id = parseJsonIntOrNull(order['table_id']);
      if (id != tableId) continue;
      final created = order['created_at']?.toString() ?? '';
      if (best == null || created.compareTo(bestCreatedAt ?? '') > 0) {
        best = order;
        bestCreatedAt = created;
      }
    }
    return best;
  }

  /// Prefer live floor ticket for a table; fall back to register held draft.
  Map<String, dynamic>? activeOrderForTable(int tableId) {
    Map<String, dynamic>? best;
    String? bestCreatedAt;
    for (final order in waiterRecentOrders) {
      final id = parseJsonIntOrNull(order['table_id']);
      if (id != tableId) continue;
      final status = '${order['status']}';
      if (status == 'cancelled' ||
          status == 'abandoned' ||
          status == 'delivered') {
        continue;
      }
      final created = order['created_at']?.toString() ?? '';
      if (best == null || created.compareTo(bestCreatedAt ?? '') > 0) {
        best = order;
        bestCreatedAt = created;
      }
    }
    return best ?? heldOrderForTable(tableId);
  }

  Map<String, dynamic>? recentOrderForTable(int tableId) {
    return activeOrderForTable(tableId);
  }

  void _startWaiterPolling() {
    _stopWaiterPolling();
    if (!isWaiterMode) return;
    _waiterPollTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      unawaited(refreshWaiterFloor(silent: true));
    });
  }

  void _stopWaiterPolling() {
    _waiterPollTimer?.cancel();
    _waiterPollTimer = null;
  }

  void _startRegisterAlertPolling() {
    _stopRegisterAlertPolling();
    if (!isRegisterMode) return;
    _registerAlertPollTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      unawaited(refreshRegisterBillAlerts(silent: true));
    });
  }

  void _stopRegisterAlertPolling() {
    _registerAlertPollTimer?.cancel();
    _registerAlertPollTimer = null;
  }

  void _startNewOrderPolling() {
    _stopNewOrderPolling();
    if (!isRegisterMode && !isWaiterMode) return;
    _newOrderPollTimer = Timer.periodic(_newOrderPollInterval, (_) {
      unawaited(refreshNewOrderAlerts(silent: true));
    });
  }

  void _stopNewOrderPolling() {
    _newOrderPollTimer?.cancel();
    _newOrderPollTimer = null;
  }

  /// Poll for new guest/kiosk/online/marketplace orders (admin web POS equivalent).
  Future<void> refreshNewOrderAlerts({bool silent = false}) async {
    final current = session;
    if (current == null || (!isRegisterMode && !isWaiterMode) || !isOnline) {
      return;
    }
    if (PosApi.isRateLimited) return;

    try {
      if (!_newOrdersSynced) {
        final baseline = await _api.fetchNewOrders(current, baseline: true);
        final lastId = parseJsonIntOrNull(baseline['last_order_id']);
        if (lastId != null) {
          _newOrdersLastSeenId = lastId;
        }
        _newOrdersSynced = true;
      }

      final payload = await _api.fetchNewOrders(
        current,
        sinceId: _newOrdersLastSeenId ?? 0,
      );
      final orders =
          (payload['orders'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      if (orders.isEmpty) return;

      // Marketplace first so the sticky priority banner wins when several arrive.
      orders.sort((a, b) {
        final am = isMarketplaceOrderSource(a['source']?.toString()) ? 0 : 1;
        final bm = isMarketplaceOrderSource(b['source']?.toString()) ? 0 : 1;
        if (am != bm) return am.compareTo(bm);
        final ai = parseJsonIntOrNull(a['id']) ?? 0;
        final bi = parseJsonIntOrNull(b['id']) ?? 0;
        return bi.compareTo(ai);
      });

      var maxId = _newOrdersLastSeenId ?? 0;
      var changed = false;
      var sawMarketplace = false;
      var sawStandard = false;
      WaiterAlert? bannerCandidate;
      final staged = <WaiterAlert>[];

      for (final order in orders) {
        final id = parseJsonIntOrNull(order['id']);
        if (id == null) continue;
        if (_newOrdersLastSeenId != null && id <= _newOrdersLastSeenId!) {
          continue;
        }
        if (id > maxId) maxId = id;

        final number = order['order_number']?.toString() ?? '#$id';
        final source = order['source']?.toString();
        final orderStatus = (order['status']?.toString() ?? '')
            .toLowerCase()
            .trim();
        if (orderStatus == 'draft') {
          continue;
        }
        unawaited(
          _printJobs?.enqueueKot(
            orderId: id,
            orderNumber: number,
            source: source ?? '',
            order: order,
          ),
        );

        if (_shouldSuppressNewOrderCue(order, id)) {
          continue;
        }

        final externalId =
            order['external_id']?.toString() ?? order['externalId']?.toString();
        final marketplace = isMarketplaceOrderSource(source);
        final alert = _buildNewOrderAlert(
          id: id,
          number: number,
          source: source,
          externalId: externalId,
          orderType: order['type']?.toString(),
          token: order['token']?.toString(),
          total:
              parseJsonDoubleOrNull(order['total']) ??
              double.tryParse('${order['total'] ?? ''}'),
          createdAt: DateTime.tryParse('${order['created_at'] ?? ''}'),
        );
        if (_isDuplicateNewOrderCue(alert)) continue;

        changed = true;
        if (marketplace) {
          sawMarketplace = true;
          _bumpMarketplaceOpenCount(source);
        } else {
          sawStandard = true;
        }
        staged.add(alert);
        bannerCandidate ??= alert;
      }

      if (changed) {
        final modalShowing = registerBannerAlert?.type.isNewOrderCue == true;
        if (modalShowing) {
          _newOrderBannerQueue.addAll(staged);
        } else {
          if (bannerCandidate != null) {
            registerBannerAlert = bannerCandidate;
            if (staged.length > 1) {
              _newOrderBannerQueue.addAll(staged.skip(1));
            }
          }
        }
        if (sawMarketplace) {
          unawaited(PosCartSound.instance.playMarketplaceOrderAlert());
        } else if (sawStandard) {
          unawaited(PosCartSound.instance.playNewOrderAlert());
        }
        notifyListeners();
      }

      _newOrdersLastSeenId = maxId;
      await _syncPaymentDraftAlerts(current);
    } catch (_) {
      // Keep prior cursor; next poll retries.
    } finally {
      if (!silent) notifyListeners();
    }
  }

  void _startPaymentSessionMonitoring() {
    final current = session;
    if (current == null) return;
    if (!_paymentSessionsBound) {
      PaymentSessionManager.instance.addListener(_onPaymentSessionsChanged);
      _paymentSessionsBound = true;
    }
    unawaited(
      PaymentSessionManager.instance.start((orderId) async {
        final live = session;
        if (live == null) return null;
        final data = await _api.fetchPaymentStatus(live, orderId: orderId);
        if (data['paid'] == true) return 'paid';
        if (data['failed'] == true) return 'failed';
        if (data['timed_out'] == true) return 'expired';
        return data['payment_status']?.toString() ?? data['status']?.toString();
      }),
    );
  }

  void _stopPaymentSessionMonitoring() {
    if (_paymentSessionsBound) {
      PaymentSessionManager.instance.removeListener(_onPaymentSessionsChanged);
      _paymentSessionsBound = false;
    }
    PaymentSessionManager.instance.stop();
  }

  void _onPaymentSessionsChanged() {
    for (final session in PaymentSessionManager.instance.sessions) {
      final key = '${session.paymentSessionId}:${session.status.name}';
      if (!_paymentSessionSignals.add(key)) continue;

      if (session.status == PaymentSessionStatus.expired) {
        final onDisplay = CustomerDisplayBroker.instance.displaysOrder(
          session.orderNumber,
        );
        CustomerDisplayBroker.instance.paymentExpired(
          orderNumber: session.orderNumber,
        );
        if (session.heldForNewOrder && !onDisplay) {
          paymentSessionNotice = 'QR expired: ${session.orderNumber}';
          notifyListeners();
        }
        continue;
      }
      if (session.status == PaymentSessionStatus.failed) {
        CustomerDisplayBroker.instance.paymentFailed(
          orderNumber: session.orderNumber,
        );
        continue;
      }
      if (session.status != PaymentSessionStatus.paid) continue;
      if (session.receiptPrinted) continue;

      paymentSessionNotice = 'Payment received: ${session.orderNumber}';
      notifyListeners();
      unawaited(_settleBackgroundPayment(session));
    }
  }

  Future<void> _settleBackgroundPayment(PaymentSession session) async {
    final latest = PaymentSessionManager.instance.sessionForOrder(
      session.orderId,
    );
    if (latest == null || latest.status != PaymentSessionStatus.paid) return;

    unawaited(
      _printJobs?.enqueueKot(
        orderId: latest.orderId,
        orderNumber: latest.orderNumber,
        source: 'pos',
        order: {
          'id': latest.orderId,
          'order_number': latest.orderNumber,
          'source': 'pos',
          'payment_status': 'paid',
        },
        cashierCheckout: true,
      ),
    );

    if (latest.receiptPrinted) return;
    unawaited(
      _printJobs?.enqueueReceipt(
        orderId: latest.orderId,
        orderNumber: latest.orderNumber,
      ),
    );
    await PaymentSessionManager.instance.markReceiptPrinted(
      latest.paymentSessionId,
    );
  }

  void showCashierPlacedNotice({required String orderNumber, int? orderId}) {
    final t = PosTranslationStore.instance;
    cashierPlacedNotice = t.text(
      'orderPlaced',
      'Order {label} placed',
      replacements: {'label': orderNumber},
    );
    _cashierPlacedNoticeTimer?.cancel();
    _cashierPlacedNoticeTimer = Timer(const Duration(milliseconds: 2200), () {
      cashierPlacedNotice = null;
      notifyListeners();
    });
    if (orderId != null && orderId > 0) {
      registerSelfPlacedOrder(orderId);
      _pushWaiterAlert(
        WaiterAlert(
          id: 'placed-$orderId',
          type: WaiterAlertType.newOrder,
          title: t.text('orderPlacedTitle', 'Order placed'),
          body: orderNumber,
          at: DateTime.now(),
          orderId: orderId,
          orderNumber: orderNumber,
          source: 'pos',
        ),
      );
    }
    notifyListeners();
  }

  void clearCashierPlacedNotice() {
    _cashierPlacedNoticeTimer?.cancel();
    if (cashierPlacedNotice == null) return;
    cashierPlacedNotice = null;
    notifyListeners();
  }

  String? takePaymentSessionNotice() {
    final notice = paymentSessionNotice;
    paymentSessionNotice = null;
    return notice;
  }

  Future<void> _syncPaymentDraftAlerts(PosSession current) async {
    final drafts = await _paymentDraftRows(current);
    if (drafts.isEmpty) return;
    var added = false;
    for (final order in drafts) {
      final id = parseJsonIntOrNull(order['id']);
      if (id == null || _selfPlacedOrderIds.contains(id)) continue;
      final already =
          waiterAlerts.any(
            (alert) => alert.orderId == id && alert.type.isNewOrderCue,
          ) ||
          registerBannerAlert?.orderId == id ||
          _newOrderBannerQueue.any((alert) => alert.orderId == id);
      if (already) continue;
      final payment = '${order['payment_status'] ?? ''}'.toLowerCase().trim();
      final failed = payment.contains('fail');
      final number = '${order['order_number'] ?? '#$id'}';
      final alert = WaiterAlert(
        id: 'draft-order-$id',
        type: WaiterAlertType.newOrder,
        title: failed ? 'Payment failed' : 'Payment pending',
        body: 'Draft order $number',
        at: DateTime.tryParse('${order['created_at'] ?? ''}') ?? DateTime.now(),
        orderId: id,
        orderNumber: number,
        source: order['source']?.toString(),
        orderType: order['type']?.toString(),
        total: parseJsonDoubleOrNull(order['total']),
      );
      if (_pushWaiterAlert(alert)) {
        added = true;
        registerBannerAlert ??= alert;
      }
    }
    if (added) {
      unawaited(PosCartSound.instance.playNewOrderAlert());
      notifyListeners();
    }
  }

  WaiterAlert _buildNewOrderAlert({
    required int id,
    required String number,
    required String? source,
    required String? externalId,
    String? orderType,
    String? token,
    double? total,
    DateTime? createdAt,
  }) {
    final t = PosTranslationStore.instance;
    final marketplace = isMarketplaceOrderSource(source);
    final ext = (externalId ?? '').trim();
    final type = (orderType ?? '').trim();
    final tok = (token ?? '').trim();
    if (marketplace) {
      final partner = _marketplacePartnerLabel(source);
      return WaiterAlert(
        id: 'new-order-$id',
        type: WaiterAlertType.marketplaceOrder,
        title: t.text(
          'marketplacePriorityTitle',
          'Priority · {partner}',
          replacements: {'partner': partner},
        ),
        body: t.text(
          'marketplacePriorityBody',
          'Partner order {number} needs attention',
          replacements: {'number': number},
        ),
        at: createdAt ?? DateTime.now(),
        orderId: id,
        orderNumber: number,
        source: source,
        externalId: ext.isEmpty ? null : ext,
        orderType: type.isEmpty ? null : type,
        token: tok.isEmpty ? null : tok,
        total: total,
      );
    }

    return WaiterAlert(
      id: 'new-order-$id',
      type: WaiterAlertType.newOrder,
      title: t.text('registerNotificationNewOrderTitle', 'New order'),
      body: t.text(
        'registerNotificationNewOrderBody',
        'Order {number} received',
        replacements: {'number': number},
      ),
      at: createdAt ?? DateTime.now(),
      orderId: id,
      orderNumber: number,
      source: source,
      externalId: ext.isEmpty ? null : ext,
      orderType: type.isEmpty ? null : type,
      token: tok.isEmpty ? null : tok,
      total: total,
    );
  }

  String _marketplacePartnerLabel(String? source) {
    final t = PosTranslationStore.instance;
    return switch ((source ?? '').toLowerCase().trim()) {
      'zomato' => t.text('ordersFilterZomato', 'Zomato'),
      'swiggy' => t.text('ordersFilterSwiggy', 'Swiggy'),
      final key when key.isNotEmpty =>
        '${key[0].toUpperCase()}${key.substring(1)}',
      _ => t.text('ordersFilterPartners', 'Delivery partners'),
    };
  }

  void _sortWaiterAlertsPriorityFirst() {
    if (waiterAlerts.length < 2) return;
    final priority = <WaiterAlert>[];
    final rest = <WaiterAlert>[];
    for (final alert in waiterAlerts) {
      if (alert.isPriority && !alert.isRead) {
        priority.add(alert);
      } else {
        rest.add(alert);
      }
    }
    waiterAlerts = [...priority, ...rest].take(40).toList();
  }

  /// Poll floor tickets so register staff see captain bill requests.
  Future<void> refreshRegisterBillAlerts({bool silent = false}) async {
    final current = session;
    if (current == null || !isRegisterMode || !isOnline) return;
    if (PosApi.isRateLimited) return;

    var shouldNotify = !silent;
    try {
      if (!_waiterAlertsHydrated) {
        waiterAlerts = await PosWaiterAlertsStorage.read(current.branchId);
        _waiterAlertsHydrated = true;
        shouldNotify = true;
      }

      final floor = await _api.fetchFloorOrders(current);
      _detectRegisterBillAlerts(floor);
      _registerFloorSnapshot = floor;
      _registerFloorPrimed = true;
    } catch (_) {
      // Keep prior snapshot; next poll retries.
    } finally {
      if (shouldNotify) notifyListeners();
    }
  }

  void _detectRegisterBillAlerts(List<Map<String, dynamic>> orders) {
    // Skip first snapshot so already-open bill requests do not spam.
    if (!_registerFloorPrimed) return;

    final previousBilled = _registerFloorSnapshot
        .where((o) => o['bill_requested'] == true)
        .map((o) => o['id'])
        .toSet();

    var changed = false;
    for (final order in orders) {
      if (order['bill_requested'] != true) continue;
      final id = order['id'];
      if (previousBilled.contains(id)) continue;

      final tableName = order['table_name']?.toString();
      final number = order['order_number']?.toString() ?? '#$id';
      final billAlert = WaiterAlert(
        id: 'bill-reg-$id-${DateTime.now().millisecondsSinceEpoch}',
        type: WaiterAlertType.billRequested,
        title: PosTranslationStore.instance.text(
          'waiterNotificationBillTitle',
          'Bill requested',
        ),
        body: PosTranslationStore.instance.text(
          'registerNotificationBillBody',
          'Captain requested checkout for {table}',
          replacements: {
            'table': tableName != null && tableName.isNotEmpty
                ? tableName
                : number,
          },
        ),
        at: DateTime.now(),
        tableId: parseJsonIntOrNull(order['table_id']),
        orderId: parseJsonIntOrNull(order['id']),
        tableName: tableName,
        orderNumber: number,
      );
      final pushed = _pushWaiterAlert(billAlert, persist: false);
      if (pushed) {
        changed = true;
        if (registerBannerAlert?.type.isNewOrderCue != true) {
          registerBannerAlert = billAlert;
        }
      }
    }

    if (changed) {
      unawaited(_persistWaiterAlerts());
      notifyListeners();
    }
  }

  WaiterAlert? takeRegisterBannerAlert() {
    final alert = registerBannerAlert;
    registerBannerAlert = null;
    return alert;
  }

  /// Clear the in-app new-order / bill banner (optionally mark the cue read).
  void dismissRegisterBannerAlert({
    bool markRead = false,
    bool showNext = false,
  }) {
    final alert = registerBannerAlert;
    if (alert == null) return;
    registerBannerAlert = null;

    if (alert.type.isNewOrderCue) {
      _commitNewOrderCueToInbox(alert, markRead: markRead);
      if (_newOrderBannerQueue.isNotEmpty) {
        registerBannerAlert = _newOrderBannerQueue.removeAt(0);
      } else if (showNext) {
        for (final a in waiterAlerts) {
          if (a.type.isNewOrderCue && !a.isRead && a.id != alert.id) {
            registerBannerAlert = a;
            break;
          }
        }
      }
    } else if (markRead) {
      final index = waiterAlerts.indexWhere((a) => a.id == alert.id);
      if (index >= 0 && !waiterAlerts[index].isRead) {
        final next = [...waiterAlerts];
        next[index] = next[index].copyWith(isRead: true);
        waiterAlerts = next;
        unawaited(_persistWaiterAlerts());
      }
    }
    notifyListeners();
  }

  bool _shouldSuppressNewOrderCue(Map<String, dynamic> order, int id) {
    if (_selfPlacedOrderIds.contains(id)) return true;

    final status = (order['status']?.toString() ?? '').toLowerCase().trim();
    if (status == 'abandoned' || status == 'cancelled') {
      return true;
    }
    if (status == 'draft') {
      final source = (order['source']?.toString() ?? '').toLowerCase().trim();
      return source.isEmpty || source == 'pos';
    }

    final source = (order['source']?.toString() ?? '').toLowerCase().trim();
    if (!canAutomaticallyFulfillOrder(order, source: source)) {
      return true;
    }
    if (source != 'pos') return false;

    final terminalId = parseJsonIntOrNull(order['pos_terminal_id']);
    final mine = selectedTerminal?.id;
    return terminalId != null && mine != null && terminalId == mine;
  }

  bool _isDuplicateNewOrderCue(WaiterAlert alert) {
    if (registerBannerAlert?.orderId == alert.orderId &&
        registerBannerAlert!.type.isNewOrderCue) {
      return true;
    }
    if (_newOrderBannerQueue.any(
      (a) => a.orderId == alert.orderId && a.type.isNewOrderCue,
    )) {
      return true;
    }
    return waiterAlerts.any(
      (a) =>
          a.type.isNewOrderCue &&
          a.orderId == alert.orderId &&
          !a.isRead &&
          DateTime.now().difference(a.at).inMinutes < 10,
    );
  }

  void _commitNewOrderCueToInbox(WaiterAlert alert, {required bool markRead}) {
    final committed = markRead ? alert.copyWith(isRead: true) : alert;
    if (_pushWaiterAlert(committed, persist: false)) {
      _sortWaiterAlertsPriorityFirst();
    } else if (markRead) {
      markWaiterAlertRead(alert.id);
    }
    unawaited(_persistWaiterAlerts());
  }

  Future<void>? _waiterFloorRefresh;

  Future<void> refreshWaiterFloor({bool silent = false}) {
    return _waiterFloorRefresh ??= _refreshWaiterFloor(
      silent: silent,
    ).whenComplete(() => _waiterFloorRefresh = null);
  }

  Future<void> _refreshWaiterFloor({bool silent = false}) async {
    final current = session;
    if (current == null || !isWaiterMode) return;
    if (PosApi.isRateLimited) return;
    if (!silent) {
      waiterRefreshing = true;
      notifyListeners();
    }

    try {
      if (!_waiterAlertsHydrated) {
        waiterAlerts = await PosWaiterAlertsStorage.read(current.branchId);
        _waiterAlertsHydrated = true;
      }

      billRequestedTableIds = await PosBillRequestStorage.read(
        current.branchId,
      );

      if (isOnline) {
        Future<void> loadTables() async {
          try {
            final data = await _api.fetchTables(current);
            tablesSnapshot = data;
            waiterTables = _mapDynamicList(data['tables']);
            waiterTableAreas = _mapDynamicList(data['table_areas']);
            final without = _mapDynamicList(data['tables_without_area']);
            waiterTablesWithoutArea = without.isNotEmpty
                ? without
                : waiterTables.where((t) {
                    final areaId = t['table_area_id'];
                    return areaId == null || '$areaId'.isEmpty;
                  }).toList();
            // Show the floor as soon as tables arrive; orders load alongside it.
            notifyListeners();
          } catch (_) {
            // Keep prior snapshot.
          }
        }

        Future<void> loadHeld() async {
          try {
            waiterHeldOrders = await fetchHeldOrders();
          } catch (_) {}
        }

        Future<void> loadFloorOrders() async {
          try {
            final floor = await _api.fetchFloorOrders(current);
            _detectFloorAlerts(floor);
            waiterRecentOrders = floor;
          } catch (_) {
            try {
              final recent = await _api.fetchRecentOrders(
                current,
                filter: 'floor',
                perPage: 50,
              );
              final orders = _mapDynamicList(recent['orders']);
              _detectFloorAlerts(orders);
              waiterRecentOrders = orders;
            } catch (_) {}
          }
        }

        await Future.wait([loadTables(), loadHeld(), loadFloorOrders()]);

        // Reconcile local billing overlay with server tables + floor tickets.
        // Do not keep stale bill flags after web frees / updates a table.
        await _reconcileBillRequestsFromServer(current.branchId);
      } else {
        try {
          waiterHeldOrders = await fetchHeldOrders();
        } catch (_) {}
      }

      waiterLastRefreshedAt = DateTime.now();
      unawaited(refreshHeldOrderCount());
    } finally {
      if (!silent) waiterRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _reconcileBillRequestsFromServer(int branchId) async {
    final serverBillIds = <int>{
      for (final o in waiterRecentOrders)
        if (o['bill_requested'] == true)
          if (parseJsonIntOrNull(o['table_id']) != null)
            parseJsonIntOrNull(o['table_id'])!,
    };

    final availableOrIdle = <int>{};
    for (final table in waiterTables) {
      final id = parseJsonIntOrNull(table['id']);
      if (id == null) continue;
      final status = (table['status']?.toString() ?? '').toLowerCase();
      if (status == 'available' || status == 'cleaning') {
        availableOrIdle.add(id);
      }
    }

    final next = serverBillIds.difference(availableOrIdle);
    billRequestedTableIds = next;
    await PosBillRequestStorage.write(branchId, next);
  }

  void _detectFloorAlerts(List<Map<String, dynamic>> orders) {
    // Skip first snapshot so existing ready / bill cues do not spam alerts.
    if (waiterLastRefreshedAt == null) return;

    final previousReady = waiterRecentOrders
        .where((o) => '${o['status']}' == 'ready')
        .map((o) => o['id'])
        .toSet();
    final previousBilled = waiterRecentOrders
        .where((o) => o['bill_requested'] == true)
        .map((o) => o['id'])
        .toSet();

    var changed = false;
    for (final order in orders) {
      final id = order['id'];
      final tableName = order['table_name']?.toString();
      final number = order['order_number']?.toString() ?? '#$id';
      final tableId = parseJsonIntOrNull(order['table_id']);
      final orderId = parseJsonIntOrNull(order['id']);

      if ('${order['status']}' == 'ready' && !previousReady.contains(id)) {
        changed =
            _pushWaiterAlert(
              WaiterAlert(
                id: 'ready-$id-${DateTime.now().millisecondsSinceEpoch}',
                type: WaiterAlertType.kitchenReady,
                title: PosTranslationStore.instance.text(
                  'waiterNotificationReadyTitle',
                  'Order ready',
                ),
                body: PosTranslationStore.instance.text(
                  'waiterNotificationReadyBody',
                  '{number} is ready for pickup{table}',
                  replacements: {
                    'number': number,
                    'table': tableName != null && tableName.isNotEmpty
                        ? ' · $tableName'
                        : '',
                  },
                ),
                at: DateTime.now(),
                tableId: tableId,
                orderId: orderId,
                tableName: tableName,
                orderNumber: number,
              ),
              persist: false,
            ) ||
            changed;
      }

      if (order['bill_requested'] == true && !previousBilled.contains(id)) {
        changed =
            _pushWaiterAlert(
              WaiterAlert(
                id: 'bill-$id-${DateTime.now().millisecondsSinceEpoch}',
                type: WaiterAlertType.billRequested,
                title: PosTranslationStore.instance.text(
                  'waiterNotificationBillTitle',
                  'Bill requested',
                ),
                body: PosTranslationStore.instance.text(
                  'waiterNotificationBillBody',
                  '{table} is waiting for checkout',
                  replacements: {
                    'table': tableName != null && tableName.isNotEmpty
                        ? tableName
                        : number,
                  },
                ),
                at: DateTime.now(),
                tableId: tableId,
                orderId: orderId,
                tableName: tableName,
                orderNumber: number,
              ),
              persist: false,
            ) ||
            changed;
      }
    }

    if (changed) {
      unawaited(_persistWaiterAlerts());
    }
  }

  /// Returns true when the alert was added.
  bool _pushWaiterAlert(WaiterAlert alert, {bool persist = true}) {
    // De-dupe identical live cues (same type + order/table within a short window).
    // Treat newOrder / marketplaceOrder as the same order cue for de-dupe.
    final duplicate = waiterAlerts.any(
      (a) =>
          (a.type == alert.type ||
              (a.type.isNewOrderCue && alert.type.isNewOrderCue)) &&
          a.orderId == alert.orderId &&
          a.tableId == alert.tableId &&
          !a.isRead &&
          DateTime.now().difference(a.at).inMinutes < 10,
    );
    if (duplicate) return false;

    if (alert.isPriority) {
      waiterAlerts = [alert, ...waiterAlerts].take(40).toList();
    } else {
      final firstNonPriority = waiterAlerts.indexWhere((a) => !a.isPriority);
      if (firstNonPriority <= 0) {
        waiterAlerts = [alert, ...waiterAlerts].take(40).toList();
      } else {
        waiterAlerts = [
          ...waiterAlerts.take(firstNonPriority),
          alert,
          ...waiterAlerts.skip(firstNonPriority),
        ].take(40).toList();
      }
    }
    if (persist) {
      unawaited(_persistWaiterAlerts());
    }
    return true;
  }

  Future<void> _persistWaiterAlerts() async {
    final branchId = session?.branchId;
    if (branchId == null) return;
    await PosWaiterAlertsStorage.write(branchId, waiterAlerts);
  }

  static List<Map<String, dynamic>> _mapDynamicList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void markWaiterAlertRead(String id) {
    final index = waiterAlerts.indexWhere((a) => a.id == id);
    if (index < 0 || waiterAlerts[index].isRead) return;
    final next = [...waiterAlerts];
    next[index] = next[index].copyWith(isRead: true);
    waiterAlerts = next;
    notifyListeners();
    unawaited(_persistWaiterAlerts());
  }

  void markAllWaiterAlertsRead() {
    if (waiterUnreadAlertCount == 0) return;
    waiterAlerts = [
      for (final a in waiterAlerts) a.isRead ? a : a.copyWith(isRead: true),
    ];
    notifyListeners();
    unawaited(_persistWaiterAlerts());
  }

  void dismissWaiterAlert(String id) {
    final next = waiterAlerts.where((a) => a.id != id).toList();
    if (next.length == waiterAlerts.length) return;
    waiterAlerts = next;
    notifyListeners();
    unawaited(_persistWaiterAlerts());
  }

  void clearWaiterAlerts() {
    if (waiterAlerts.isEmpty) return;
    waiterAlerts = const [];
    notifyListeners();
    unawaited(_persistWaiterAlerts());
  }

  void focusWaiterTable(int? tableId) {
    waiterFocusTableId = tableId;
    notifyListeners();
  }

  int? takeWaiterFocusTableId() {
    final id = waiterFocusTableId;
    waiterFocusTableId = null;
    return id;
  }

  /// Open a notification: mark read and deep-link when possible.
  void openWaiterAlert(WaiterAlert alert) {
    markWaiterAlertRead(alert.id);
    if (alert.tableId != null) {
      focusWaiterTable(alert.tableId);
    }
  }

  @override
  void dispose() {
    _stopPairingPoll();
    _stopRevisionPolling();
    _stopWaiterPolling();
    _stopRegisterAlertPolling();
    _stopNewOrderPolling();
    _cancelDisplaySync();
    _stopPaymentSessionMonitoring();
    _cashierPlacedNoticeTimer?.cancel();
    super.dispose();
  }
}
