import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../providers/pos_controller.dart';
import '../../services/pos_api.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_appearance_picker.dart';
import '../../utils/format.dart';
import '../../utils/json_parse.dart';
import '../../utils/pos_table_layout.dart';
import '../../utils/waiter_table_status.dart';
import '../../widgets/offline_status_indicator.dart';
import '../../widgets/pos_table_tile.dart';
import '../../widgets/pos_ui.dart';
import 'bill_preview_sheet.dart';
import 'open_table_sheet.dart';
import 'table_actions_sheet.dart';

class WaiterTablesScreen extends StatefulWidget {
  const WaiterTablesScreen({super.key, required this.onOpenOrder});

  final VoidCallback onOpenOrder;

  @override
  State<WaiterTablesScreen> createState() => _WaiterTablesScreenState();
}

class _WaiterTablesScreenState extends State<WaiterTablesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  WaiterTableStatus? _statusFilter;
  Object? _zoneFilter; // null = all, 'none' = other, int/string area id
  bool _mineOnly = false;
  bool _openingFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosController>().refreshWaiterFloor();
      _consumeNotificationFocus();
    });
  }

  void _consumeNotificationFocus() {
    if (!mounted || _openingFocus) return;
    final pos = context.read<PosController>();
    if (pos.waiterFocusTableId == null) return;
    final focusId = pos.takeWaiterFocusTableId();
    if (focusId == null) return;
    Map<String, dynamic>? table;
    for (final t in pos.waiterTables) {
      if (parseJsonIntOrNull(t['id']) == focusId) {
        table = t;
        break;
      }
    }
    if (table == null) return;
    _openingFocus = true;
    unawaited(() async {
      try {
        await _onTableTap(table!);
      } finally {
        _openingFocus = false;
      }
    }());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _statusFilter != null ||
      _zoneFilter != null ||
      _mineOnly;

  void _clearFilters() {
    setState(() {
      _query = '';
      _statusFilter = null;
      _zoneFilter = null;
      _mineOnly = false;
      _searchController.clear();
    });
  }

  Set<int> _myTableIds(PosController pos) {
    final userId = pos.profile?.user.id ?? pos.session?.userId;
    if (userId == null) return {};
    final ids = <int>{};
    for (final order in pos.waiterRecentOrders) {
      if (parseJsonIntOrNull(order['user_id']) != userId) continue;
      final status = '${order['status']}'.toLowerCase();
      if (status == 'cancelled' ||
          status == 'abandoned' ||
          status == 'delivered') {
        continue;
      }
      if ('${order['payment_status']}'.toLowerCase() == 'paid') continue;
      final tableId = parseJsonIntOrNull(order['table_id']);
      if (tableId != null) ids.add(tableId);
    }
    return ids;
  }

  WaiterTableStatus _statusOf(
    Map<String, dynamic> table,
    Set<int> billRequested,
  ) {
    final id = parseJsonIntOrNull(table['id']);
    return parseWaiterTableStatus(
      table['status']?.toString(),
      billRequested: id != null && billRequested.contains(id),
    );
  }

  List<Map<String, dynamic>> _filteredTables(
    List<Map<String, dynamic>> tables,
    Set<int> billRequested, {
    Set<int> myTableIds = const {},
  }) {
    final q = _query.trim().toLowerCase();
    return tables.where((table) {
      final status = _statusOf(table, billRequested);
      if (_statusFilter != null && status != _statusFilter) return false;

      if (_mineOnly) {
        final id = parseJsonIntOrNull(table['id']);
        if (id == null || !myTableIds.contains(id)) return false;
      }

      if (_zoneFilter != null) {
        final areaId = table['table_area_id'];
        if (_zoneFilter == 'none') {
          if (areaId != null && '$areaId'.isNotEmpty) return false;
        } else if ('$areaId' != '$_zoneFilter') {
          return false;
        }
      }

      if (q.isNotEmpty) {
        final name = table['name']?.toString().toLowerCase() ?? '';
        if (!name.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Map<WaiterTableStatus, int> _statusCounts(
    List<Map<String, dynamic>> tables,
    Set<int> billRequested,
  ) {
    final counts = <WaiterTableStatus, int>{
      for (final s in WaiterTableStatus.values) s: 0,
    };
    for (final table in tables) {
      final status = _statusOf(table, billRequested);
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  Set<int> _openTicketTableIds(PosController pos) {
    const closed = {'delivered', 'cancelled', 'abandoned'};
    final ids = <int>{};

    // Active floor / captain tickets only (not delivered / paid).
    for (final order in pos.waiterRecentOrders) {
      final status = '${order['status']}'.toLowerCase();
      if (closed.contains(status)) continue;
      if ('${order['payment_status']}'.toLowerCase() == 'paid') continue;
      final id = parseJsonIntOrNull(order['table_id']);
      if (id != null) ids.add(id);
    }

    // Register held drafts still open on a table.
    for (final order in pos.waiterHeldOrders) {
      final status = '${order['status']}'.toLowerCase();
      if (status.isNotEmpty && status != 'draft') continue;
      final id = parseJsonIntOrNull(order['table_id']);
      if (id != null) ids.add(id);
    }

    // Never badge available/cleaning tables (stale drafts after deliver).
    for (final table in pos.waiterTables) {
      final id = parseJsonIntOrNull(table['id']);
      if (id == null || !ids.contains(id)) continue;
      final status = parseWaiterTableStatus(table['status']?.toString());
      if (status == WaiterTableStatus.available ||
          status == WaiterTableStatus.cleaning) {
        ids.remove(id);
      }
    }

    return ids;
  }

  String _actionHint(AppLocalizations l10n, WaiterTableStatus status) {
    return switch (status) {
      WaiterTableStatus.available || WaiterTableStatus.reserved =>
        l10n.waiterActionSeat,
      WaiterTableStatus.occupied => l10n.waiterActionOrder,
      WaiterTableStatus.billing => l10n.waiterActionBill,
      WaiterTableStatus.cleaning => l10n.waiterActionClean,
    };
  }

  Future<void> _seatGuestsOnTable({
    required int tableId,
    required String tableName,
  }) async {
    final pos = context.read<PosController>();
    final result = await showOpenTableSheet(
      context,
      tableName: tableName,
      initialGuests: 2,
    );
    if (!mounted || result == null) return;
    if (pos.cart.isNotEmpty && pos.tableId != tableId) {
      pos.clearCart();
    }
    pos.startWaiterTableSession(tableId: tableId, guests: result.guests);
    // Mark occupied immediately so the floor shows “No order” until a ticket exists.
    try {
      await pos.updateWaiterTableStatus(tableId: tableId, status: 'occupied');
    } catch (_) {
      // Session still opens; floor status will catch up on next refresh / order send.
    }
    if (!mounted) return;
    widget.onOpenOrder();
  }

  Future<void> _onTableTap(Map<String, dynamic> table) async {
    final pos = context.read<PosController>();
    final l10n = context.l10n;
    final id = parseJsonIntOrNull(table['id']);
    if (id == null) return;

    final name = table['name']?.toString() ?? l10n.cartTableNamed('$id');
    final status = _statusOf(table, pos.billRequestedTableIds);

    final order = pos.activeOrderForTable(id);
    final action = await showTableActionsSheet(
      context,
      tableName: name,
      status: status,
      order: order,
      currency: pos.currency,
      seatCapacity: parseJsonIntOrNull(table['capacity']),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case WaiterTableAction.seatGuests:
        await _seatGuestsOnTable(tableId: id, tableName: name);
        return;
      case WaiterTableAction.addMore:
        await _openOrderForTable(id, order);
        return;
      case WaiterTableAction.viewBill:
        await showBillPreviewSheet(
          context,
          tableId: id,
          tableName: name,
          order: order,
        );
        return;
      case WaiterTableAction.clearBillRequest:
        try {
          await pos.clearBillRequest(id);
          if (!mounted) return;
          showPosSnackBar(context, l10n.waiterTableActionClearBillDone);
        } on PosApiException catch (e) {
          if (!mounted) return;
          showPosErrorSnackBar(context, e);
        } catch (e) {
          if (!mounted) return;
          showPosErrorSnackBar(context, e);
        }
        return;
      case WaiterTableAction.markCleaning:
        await _setTableStatus(
          id,
          'cleaning',
          l10n.waiterTableActionMarkedCleaning,
        );
        return;
      case WaiterTableAction.markAvailable:
        await _setTableStatus(
          id,
          'available',
          l10n.waiterTableActionMarkedAvailable,
        );
        return;
      case WaiterTableAction.markReserved:
        await _setTableStatus(
          id,
          'reserved',
          l10n.waiterTableActionMarkedReserved,
        );
        return;
    }
  }

  Future<void> _setTableStatus(int tableId, String status, String toast) async {
    final pos = context.read<PosController>();
    try {
      await pos.updateWaiterTableStatus(tableId: tableId, status: status);
      if (!mounted) return;
      showPosSnackBar(context, toast);
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _openOrderForTable(
    int id,
    Map<String, dynamic>? active,
  ) async {
    final pos = context.read<PosController>();
    try {
      if (active != null) {
        final orderId = parseJsonIntOrNull(active['id']);
        final localUuid = active['local_uuid']?.toString();
        await pos.beginWaiterAppendSession(
          orderId: orderId,
          localUuid: localUuid,
          fallbackTableId: id,
          guests: pos.waiterGuestCount ?? 2,
        );
      } else {
        if (pos.cart.isNotEmpty && pos.tableId != id) {
          pos.clearCart();
        }
        pos.startWaiterTableSession(
          tableId: id,
          guests: pos.waiterGuestCount ?? 2,
        );
      }
      if (!mounted) return;
      widget.onOpenOrder();
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    PosTheme.bind(context);
    final pos = context.watch<PosController>();
    if (pos.waiterFocusTableId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _consumeNotificationFocus();
      });
    }
    final accent = Theme.of(context).colorScheme.primary;
    final areas = pos.waiterTableAreas;
    final allTables = pos.waiterTables;
    final billRequested = pos.billRequestedTableIds;
    final openTickets = _openTicketTableIds(pos);
    final myTableIds = _myTableIds(pos);
    final counts = _statusCounts(allTables, billRequested);
    final filtered = _filteredTables(
      allTables,
      billRequested,
      myTableIds: myTableIds,
    );
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = posTableFloorMaxWidth(width);
    final horizontalPad = width >= 800 ? 24.0 : 16.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad, 10, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.waiterNavTables,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          l10n.waiterTablesSummary(allTables.length),
                          if (_hasActiveFilters)
                            l10n.waiterTablesShowing(filtered.length),
                          pos.isOnline
                              ? l10n.waiterConnectionLive
                              : l10n.waiterConnectionOffline,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: PosTheme.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                const OfflineStatusIndicator(),
                PosAppBarThemeButton(accent: accent),
                if (_hasActiveFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: Text(l10n.waiterClearFilters),
                  ),
                IconButton(
                  tooltip: l10n.commonRefresh,
                  onPressed: pos.waiterRefreshing
                      ? null
                      : () => pos.refreshWaiterFloor(),
                  icon: pos.waiterRefreshing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.waiterSearchTables,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.commonClear,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: PosTheme.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              children: [
                _StatusFilterChip(
                  label: l10n.waiterFilterAll,
                  count: allTables.length,
                  selected: _statusFilter == null && !_mineOnly,
                  color: accent,
                  onTap: () => setState(() {
                    _statusFilter = null;
                    _mineOnly = false;
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _StatusFilterChip(
                    label: l10n.waiterFilterMyTables,
                    count: myTableIds.length,
                    selected: _mineOnly,
                    color: PosTheme.accent,
                    onTap: () => setState(() {
                      _mineOnly = !_mineOnly;
                      if (_mineOnly) _statusFilter = null;
                    }),
                  ),
                ),
                for (final status in const [
                  WaiterTableStatus.available,
                  WaiterTableStatus.occupied,
                  WaiterTableStatus.billing,
                  WaiterTableStatus.reserved,
                  WaiterTableStatus.cleaning,
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _StatusFilterChip(
                      label: _statusLabel(l10n, status),
                      count: counts[status] ?? 0,
                      selected: !_mineOnly && _statusFilter == status,
                      color: waiterTableStatusStyle(status, isDark: isDark).dot,
                      onTap: () => setState(() {
                        _mineOnly = false;
                        _statusFilter =
                            _statusFilter == status ? null : status;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          if (areas.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                children: [
                  _ZoneFilterChip(
                    label: l10n.waiterFilterZones,
                    selected: _zoneFilter == null,
                    onTap: () => setState(() => _zoneFilter = null),
                  ),
                  for (final area in areas)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _ZoneFilterChip(
                        label: area['name']?.toString() ?? l10n.waiterZoneAll,
                        selected: '$_zoneFilter' == '${area['id']}',
                        onTap: () => setState(() {
                          final id = area['id'];
                          _zoneFilter =
                              '$_zoneFilter' == '$id' ? null : id;
                        }),
                      ),
                    ),
                  if (pos.waiterTablesWithoutArea.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _ZoneFilterChip(
                        label: l10n.waiterZoneOther,
                        selected: _zoneFilter == 'none',
                        onTap: () => setState(() {
                          _zoneFilter =
                              _zoneFilter == 'none' ? null : 'none';
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => pos.refreshWaiterFloor(),
              child: allTables.isEmpty && !pos.waiterRefreshing
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        PosEmptyState(
                          icon: Icons.table_restaurant_outlined,
                          title: l10n.cartNoTablesTitle,
                          subtitle: l10n.cartNoTablesSubtitle,
                          accent: accent,
                        ),
                      ],
                    )
                  : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 72),
                            PosEmptyState(
                              icon: Icons.filter_alt_off_rounded,
                              title: l10n.waiterNoFilterMatchesTitle,
                              subtitle: l10n.waiterNoFilterMatchesSubtitle,
                              accent: accent,
                              action: TextButton(
                                onPressed: _clearFilters,
                                child: Text(l10n.waiterClearFilters),
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxWidth ?? double.infinity,
                            ),
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPad,
                                4,
                                horizontalPad,
                                24,
                              ),
                              children: _buildZoneSections(
                                l10n: l10n,
                                areas: areas,
                                filtered: filtered,
                                billRequested: billRequested,
                                openTickets: openTickets,
                              ),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildZoneSections({
    required AppLocalizations l10n,
    required List<Map<String, dynamic>> areas,
    required List<Map<String, dynamic>> filtered,
    required Set<int> billRequested,
    required Set<int> openTickets,
  }) {
    // When a single zone is selected, flatten into one section.
    if (_zoneFilter != null || areas.isEmpty) {
      final title = _zoneFilter == null
          ? l10n.waiterZoneAll
          : _zoneFilter == 'none'
              ? l10n.waiterZoneOther
              : areas
                      .where((a) => '${a['id']}' == '$_zoneFilter')
                      .map((a) => a['name']?.toString())
                      .firstOrNull ??
                  l10n.waiterZoneAll;
      return [
        _ZoneBlock(
          title: title,
          tables: filtered,
          billRequested: billRequested,
          openTickets: openTickets,
          actionHintForStatus: (s) => _actionHint(l10n, s),
          floorInfoForTable: (table) => _floorInfoForTable(
            context.read<PosController>(),
            l10n,
            table,
          ),
          onTap: _onTableTap,
        ),
      ];
    }

    final sections = <Widget>[];
    final pos = context.read<PosController>();
    for (final area in areas) {
      final areaTables = filtered
          .where((t) => '${t['table_area_id']}' == '${area['id']}')
          .toList();
      if (areaTables.isEmpty) continue;
      sections.add(
        _ZoneBlock(
          title: area['name']?.toString() ?? l10n.waiterZoneAll,
          tables: areaTables,
          billRequested: billRequested,
          openTickets: openTickets,
          actionHintForStatus: (s) => _actionHint(l10n, s),
          floorInfoForTable: (table) => _floorInfoForTable(pos, l10n, table),
          onTap: _onTableTap,
        ),
      );
    }
    final other = filtered.where((t) {
      final areaId = t['table_area_id'];
      return areaId == null || '$areaId'.isEmpty;
    }).toList();
    if (other.isNotEmpty) {
      sections.add(
        _ZoneBlock(
          title: l10n.waiterZoneOther,
          tables: other,
          billRequested: billRequested,
          openTickets: openTickets,
          actionHintForStatus: (s) => _actionHint(l10n, s),
          floorInfoForTable: (table) => _floorInfoForTable(pos, l10n, table),
          onTap: _onTableTap,
        ),
      );
    }
    return sections;
  }

  String _statusLabel(AppLocalizations l10n, WaiterTableStatus status) {
    return switch (status) {
      WaiterTableStatus.available => l10n.waiterStatusAvailable,
      WaiterTableStatus.occupied => l10n.waiterStatusOccupied,
      WaiterTableStatus.billing => l10n.waiterStatusBilling,
      WaiterTableStatus.reserved => l10n.waiterStatusReserved,
      WaiterTableStatus.cleaning => l10n.waiterStatusCleaning,
    };
  }

  PosTableFloorInfo? _floorInfoForTable(
    PosController pos,
    AppLocalizations l10n,
    Map<String, dynamic> table,
  ) {
    final tableId = parseJsonIntOrNull(table['id']);
    final seats = parseJsonIntOrNull(table['capacity']);
    final order = tableId == null ? null : pos.activeOrderForTable(tableId);

    if (order == null) {
      if (seats == null) return null;
      return PosTableFloorInfo(seats: seats);
    }

    final amountDue = parseJsonDouble(order['amount_due'] ?? order['total']);
    final seated = _seatedLabel(order['created_at']?.toString(), l10n);

    return PosTableFloorInfo(
      seats: seats,
      billLabel: amountDue > 0 ? formatMoney(amountDue, pos.currency) : null,
      seatedLabel: seated.isEmpty ? null : seated,
    );
  }
}

String _seatedLabel(String? iso, AppLocalizations l10n) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 45) return l10n.timeJustNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  return l10n.timeDaysAgo(diff.inDays);
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : PosTheme.ink;
    final bg = selected ? color : PosTheme.surface;
    final border = selected ? color : PosTheme.border;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!selected) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : PosTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: selected ? Colors.white : PosTheme.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneFilterChip extends StatelessWidget {
  const _ZoneFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    return Material(
      color: selected ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? soft.fg.withValues(alpha: PosTheme.isDark ? 0.4 : 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: selected ? soft.fg : PosTheme.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoneBlock extends StatelessWidget {
  const _ZoneBlock({
    required this.title,
    required this.tables,
    required this.billRequested,
    required this.openTickets,
    required this.actionHintForStatus,
    required this.floorInfoForTable,
    required this.onTap,
  });

  final String title;
  final List<Map<String, dynamic>> tables;
  final Set<int> billRequested;
  final Set<int> openTickets;
  final String Function(WaiterTableStatus status) actionHintForStatus;
  final PosTableFloorInfo? Function(Map<String, dynamic> table)
      floorInfoForTable;
  final Future<void> Function(Map<String, dynamic> table) onTap;

  @override
  Widget build(BuildContext context) {
    if (tables.isEmpty) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.05,
                      fontSize: 11.5,
                      color: PosTheme.inkFaint,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: PosTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${tables.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PosTheme.inkMuted,
                  ),
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Container(height: 1, color: PosTheme.border),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          PosTableGrid(
            tables: tables,
            billRequestedIds: billRequested,
            openTicketTableIds: openTickets,
            orderAware: true,
            floorInfoForTable: floorInfoForTable,
            actionHintForStatus: actionHintForStatus,
            onTableTap: (table) => onTap(table),
          ),
        ],
      ),
    );
  }
}
