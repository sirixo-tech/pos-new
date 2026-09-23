import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/pos_models.dart';
import 'customer_display_models.dart';
import 'customer_display_repository.dart';
import 'customer_voice_service.dart';

class CustomerDisplayState {
  const CustomerDisplayState({
    this.isLoading = true,
    this.isSavingSetup = false,
    this.errorMessage,
    this.restaurantName = '',
    this.restaurantSlug = '',
    this.branchName = '',
    this.branchId = 0,
    this.terminalCode = '',
    this.syncToken = '',
    this.showPrices = true,
    this.preparing = const [],
    this.ready = const [],
    this.history = const [],
    this.cart = const CustomerCart(active: false),
    this.lastUpdated,
  });

  final bool isLoading;
  final bool isSavingSetup;
  final String? errorMessage;
  final String restaurantName;
  final String restaurantSlug;
  final String branchName;
  final int branchId;
  final String terminalCode;
  final String syncToken;
  final bool showPrices;
  final List<CustomerDisplayOrder> preparing;
  final List<CustomerDisplayOrder> ready;
  final List<CustomerDisplayOrder> history;
  final CustomerCart cart;
  final DateTime? lastUpdated;

  bool get hasSyncToken => syncToken.trim().isNotEmpty;
  bool get needsSetup => restaurantSlug.trim().isEmpty || branchId <= 0;

  CustomerDisplayState copyWith({
    bool? isLoading,
    bool? isSavingSetup,
    String? errorMessage,
    bool clearError = false,
    String? restaurantName,
    String? restaurantSlug,
    String? branchName,
    int? branchId,
    String? terminalCode,
    String? syncToken,
    bool? showPrices,
    List<CustomerDisplayOrder>? preparing,
    List<CustomerDisplayOrder>? ready,
    List<CustomerDisplayOrder>? history,
    CustomerCart? cart,
    DateTime? lastUpdated,
  }) {
    return CustomerDisplayState(
      isLoading: isLoading ?? this.isLoading,
      isSavingSetup: isSavingSetup ?? this.isSavingSetup,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantSlug: restaurantSlug ?? this.restaurantSlug,
      branchName: branchName ?? this.branchName,
      branchId: branchId ?? this.branchId,
      terminalCode: terminalCode ?? this.terminalCode,
      syncToken: syncToken ?? this.syncToken,
      showPrices: showPrices ?? this.showPrices,
      preparing: preparing ?? this.preparing,
      ready: ready ?? this.ready,
      history: history ?? this.history,
      cart: cart ?? this.cart,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class CustomerDisplayController extends ChangeNotifier {
  CustomerDisplayController({
    required this.serverUrl,
    required this.voice,
    this.session,
    this.bootstrap,
    this.terminal,
    CustomerDisplayRepository? repository,
  }) : _repository = repository ?? CustomerDisplayRepository();

  final String serverUrl;
  final CustomerVoiceService voice;
  final PosSession? session;
  final PosBootstrap? bootstrap;
  final PosTerminalInfo? terminal;
  final CustomerDisplayRepository _repository;

  CustomerDisplayState state = const CustomerDisplayState();
  Timer? _pollTimer;
  bool _cartMode = false;
  int? _routeBranchId;
  String? _routeTerminalCode;
  final Map<String, DateTime> _readyTokenEntryTimes = {};
  final Set<String> _permanentlyExpiredTokens = {};
  final Set<String> _announcedTokens = {};
  List<CustomerDisplayOrder> _orderedReadyOrders = [];
  bool _persistedStateLoaded = false;

  String get _todayKey {
    final now = DateTime.now();
    return 'cust_board_${now.year}_${now.month}_${now.day}';
  }

  Future<void> showOrderBoard() async {
    _cartMode = false;
    _routeBranchId = null;
    _routeTerminalCode = null;
    await _load();
  }

  Future<void> showCartDisplay({int? branchId, String? terminalCode}) async {
    _cartMode = true;
    _routeBranchId = branchId;
    _routeTerminalCode = _normalizedTerminal(terminalCode);
    await _load();
  }

  Future<void> saveSetup({
    required String restaurantSlug,
    required int branchId,
    required String terminalCode,
    required String syncToken,
  }) async {
    state = state.copyWith(isSavingSetup: true, clearError: true);
    notifyListeners();
    final normalizedSlug = _slugFrom(restaurantSlug);
    final normalizedTerminal = _normalizedTerminal(terminalCode) ?? '';
    if (normalizedSlug.isEmpty || branchId <= 0 || normalizedTerminal.isEmpty) {
      state = state.copyWith(
        isSavingSetup: false,
        errorMessage:
            'Restaurant, branch, and terminal must come from a valid setup.',
      );
      notifyListeners();
      return;
    }
    await _repository.saveSetup(
      restaurantSlug: normalizedSlug,
      branchId: branchId,
      terminalCode: normalizedTerminal,
      syncToken: syncToken,
    );
    state = state.copyWith(
      isSavingSetup: false,
      restaurantSlug: normalizedSlug,
      branchId: branchId,
      terminalCode: normalizedTerminal,
      syncToken: syncToken.trim(),
      clearError: true,
    );
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() => _poll();

  Future<void> _load() async {
    final setup = await _repository.readSetup(
      session: session,
      bootstrap: bootstrap,
      terminal: terminal,
    );
    final branchId = _routeBranchId ?? setup.branchId;
    final terminalCode = _routeTerminalCode ?? setup.terminalCode;
    state = state.copyWith(
      restaurantName: setup.restaurantName,
      restaurantSlug: setup.restaurantSlug,
      branchName: setup.branchName,
      branchId: branchId,
      terminalCode: terminalCode,
      syncToken: setup.syncToken,
      showPrices: setup.showPrices,
    );
    notifyListeners();
    if (state.needsSetup || state.terminalCode.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Customer display setup is missing.',
      );
      notifyListeners();
      return;
    }
    await _poll();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      if (_cartMode) {
        final cart = await _repository.pollCart(
          serverUrl: serverUrl,
          branchId: state.branchId,
          terminalCode: state.terminalCode,
          syncToken: state.syncToken,
        );
        state = state.copyWith(
          isLoading: false,
          cart: cart,
          restaurantName: cart.restaurantName ?? state.restaurantName,
          branchName: cart.branchName ?? state.branchName,
          terminalCode: cart.terminalCode ?? state.terminalCode,
          lastUpdated: DateTime.now(),
          clearError: true,
        );
        notifyListeners();
        return;
      }

      final board = await _repository.pollBoard(
        serverUrl: serverUrl,
        session: session,
        restaurantSlug: state.restaurantSlug,
        branchId: state.branchId,
        terminalCode: state.terminalCode,
      );
      await _loadPersistedState();
      final now = DateTime.now();
      final freshReady = board.ready.where((order) {
        final key = _orderKey(order);
        return key.isNotEmpty && !_permanentlyExpiredTokens.contains(key);
      }).toList();
      final currentReadyMap = <String, CustomerDisplayOrder>{
        for (final order in freshReady) _orderKey(order): order,
      };

      for (final order in freshReady) {
        final key = _orderKey(order);
        if (!_readyTokenEntryTimes.containsKey(key)) {
          _readyTokenEntryTimes[key] = now;
          _orderedReadyOrders.insert(0, order);
          if (!_announcedTokens.contains(key)) {
            _announcedTokens.add(key);
            final displayToken = order.token.trim().isNotEmpty
                ? order.token.trim()
                : order.orderNumber.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
            if (displayToken.isNotEmpty) {
              voice.announceReadyToken(displayToken);
            }
          }
        }
      }

      _orderedReadyOrders = _orderedReadyOrders
          .where((order) => currentReadyMap.containsKey(_orderKey(order)))
          .toList();
      for (final order in freshReady) {
        final key = _orderKey(order);
        if (!_orderedReadyOrders.any((item) => _orderKey(item) == key)) {
          _orderedReadyOrders.add(order);
        }
      }

      const autoDisappearDuration = Duration(minutes: 20);
      final expiredKeys = _readyTokenEntryTimes.entries
          .where((entry) => now.difference(entry.value) >= autoDisappearDuration)
          .map((entry) => entry.key)
          .toList();
      for (final expKey in expiredKeys) {
        _permanentlyExpiredTokens.add(expKey);
        _readyTokenEntryTimes.remove(expKey);
        _orderedReadyOrders.removeWhere((order) => _orderKey(order) == expKey);
      }
      await _persistState();

      state = state.copyWith(
        isLoading: false,
        preparing: board.preparing,
        ready: _orderedReadyOrders,
        history: board.history,
        cart: board.cart,
        lastUpdated: DateTime.now(),
        clearError: true,
      );
      notifyListeners();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error is CustomerDisplayException
            ? error.message
            : 'Customer display is waiting for the server.',
      );
      notifyListeners();
    }
  }

  String _orderKey(CustomerDisplayOrder order) {
    final token = order.token.trim();
    return token.isNotEmpty ? token : order.orderNumber.trim();
  }

  Future<void> _loadPersistedState() async {
    if (_persistedStateLoaded) return;
    _persistedStateLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final announced = prefs.getString('${_todayKey}_announced');
      if (announced != null) {
        _announcedTokens.addAll(
          (json.decode(announced) as List).map((e) => e.toString()),
        );
      }
      final expired = prefs.getString('${_todayKey}_expired');
      if (expired != null) {
        _permanentlyExpiredTokens.addAll(
          (json.decode(expired) as List).map((e) => e.toString()),
        );
      }
      final entryTimes = prefs.getString('${_todayKey}_entry_times');
      if (entryTimes != null) {
        final map = json.decode(entryTimes) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final millis = entry.value as int?;
          if (millis != null) {
            _readyTokenEntryTimes[entry.key] =
                DateTime.fromMillisecondsSinceEpoch(millis);
          }
        }
      }
    } catch (error) {
      debugPrint('[CustomerDisplay] persist load: $error');
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_todayKey}_announced',
        json.encode(_announcedTokens.toList()),
      );
      await prefs.setString(
        '${_todayKey}_expired',
        json.encode(_permanentlyExpiredTokens.toList()),
      );
      await prefs.setString(
        '${_todayKey}_entry_times',
        json.encode({
          for (final entry in _readyTokenEntryTimes.entries)
            entry.key: entry.value.millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

String? _normalizedTerminal(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _slugFrom(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
