import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_models.dart';
import '../models/pos_models.dart';
import '../services/pos_api.dart';
import '../utils/pos_user_facing_error.dart';
import 'pos_controller.dart';

class PosAdminController extends ChangeNotifier {
  PosAdminController({required PosApi api, required PosController pos})
    : _api = api,
      _pos = pos {
    _applyMenuCache();
  }

  static AdminMenuPayload? _menuCache;
  static String? _menuCacheKey;
  static Future<AdminMenuPayload>? _menuInFlight;
  static String? _menuInFlightKey;

  /// Start the menu request before the popup opens so the list is ready.
  static Future<void> warm(PosApi api, PosController pos) async {
    if (pos.session == null) return;
    final controller = PosAdminController(api: api, pos: pos);
    try {
      await controller.loadMenu();
    } finally {
      controller.dispose();
    }
  }

  final PosApi _api;
  final PosController _pos;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<AdminMenuCategory> categories = const [];
  List<AdminMenuModifier> modifiers = const [];
  List<AdminMenuTimeSlot> timeSlots = const [];
  AdminTablesPayload? tablesPayload;
  AdminOrdersPage? ordersPage;
  Map<String, dynamic>? selectedOrder;

  bool menuLoading = false;
  bool tablesLoading = false;
  bool ordersLoading = false;
  bool mutating = false;
  final Set<String> _menuSaves = {};
  Set<int> get savingItemIds => {
    for (final key in _menuSaves)
      if (key.startsWith('item:')) int.parse(key.substring(5)),
  };
  Set<int> get savingCategoryIds => {
    for (final key in _menuSaves)
      if (key.startsWith('category:')) int.parse(key.substring(9)),
  };

  Future<bool> _runMenuSave(String key, Future<void> Function() action) async {
    if (!_menuSaves.add(key)) return false;
    clearError();
    notifyListeners();
    try {
      await action();
      await loadMenu();
      unawaited(_refreshMenuBootstrap());
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _menuSaves.remove(key);
      notifyListeners();
    }
  }

  String? error;

  PosSession? get session => _pos.session;

  PosAdminCapabilities get capabilities => _pos.staffAdminCapabilities;

  bool get canViewMenu => capabilities.canViewMenu;
  bool get canManageMenu => capabilities.canManageMenu;
  bool get canManageMenuCategories => capabilities.canManageMenuCategories;
  bool get canManageMenuItems => capabilities.canManageMenuItems;
  bool get canManageMenuModifiers => capabilities.canManageMenuModifiers;
  bool get canManageMenuTimeSlots => capabilities.canManageMenuTimeSlots;
  bool get canToggleMenuAvailability => capabilities.canToggleMenuAvailability;
  bool get canViewTables => capabilities.canViewTables;
  bool get canManageTables => capabilities.canManageTables;
  bool get canViewOrders => capabilities.canViewOrders;
  bool get canManageOrders => capabilities.canManageOrders;
  bool get canManageSettings => capabilities.canManageSettings;
  bool get canAccessAdmin => capabilities.canAccessAdmin;

  bool _allowed(bool permission) {
    if (session != null && permission) return true;
    error = 'You do not have permission for this action.';
    notifyListeners();
    return false;
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  void _setError(Object e) {
    error = posUserFacingError(e);
    notifyListeners();
  }

  PosSession _requireSession() {
    final current = session;
    if (current == null) {
      throw PosApiException('Not signed in.');
    }
    return current;
  }

  Future<void> _refreshMenuBootstrap() async {
    try {
      await _pos.refreshBootstrap();
    } catch (_) {
      // Menu local state is already updated; bootstrap refresh is best-effort.
    }
  }

  Future<T?> _runMutation<T>(Future<T> Function() action) async {
    clearError();
    mutating = true;
    notifyListeners();
    try {
      final result = await action();
      return result;
    } catch (e) {
      _setError(e);
      return null;
    } finally {
      mutating = false;
      notifyListeners();
    }
  }

  String get _menuKey {
    final current = session;
    return '${current?.restaurantId}|${current?.branchId}';
  }

  void _applyMenuCache() {
    if (_menuCacheKey != _menuKey || _menuCache == null) return;
    categories = _menuCache!.categories;
    modifiers = _menuCache!.modifiers;
    timeSlots = _menuCache!.timeSlots;
  }

  void _rememberMenu(AdminMenuPayload payload) {
    _menuCache = payload;
    _menuCacheKey = _menuKey;
  }

  Future<AdminMenuPayload> _sharedMenu(PosSession current) {
    final key = _menuKey;
    final existing = _menuInFlight;
    if (existing != null && _menuInFlightKey == key) return existing;
    _menuInFlightKey = key;
    final future = _api.fetchAdminMenu(current).whenComplete(() {
      if (_menuInFlightKey == key) _menuInFlight = null;
    });
    _menuInFlight = future;
    return future;
  }

  Future<void> loadMenu() async {
    if (!_allowed(_pos.canViewStaffMenu)) return;
    if (_disposed) return;
    final showSpinner = categories.isEmpty;
    if (showSpinner) {
      clearError();
      menuLoading = true;
      notifyListeners();
    }
    try {
      final payload = await _sharedMenu(_requireSession());
      categories = payload.categories;
      modifiers = payload.modifiers;
      timeSlots = payload.timeSlots;
      _rememberMenu(payload);
    } catch (e) {
      if (categories.isEmpty) _setError(e);
    } finally {
      menuLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createMenuCategory(
    Map<String, dynamic> body, {
    XFile? imageFile,
  }) async {
    if (!_allowed(canManageMenu || canManageMenuCategories)) return false;
    return _runMenuSave('new-category', () async {
      await _api.createAdminMenuCategory(
        _requireSession(),
        body: {'is_active': true, ...body},
        imageFile: imageFile,
      );
    });
  }

  Future<bool> updateMenuCategory(
    int id,
    Map<String, dynamic> body, {
    XFile? imageFile,
  }) async {
    if (!_allowed(canManageMenu || canManageMenuCategories)) return false;
    final currentStatus = categories
        .where((category) => category.id == id)
        .firstOrNull
        ?.isActive;
    return _runMenuSave('category:$id', () async {
      await _api.updateAdminMenuCategory(
        _requireSession(),
        id: id,
        body: {if (currentStatus != null) 'is_active': currentStatus, ...body},
        imageFile: imageFile,
      );
    });
  }

  Future<bool> toggleMenuCategory(int id) async {
    if (!_allowed(canToggleMenuAvailability || canManageMenu)) return false;
    if (_menuSaves.contains('category:$id')) return false;
    clearError();
    final index = categories.indexWhere((c) => c.id == id);
    if (index < 0) return false;

    final previous = categories[index];
    final optimistic = previous.copyWith(isActive: !previous.isActive);
    categories = [...categories]..[index] = optimistic;
    notifyListeners();

    try {
      final active = await _api.toggleAdminMenuCategoryActive(
        _requireSession(),
        id: id,
      );
      final latestIndex = categories.indexWhere((c) => c.id == id);
      if (latestIndex >= 0 && categories[latestIndex].isActive != active) {
        categories = [...categories]
          ..[latestIndex] = categories[latestIndex].copyWith(isActive: active);
        notifyListeners();
      }
      unawaited(_refreshMenuBootstrap());
      return true;
    } catch (e) {
      final latestIndex = categories.indexWhere((c) => c.id == id);
      if (latestIndex >= 0) {
        categories = [...categories]..[latestIndex] = previous;
      }
      _setError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMenuCategory(int id) async {
    if (!_allowed(canManageMenu || canManageMenuCategories)) return false;
    if (_menuSaves.contains('category:$id')) return false;
    final ok = await _runMutation(() async {
      await _api.deleteAdminMenuCategory(_requireSession(), id: id);
      await loadMenu();
      await _refreshMenuBootstrap();
      return true;
    });
    return ok == true;
  }

  void stageCategoryOrder(List<int> order) {
    final byId = {for (final category in categories) category.id: category};
    final next = <AdminMenuCategory>[
      for (final id in order)
        if (byId[id] != null) byId[id]!,
    ];
    if (next.length != categories.length) return;
    categories = next;
    notifyListeners();
  }

  Future<bool> reorderMenuCategories(List<int> order) async {
    if (!_allowed(canManageMenu || canManageMenuCategories)) return false;
    final ok = await _runMutation(() async {
      await _api.reorderAdminMenuCategories(_requireSession(), order: order);
      await loadMenu();
      await _refreshMenuBootstrap();
      return true;
    });
    return ok == true;
  }

  Future<bool> reorderMenuItems({
    required int categoryId,
    required List<int> order,
  }) async {
    if (!_allowed(canManageMenu || canManageMenuItems)) return false;
    final ok = await _runMutation(() async {
      await _api.reorderAdminMenuItems(
        _requireSession(),
        categoryId: categoryId,
        order: order,
      );
      await loadMenu();
      await _refreshMenuBootstrap();
      return true;
    });
    return ok == true;
  }

  Future<bool> createMenuItem(
    Map<String, dynamic> body, {
    XFile? imageFile,
  }) async {
    if (!_allowed(canManageMenu || canManageMenuItems)) return false;
    return _runMenuSave('new-item', () async {
      await _api.createAdminMenuItem(
        _requireSession(),
        body: {'is_available': true, ...body},
        imageFile: imageFile,
      );
    });
  }

  Future<bool> updateMenuItem(
    int id,
    Map<String, dynamic> body, {
    XFile? imageFile,
  }) async {
    if (!_allowed(canManageMenu || canManageMenuItems)) return false;
    final currentStatus = categories
        .expand((category) => category.items)
        .where((item) => item.id == id)
        .firstOrNull
        ?.isAvailable;
    return _runMenuSave('item:$id', () async {
      await _api.updateAdminMenuItem(
        _requireSession(),
        id: id,
        body: {
          if (currentStatus != null) 'is_available': currentStatus,
          ...body,
        },
        imageFile: imageFile,
      );
    });
  }

  Future<bool> toggleMenuItem(int id) async {
    if (!_allowed(canToggleMenuAvailability || canManageMenu)) return false;
    if (_menuSaves.contains('item:$id')) return false;
    clearError();
    var catIndex = -1;
    var itemIndex = -1;
    for (var i = 0; i < categories.length; i++) {
      final j = categories[i].items.indexWhere((item) => item.id == id);
      if (j >= 0) {
        catIndex = i;
        itemIndex = j;
        break;
      }
    }
    if (catIndex < 0 || itemIndex < 0) return false;

    final category = categories[catIndex];
    final previous = category.items[itemIndex];
    final optimisticItem = previous.copyWith(
      isAvailable: !previous.isAvailable,
    );
    final optimisticItems = [...category.items]..[itemIndex] = optimisticItem;
    categories = [...categories]
      ..[catIndex] = category.copyWith(items: optimisticItems);
    notifyListeners();

    try {
      final available = await _api.toggleAdminMenuItemAvailable(
        _requireSession(),
        id: id,
      );
      catIndex = -1;
      itemIndex = -1;
      for (var i = 0; i < categories.length; i++) {
        final j = categories[i].items.indexWhere((item) => item.id == id);
        if (j >= 0) {
          catIndex = i;
          itemIndex = j;
          break;
        }
      }
      if (catIndex >= 0 &&
          itemIndex >= 0 &&
          categories[catIndex].items[itemIndex].isAvailable != available) {
        final cat = categories[catIndex];
        final items = [...cat.items]
          ..[itemIndex] = cat.items[itemIndex].copyWith(isAvailable: available);
        categories = [...categories]..[catIndex] = cat.copyWith(items: items);
        notifyListeners();
      }
      unawaited(_refreshMenuBootstrap());
      return true;
    } catch (e) {
      catIndex = -1;
      itemIndex = -1;
      for (var i = 0; i < categories.length; i++) {
        final j = categories[i].items.indexWhere((item) => item.id == id);
        if (j >= 0) {
          catIndex = i;
          itemIndex = j;
          break;
        }
      }
      if (catIndex >= 0 && itemIndex >= 0) {
        final cat = categories[catIndex];
        final items = [...cat.items]..[itemIndex] = previous;
        categories = [...categories]..[catIndex] = cat.copyWith(items: items);
      }
      _setError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMenuItem(int id) async {
    if (!_allowed(canManageMenu || canManageMenuItems)) return false;
    if (_menuSaves.contains('item:$id')) return false;
    final ok = await _runMutation(() async {
      await _api.deleteAdminMenuItem(_requireSession(), id: id);
      await loadMenu();
      await _refreshMenuBootstrap();
      return true;
    });
    return ok == true;
  }

  Future<bool> createModifier(Map<String, dynamic> body) async {
    if (!_allowed(canManageMenu || canManageMenuModifiers)) return false;
    final ok = await _runMutation(() async {
      await _api.createAdminModifier(_requireSession(), body: body);
      await loadMenu();
      return true;
    });
    return ok == true;
  }

  Future<bool> updateModifier(int id, Map<String, dynamic> body) async {
    if (!_allowed(canManageMenu || canManageMenuModifiers)) return false;
    final ok = await _runMutation(() async {
      await _api.updateAdminModifier(_requireSession(), id: id, body: body);
      await loadMenu();
      return true;
    });
    return ok == true;
  }

  Future<bool> deleteModifier(int id) async {
    if (!_allowed(canManageMenu || canManageMenuModifiers)) return false;
    final ok = await _runMutation(() async {
      await _api.deleteAdminModifier(_requireSession(), id: id);
      await loadMenu();
      return true;
    });
    return ok == true;
  }

  Future<bool> createTimeSlot(Map<String, dynamic> body) async {
    if (!_allowed(canManageMenu || canManageMenuTimeSlots)) return false;
    final ok = await _runMutation(() async {
      await _api.createAdminTimeSlot(_requireSession(), body: body);
      await loadMenu();
      await _refreshMenuBootstrap();
      return true;
    });
    return ok == true;
  }

  Future<bool> updateTimeSlot(int id, Map<String, dynamic> body) async {
    if (!_allowed(canManageMenu || canManageMenuTimeSlots)) return false;
    final ok = await _runMutation(() async {
      await _api.updateAdminTimeSlot(_requireSession(), id: id, body: body);
      await loadMenu();
      await _refreshMenuBootstrap();
      return true;
    });
    return ok == true;
  }

  Future<bool> deleteTimeSlot(int id) async {
    if (!_allowed(canManageMenu || canManageMenuTimeSlots)) return false;
    final ok = await _runMutation(() async {
      await _api.deleteAdminTimeSlot(_requireSession(), id: id);
      await loadMenu();
      await _refreshMenuBootstrap();
      return true;
    });
    return ok == true;
  }

  Future<void> loadTables() async {
    if (!_allowed(canViewTables || canManageTables)) return;
    clearError();
    tablesLoading = true;
    notifyListeners();
    try {
      tablesPayload = await _api.fetchAdminTables(_requireSession());
    } catch (e) {
      _setError(e);
    } finally {
      tablesLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTable(Map<String, dynamic> body) async {
    if (!_allowed(canManageTables)) return false;
    final ok = await _runMutation(() async {
      await _api.createAdminTable(_requireSession(), body: body);
      await loadTables();
      return true;
    });
    return ok == true;
  }

  Future<bool> updateTable(int id, Map<String, dynamic> body) async {
    if (!_allowed(canManageTables)) return false;
    final ok = await _runMutation(() async {
      await _api.updateAdminTable(_requireSession(), id: id, body: body);
      await loadTables();
      return true;
    });
    return ok == true;
  }

  Future<bool> deleteTable(int id) async {
    if (!_allowed(canManageTables)) return false;
    final ok = await _runMutation(() async {
      await _api.deleteAdminTable(_requireSession(), id: id);
      await loadTables();
      return true;
    });
    return ok == true;
  }

  Future<bool> updateTableStatus(int id, String status) async {
    if (!_allowed(canManageTables)) return false;
    final ok = await _runMutation(() async {
      await _api.updateAdminTableStatus(
        _requireSession(),
        id: id,
        status: status,
      );
      await loadTables();
      return true;
    });
    return ok == true;
  }

  Future<bool> createTableArea(Map<String, dynamic> body) async {
    if (!_allowed(canManageTables)) return false;
    final ok = await _runMutation(() async {
      await _api.createAdminTableArea(_requireSession(), body: body);
      await loadTables();
      return true;
    });
    return ok == true;
  }

  Future<bool> updateTableArea(int id, Map<String, dynamic> body) async {
    if (!_allowed(canManageTables)) return false;
    final ok = await _runMutation(() async {
      await _api.updateAdminTableArea(_requireSession(), id: id, body: body);
      await loadTables();
      return true;
    });
    return ok == true;
  }

  Future<bool> deleteTableArea(int id) async {
    if (!_allowed(canManageTables)) return false;
    final ok = await _runMutation(() async {
      await _api.deleteAdminTableArea(_requireSession(), id: id);
      await loadTables();
      return true;
    });
    return ok == true;
  }

  Future<bool> updateFloorPlan(Map<String, dynamic> body) async {
    if (!_allowed(canManageTables)) return false;
    final ok = await _runMutation(() async {
      await _api.updateAdminFloorPlan(_requireSession(), body: body);
      await loadTables();
      return true;
    });
    return ok == true;
  }

  Future<void> loadOrders({
    String? q,
    String? status,
    String? source,
    String period = 'today',
    String payment = 'all',
    int page = 1,
    bool silent = false,
  }) async {
    if (!_allowed(canViewOrders || canManageOrders)) return;
    if (ordersLoading) return;
    if (PosApi.isRateLimited) return;
    clearError();
    final showLoading = !silent || ordersPage == null;
    if (showLoading) {
      ordersLoading = true;
      notifyListeners();
    }
    try {
      final pageResult = await _api.fetchAdminOrders(
        _requireSession(),
        q: q,
        status: status,
        source: source,
        period: period,
        payment: payment,
        page: page,
      );
      if ((status == null || status.isEmpty) && page == 1) {
        ordersPage = await _withTodayDrafts(
          pageResult,
          q: q,
          source: source,
          period: period,
          payment: payment,
        );
      } else {
        ordersPage = pageResult;
      }
    } catch (e) {
      _setError(e);
    } finally {
      if (showLoading) {
        ordersLoading = false;
      }
      notifyListeners();
    }
  }

  Future<AdminOrdersPage> _withTodayDrafts(
    AdminOrdersPage page, {
    String? q,
    String? source,
    required String period,
    required String payment,
  }) async {
    try {
      final drafts = await _api.fetchAdminOrders(
        _requireSession(),
        q: q,
        status: 'draft',
        source: source,
        period: period,
        payment: payment,
        page: 1,
      );
      final seen = page.orders.map((order) => order.id).toSet();
      final extra = drafts.orders.where((order) => seen.add(order.id)).toList();
      if (extra.isEmpty) return page;
      return AdminOrdersPage(
        orders: [...extra, ...page.orders],
        currentPage: page.currentPage,
        lastPage: page.lastPage,
        total: page.total + extra.length,
      );
    } catch (_) {
      return page;
    }
  }

  Future<Map<String, dynamic>?> loadOrder(String orderKey) async {
    clearError();
    selectedOrder = null;
    notifyListeners();
    try {
      selectedOrder = await _api.fetchAdminOrder(
        _requireSession(),
        orderKey: orderKey,
      );
      notifyListeners();
      return selectedOrder;
    } catch (e) {
      // Register / waiter staff may lack view_orders — fall back to POS detail.
      final id = int.tryParse(orderKey);
      if (id != null) {
        try {
          selectedOrder = await _api.fetchOrderForView(
            _requireSession(),
            orderId: id,
          );
          notifyListeners();
          return selectedOrder;
        } catch (_) {
          // Prefer the original admin error below.
        }
      }
      _setError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateOrderStatus(
    String orderKey,
    String status, {
    bool refund = false,
    String? cancelReason,
    String? cancelNote,
  }) async {
    if (!_allowed(canManageOrders)) return false;
    final ok = await _runMutation(() async {
      selectedOrder = await _api.updateAdminOrderStatus(
        _requireSession(),
        orderKey: orderKey,
        status: status,
        refund: refund,
        cancelReason: cancelReason,
        cancelNote: cancelNote,
      );
      return true;
    });
    return ok == true;
  }

  Future<bool> reopenOrder(String orderKey) async {
    if (!_allowed(canManageOrders)) return false;
    final ok = await _runMutation(() async {
      selectedOrder = await _api.reopenAdminOrder(
        _requireSession(),
        orderKey: orderKey,
      );
      return true;
    });
    return ok == true;
  }

  Future<bool> markOrderPaid(
    String orderKey, {
    String? method,
    bool complete = false,
  }) async {
    if (!_allowed(canManageOrders)) return false;
    final ok = await _runMutation(() async {
      selectedOrder = await _api.markAdminOrderPaid(
        _requireSession(),
        orderKey: orderKey,
        method: method,
        complete: complete,
      );
      return true;
    });
    return ok == true;
  }

  Future<bool> updateOrderPaymentStatus(
    String orderKey,
    String paymentStatus, {
    String? paymentMethod,
  }) async {
    if (!_allowed(canManageOrders)) return false;
    final ok = await _runMutation(() async {
      selectedOrder = await _api.updateAdminOrderPaymentStatus(
        _requireSession(),
        orderKey: orderKey,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
      );
      return true;
    });
    return ok == true;
  }

  Future<AdminPaymentCheckResult?> checkOrderPayment(String orderKey) async {
    return _runMutation(() async {
      final result = await _api.checkAdminOrderPayment(
        _requireSession(),
        orderKey: orderKey,
      );
      if (result.order != null) {
        selectedOrder = result.order;
      }
      return result;
    });
  }
}
