import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/kitchen_models.dart';
import '../models/pos_models.dart';
import '../services/kot_reset_time.dart';
import '../services/pos_api.dart';
import '../services/pos_cart_sound.dart';
import '../services/printing/print_job_coordinator.dart';
import '../utils/kitchen_board.dart';

/// Kitchen / KOT display board state (polls `/api/v1/kitchen/*`).
class KitchenController extends ChangeNotifier {
  KitchenController({PosApi? api, PrintJobCoordinator? printJobs})
    : _api = api ?? PosApi(),
      _printJobs = printJobs;

  final PosApi _api;
  final PrintJobCoordinator? _printJobs;

  KitchenBootstrap? bootstrap;
  KitchenBoard board = emptyKitchenBoard();
  Map<String, List<KitchenBoardOrder>> lanes = const {};

  int? selectedKitchenId;
  String? selectedChannel;
  KitchenTicketSort selectedSort = KitchenTicketSort.priority;
  bool loading = true;
  bool refreshing = false;
  String? errorMessage;
  DateTime? lastRefresh;

  Timer? _pollTimer;
  Timer? _autoDeliverTimer;
  String? _kitchenToken;
  PosSession? _session;
  TimeOfDay kotResetTime = KotResetTimeSettings.defaultTime;
  static const _autoDeliverAfter = Duration(minutes: 15);
  static const _readyTimesKey = 'kot_ready_entry_times';
  final Map<int, DateTime> _readyOrderEntryTimes = {};
  final Set<int> _knownOrderIds = {};
  bool _soundPrimed = false;

  int get totalActive => board.totalActive;

  int get readyCount => board.ready.length;

  int get attentionCount {
    final queueRequired = bootstrap?.queueRequired ?? false;
    final laneMap = bucketBoardToLanes(board, queueRequired);
    final newCount = laneMap['new']?.length ?? 0;
    final confirmedCount = laneMap['confirmed']?.length ?? 0;
    final preparingCount = laneMap['preparing']?.length ?? 0;
    return newCount + confirmedCount + preparingCount;
  }

  bool get isActive => _session != null && _kitchenToken != null;

  Future<void> ensureRunning({
    required PosSession session,
    required Future<String> Function() ensureKitchenToken,
    bool userInitiated = false,
  }) async {
    if (isActive && _session!.branchId == session.branchId) {
      if (_pollTimer == null) _startPolling();
      _startAutoDeliverChecker();
      if (userInitiated) await _refresh(silent: false);
      return;
    }
    await start(session: session, ensureKitchenToken: ensureKitchenToken);
  }

  Future<void> start({
    required PosSession session,
    required Future<String> Function() ensureKitchenToken,
  }) async {
    _session = session;
    _kitchenToken = await ensureKitchenToken();
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      bootstrap = await _api.fetchKitchenBootstrap(
        session: session,
        kitchenToken: _kitchenToken!,
      );
      selectedKitchenId = await _readStoredKitchenFilter(session.branchId);
      kotResetTime = await KotResetTimeSettings.read();
      await _loadPersistedReadyTimes();
      await _refresh(silent: false);
      _startPolling();
      _startAutoDeliverChecker();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _autoDeliverTimer?.cancel();
    _autoDeliverTimer = null;
    _kitchenToken = null;
    _session = null;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(kitchenPollInterval, (_) {
      unawaited(_refresh(silent: true));
    });
  }

  Future<void> refresh({bool userInitiated = false}) =>
      _refresh(silent: !userInitiated);

  Future<void> _refresh({required bool silent}) async {
    final session = _session;
    final token = _kitchenToken;
    if (session == null || token == null) return;

    if (!silent) {
      refreshing = true;
      notifyListeners();
    }

    try {
      final result = await _api.fetchKitchenOrders(
        session: session,
        kitchenToken: token,
        kitchenId: selectedKitchenId,
      );
      board = _applyKotReset(result.board);
      _trackReadyOrderTimes(board);
      _checkAndPlayNewOrderSound(board);
      _rebuildLanes();
      lastRefresh = DateTime.now();
      errorMessage = null;
      unawaited(_checkAutoDeliverReadyOrders());
    } catch (e) {
      if (!silent) {
        errorMessage = e.toString();
      }
    } finally {
      if (!silent) {
        refreshing = false;
      }
      notifyListeners();
    }
  }

  Future<void> setKotResetTime(TimeOfDay time) async {
    kotResetTime = time;
    await KotResetTimeSettings.save(time);
    notifyListeners();
    await _refresh(silent: true);
  }

  KitchenBoard _applyKotReset(KitchenBoard incoming) {
    final cutoff = KotResetTimeSettings.cutoff(kotResetTime);
    List<KitchenBoardOrder> keep(List<KitchenBoardOrder> list) {
      return list
          .where(
            (order) =>
                order.createdAt == null || !order.createdAt!.isBefore(cutoff),
          )
          .toList();
    }

    return KitchenBoard(
      pending: keep(incoming.pending),
      confirmed: keep(incoming.confirmed),
      preparing: keep(incoming.preparing),
      ready: keep(incoming.ready),
    );
  }

  int _ticketKey(KitchenBoardOrder order) =>
      order.kitchenTicketId > 0 ? order.kitchenTicketId : order.id;

  void _startAutoDeliverChecker() {
    _autoDeliverTimer?.cancel();
    _autoDeliverTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_checkAutoDeliverReadyOrders());
    });
    unawaited(_checkAutoDeliverReadyOrders());
  }

  void _trackReadyOrderTimes(KitchenBoard current) {
    final now = DateTime.now();
    final currentReadyIds = <int>{};
    var changed = false;
    for (final order in current.ready) {
      final key = _ticketKey(order);
      currentReadyIds.add(key);
      if (!_readyOrderEntryTimes.containsKey(key)) {
        _readyOrderEntryTimes[key] = order.createdAt ?? now;
        changed = true;
      }
    }
    final stale = _readyOrderEntryTimes.keys
        .where((id) => !currentReadyIds.contains(id))
        .toList();
    for (final id in stale) {
      _readyOrderEntryTimes.remove(id);
      changed = true;
    }
    if (changed) unawaited(_persistReadyOrderTimes());
  }

  Future<void> _checkAutoDeliverReadyOrders() async {
    if (!isActive) return;
    final now = DateTime.now();
    final readyLane = kitchenLanesFor(
      bootstrap?.queueRequired ?? false,
    ).firstWhere((lane) => lane.key == 'ready');
    final due = board.ready.where((order) {
      final entry = _readyOrderEntryTimes[_ticketKey(order)];
      return entry != null && now.difference(entry) >= _autoDeliverAfter;
    }).toList();
    for (final order in due) {
      _readyOrderEntryTimes.remove(_ticketKey(order));
      await advanceOrder(order, 'delivered', lane: readyLane);
    }
    if (due.isNotEmpty) {
      await _persistReadyOrderTimes();
    }
  }

  void _checkAndPlayNewOrderSound(KitchenBoard current) {
    final live = [
      ...current.pending,
      ...current.confirmed,
      ...current.preparing,
    ];
    if (!_soundPrimed) {
      _knownOrderIds.addAll(live.map(_ticketKey));
      _soundPrimed = true;
      return;
    }
    var hasNew = false;
    final fresh = <KitchenBoardOrder>[];
    for (final order in live) {
      if (_knownOrderIds.add(_ticketKey(order))) {
        hasNew = true;
        fresh.add(order);
      }
    }
    if (hasNew) {
      unawaited(PosCartSound.instance.playKitchenNewOrder());
      unawaited(_enqueueNewKotPrints(fresh));
    }
  }

  Future<void> _enqueueNewKotPrints(List<KitchenBoardOrder> orders) async {
    final jobs = _printJobs;
    if (jobs == null || orders.isEmpty) return;
    for (final order in orders) {
      unawaited(
        jobs.enqueueKot(
          orderId: order.id,
          orderNumber: order.orderNumber,
          source: order.source ?? '',
          order: {
            'id': order.id,
            'order_number': order.orderNumber,
            'source': order.source,
            'status': order.status,
          },
        ),
      );
    }
  }

  /// After a PWA/online QR is scanned at POS (`handoff=1`), drop matching
  /// kitchen cards so a ready pickup disappears with the printed receipt.
  Future<bool> clearHandoffForOrderNumber(String orderNumber) async {
    final needle = orderNumber.trim().toUpperCase();
    if (needle.isEmpty) return false;
    final matches = allActiveOrders.where((order) {
      final number = order.orderNumber.trim().toUpperCase();
      return number == needle ||
          '${order.id}' == orderNumber.trim() ||
          (order.token ?? '').trim().toUpperCase() == needle;
    }).toList();
    if (matches.isEmpty) {
      await _refresh(silent: true);
      return false;
    }
    final readyLane = kitchenLanesFor(
      bootstrap?.queueRequired ?? false,
    ).firstWhere((lane) => lane.key == 'ready');
    for (final order in matches) {
      await advanceOrder(order, 'delivered', lane: readyLane);
    }
    await _refresh(silent: true);
    return true;
  }

  Future<void> _loadPersistedReadyTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_readyTimesKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((key, value) {
        final id = int.tryParse(key);
        final dt = DateTime.tryParse('$value');
        if (id != null && dt != null) {
          _readyOrderEntryTimes[id] = dt;
        }
      });
    } catch (_) {}
  }

  Future<void> _persistReadyOrderTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    _readyOrderEntryTimes.forEach((id, dt) {
      map['$id'] = dt.toIso8601String();
    });
    await prefs.setString(_readyTimesKey, jsonEncode(map));
  }

  Future<void> setKitchenFilter(int? kitchenId) async {
    selectedKitchenId = kitchenId;
    final session = _session;
    if (session != null) {
      await _persistKitchenFilter(session.branchId, kitchenId);
    }
    notifyListeners();
    await _refresh(silent: false);
  }

  void _rebuildLanes() {
    lanes = bucketBoardToLanes(
      board,
      bootstrap?.queueRequired ?? false,
      sort: selectedSort,
    );
  }

  void setTicketSort(KitchenTicketSort sort) {
    if (selectedSort == sort) return;
    selectedSort = sort;
    _rebuildLanes();
    notifyListeners();
  }

  void setChannelFilter(String? channel) {
    final next = (channel == null || channel.isEmpty) ? null : channel;
    if (selectedChannel == next) return;
    selectedChannel = next;
    notifyListeners();
  }

  List<KitchenBoardOrder> get allActiveOrders => [
    ...board.pending,
    ...board.confirmed,
    ...board.preparing,
    ...board.ready,
  ];

  Future<void> advanceOrder(
    KitchenBoardOrder order,
    String nextStatus, {
    required KitchenLane lane,
  }) async {
    final session = _session;
    final token = _kitchenToken;
    if (session == null || token == null) return;

    final cascadedItems = order.items.map((item) {
      if (nextStatus == 'ready' ||
          nextStatus == 'delivered' ||
          nextStatus == 'cancelled') {
        return item.copyWith(kitchenStatus: nextStatus);
      }
      if (item.isReady || item.isDelivered || item.isLocked) {
        return item;
      }
      return item.copyWith(kitchenStatus: nextStatus);
    }).toList();

    board = relocateKitchenOrder(
      board,
      order,
      nextStatus,
      items: cascadedItems,
    );
    _rebuildLanes();
    notifyListeners();

    try {
      if (order.kitchenTicketId > 0) {
        await _api.updateKitchenTicketStatus(
          session: session,
          kitchenToken: token,
          ticketId: order.kitchenTicketId,
          status: nextStatus,
        );
      }
    } catch (_) {
      await _refresh(silent: true);
    }
  }

  Future<void> toggleItemReady(
    KitchenBoardOrder order,
    KitchenBoardItem item, {
    String? status,
  }) async {
    final session = _session;
    final token = _kitchenToken;
    if (session == null || token == null) return;
    if (item.id <= 0 || item.isLocked) return;

    final nextStatus = status ?? nextKitchenItemStatus(item.kitchenStatus);
    if (nextStatus == (item.kitchenStatus ?? 'pending')) return;
    board = applyKitchenItemStatus(board, order, item, nextStatus);
    _rebuildLanes();
    notifyListeners();

    try {
      await _api.updateKitchenItemStatus(
        session: session,
        kitchenToken: token,
        itemId: item.id,
        status: nextStatus,
      );
    } catch (_) {
      await _refresh(silent: true);
    }
  }

  Future<void> bumpPriority(KitchenBoardOrder order) async {
    final session = _session;
    final token = _kitchenToken;
    if (session == null || token == null) return;

    try {
      await _api.bumpKitchenPriority(
        session: session,
        kitchenToken: token,
        orderId: order.id,
      );
      await _refresh(silent: true);
    } catch (_) {
      // Poll will reconcile.
    }
  }

  static String _filterKey(int branchId) =>
      'serve_pos_kitchen_filter_$branchId';

  static Future<int?> _readStoredKitchenFilter(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_filterKey(branchId));
    if (raw == null || raw == 'all') return null;
    return int.tryParse(raw);
  }

  static Future<void> _persistKitchenFilter(
    int branchId,
    int? kitchenId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (kitchenId == null) {
      await prefs.setString(_filterKey(branchId), 'all');
    } else {
      await prefs.setString(_filterKey(branchId), '$kitchenId');
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
