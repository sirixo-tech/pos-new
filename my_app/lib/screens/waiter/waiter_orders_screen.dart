import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../providers/pos_controller.dart';
import '../../services/pos_api.dart';
import '../../theme/pos_theme.dart';
import '../../utils/format.dart';
import '../../utils/json_parse.dart';
import '../../utils/waiter_table_status.dart';
import '../../widgets/pos_appearance_picker.dart';
import '../../widgets/pos_ui.dart';
import 'bill_preview_sheet.dart';

enum _OrdersFilter { all, preparing, ready, billing, mine }

class WaiterOrdersScreen extends StatefulWidget {
  const WaiterOrdersScreen({super.key, required this.onAddMore});

  final VoidCallback onAddMore;

  @override
  State<WaiterOrdersScreen> createState() => _WaiterOrdersScreenState();
}

class _WaiterOrdersScreenState extends State<WaiterOrdersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _OrdersFilter _filter = _OrdersFilter.all;
  final Set<int> _expandedOrderIds = {};
  /// Orders the captain collapsed while food was still ready.
  final Set<int> _collapsedWhileReady = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosController>().refreshWaiterFloor();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addMore(Map<String, dynamic> order) async {
    final pos = context.read<PosController>();
    final orderId = parseJsonIntOrNull(order['id']);
    final localUuid = order['local_uuid']?.toString();
    final tableId = parseJsonIntOrNull(order['table_id']);
    final status = '${order['status']}';
    final canAppend = (localUuid != null && localUuid.isNotEmpty) ||
        (orderId != null &&
            const {
              'draft',
              'pending',
              'confirmed',
              'preparing',
              'ready',
            }.contains(status));
    try {
      if (canAppend) {
        await pos.beginWaiterAppendSession(
          orderId: orderId,
          localUuid: localUuid,
          fallbackTableId: tableId,
        );
      } else if (tableId != null) {
        pos.startWaiterTableSession(tableId: tableId);
      }
      if (!mounted) return;
      widget.onAddMore();
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _clearBill(Map<String, dynamic> order) async {
    final pos = context.read<PosController>();
    final l10n = context.l10n;
    final tableId = parseJsonIntOrNull(order['table_id']);
    if (tableId == null) return;
    try {
      await pos.clearBillRequest(tableId);
      if (!mounted) return;
      showPosSnackBar(context, l10n.waiterTableActionClearBillDone);
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _markServed(
    Map<String, dynamic> order, {
    int? kitchenTicketId,
  }) async {
    final pos = context.read<PosController>();
    final l10n = context.l10n;
    final orderId = parseJsonIntOrNull(order['id']);
    if (orderId == null) return;
    try {
      final marked = await pos.markWaiterServed(
        orderId: orderId,
        kitchenTicketId: kitchenTicketId,
      );
      if (!mounted) return;
      showPosSnackBar(
        context,
        marked > 1
            ? l10n.waiterMarkServedDoneCount(marked)
            : l10n.waiterMarkServedDone,
      );
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  List<Map<String, dynamic>> _sortedOrders(List<Map<String, dynamic>> source) {
    final orders = [...source]
      ..sort((a, b) {
        final aBill = a['bill_requested'] == true;
        final bBill = b['bill_requested'] == true;
        if (aBill != bBill) return aBill ? -1 : 1;

        final aCounts = _pipelineCounts(a);
        final bCounts = _pipelineCounts(b);
        if (aCounts.ready != bCounts.ready) {
          return bCounts.ready.compareTo(aCounts.ready);
        }
        if (aCounts.prep != bCounts.prep) {
          return bCounts.prep.compareTo(aCounts.prep);
        }

        final at = a['created_at']?.toString() ?? '';
        final bt = b['created_at']?.toString() ?? '';
        return bt.compareTo(at);
      });
    return orders;
  }

  _PipelineCounts _pipelineCounts(Map<String, dynamic> order) {
    final items = (order['items'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final tickets = (order['kitchen_tickets'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];

    if (items.isEmpty && tickets.isEmpty) {
      final pipeline = mapOrderStatusToPipeline(order['status']?.toString());
      return switch (pipeline) {
        WaiterLinePipeline.ready => const _PipelineCounts(ready: 1),
        WaiterLinePipeline.preparing => const _PipelineCounts(prep: 1),
        WaiterLinePipeline.served => const _PipelineCounts(served: 1),
        WaiterLinePipeline.sent => const _PipelineCounts(sent: 1),
      };
    }

    var sent = 0;
    var prep = 0;
    var ready = 0;
    var served = 0;

    if (items.isNotEmpty) {
      for (final item in items) {
        final qty = parseJsonInt(item['quantity'], fallback: 1);
        final raw = item['kitchen_status']?.toString();
        final status = (raw != null && raw.trim().isNotEmpty)
            ? raw
            : (item['kitchen_ticket_id'] != null
                ? order['status']?.toString()
                : null);
        switch (mapOrderStatusToPipeline(status)) {
          case WaiterLinePipeline.ready:
            ready += qty;
          case WaiterLinePipeline.preparing:
            prep += qty;
          case WaiterLinePipeline.served:
            served += qty;
          case WaiterLinePipeline.sent:
            sent += qty;
        }
      }
    } else {
      for (final ticket in tickets) {
        switch (mapOrderStatusToPipeline(ticket['status']?.toString())) {
          case WaiterLinePipeline.ready:
            ready += 1;
          case WaiterLinePipeline.preparing:
            prep += 1;
          case WaiterLinePipeline.served:
            served += 1;
          case WaiterLinePipeline.sent:
            sent += 1;
        }
      }
    }

    // Ticket-level ready can outpace stale/missing line kitchen_status.
    if (ready == 0 && tickets.isNotEmpty) {
      final ticketReady = tickets
          .where(
            (t) =>
                mapOrderStatusToPipeline(t['status']?.toString()) ==
                WaiterLinePipeline.ready,
          )
          .length;
      if (ticketReady > 0) {
        ready = ticketReady;
      }
    }

    return _PipelineCounts(sent: sent, prep: prep, ready: ready, served: served);
  }

  bool _isExpanded(int? orderId, _PipelineCounts counts) {
    if (orderId == null) return false;
    if (counts.ready > 0) {
      return !_collapsedWhileReady.contains(orderId);
    }
    return _expandedOrderIds.contains(orderId);
  }

  void _toggleExpanded(int orderId, _PipelineCounts counts) {
    setState(() {
      if (counts.ready > 0) {
        if (_collapsedWhileReady.contains(orderId)) {
          _collapsedWhileReady.remove(orderId);
        } else {
          _collapsedWhileReady.add(orderId);
        }
        return;
      }
      if (_expandedOrderIds.contains(orderId)) {
        _expandedOrderIds.remove(orderId);
      } else {
        _expandedOrderIds.add(orderId);
      }
    });
  }

  List<Map<String, dynamic>> _filteredOrders(
    List<Map<String, dynamic>> orders,
    int? myUserId,
  ) {
    final q = _query.trim().toLowerCase();
    return orders.where((order) {
      final counts = _pipelineCounts(order);
      if (_filter == _OrdersFilter.billing && order['bill_requested'] != true) {
        return false;
      }
      if (_filter == _OrdersFilter.ready && counts.ready <= 0) {
        return false;
      }
      if (_filter == _OrdersFilter.preparing && counts.prep <= 0) {
        return false;
      }
      if (_filter == _OrdersFilter.mine) {
        final ownerId = parseJsonIntOrNull(order['user_id']);
        if (myUserId == null || ownerId != myUserId) return false;
      }
      if (q.isEmpty) return true;

      final table = order['table_name']?.toString().toLowerCase() ?? '';
      final number = order['order_number']?.toString().toLowerCase() ?? '';
      final token = order['token']?.toString().toLowerCase() ?? '';
      final captain = order['captain_name']?.toString().toLowerCase() ?? '';
      return table.contains(q) ||
          number.contains(q) ||
          token.contains(q) ||
          captain.contains(q);
    }).toList();
  }

  Map<_OrdersFilter, int> _filterCounts(
    List<Map<String, dynamic>> orders,
    int? myUserId,
  ) {
    return {
      _OrdersFilter.all: orders.length,
      _OrdersFilter.preparing:
          orders.where((o) => _pipelineCounts(o).prep > 0).length,
      _OrdersFilter.ready:
          orders.where((o) => _pipelineCounts(o).ready > 0).length,
      _OrdersFilter.billing:
          orders.where((o) => o['bill_requested'] == true).length,
      _OrdersFilter.mine: orders.where((o) {
        final ownerId = parseJsonIntOrNull(o['user_id']);
        return myUserId != null && ownerId == myUserId;
      }).length,
    };
  }

  void _setFilter(_OrdersFilter next) {
    setState(() {
      _filter = _filter == next && next != _OrdersFilter.all
          ? _OrdersFilter.all
          : next;
    });
  }

  void _clearFilters() {
    setState(() {
      _filter = _OrdersFilter.all;
      _query = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final currency = pos.currency;
    final accent = Theme.of(context).colorScheme.primary;
    final myUserId = pos.profile?.user.id;
    final allOrders = _sortedOrders(pos.waiterRecentOrders);
    final counts = _filterCounts(allOrders, myUserId);
    final orders = _filteredOrders(allOrders, myUserId);
    final hasFilters =
        _filter != _OrdersFilter.all || _query.trim().isNotEmpty;
    final readyCount = counts[_OrdersFilter.ready] ?? 0;
    final billingCount = counts[_OrdersFilter.billing] ?? 0;
    final mineCount = counts[_OrdersFilter.mine] ?? 0;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.waiterNavOrders,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        allOrders.isEmpty
                            ? l10n.waiterOrdersSubtitle
                            : l10n.waiterOrdersSummary(allOrders.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PosTheme.inkMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                PosAppBarThemeButton(accent: accent),
                if (pos.waiterRefreshing)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  tooltip: l10n.commonRefresh,
                  onPressed: () => pos.refreshWaiterFloor(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          if (allOrders.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: _UrgencySummary(
                readyLabel: l10n.waiterOrdersSummaryReady(readyCount),
                billingLabel: l10n.waiterOrdersSummaryBilling(billingCount),
                mineLabel: l10n.waiterOrdersSummaryMine(mineCount),
                readySelected: _filter == _OrdersFilter.ready,
                billingSelected: _filter == _OrdersFilter.billing,
                mineSelected: _filter == _OrdersFilter.mine,
                onReady: () => _setFilter(_OrdersFilter.ready),
                onBilling: () => _setFilter(_OrdersFilter.billing),
                onMine: () => _setFilter(_OrdersFilter.mine),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.waiterOrdersSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.waiterClearFilters,
                          onPressed: () {
                            setState(() {
                              _query = '';
                              _searchController.clear();
                            });
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: PosTheme.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: PosTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: PosTheme.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: l10n.waiterOrdersFilterAll,
                    count: counts[_OrdersFilter.all] ?? 0,
                    selected: _filter == _OrdersFilter.all,
                    color: accent,
                    onTap: () => setState(() => _filter = _OrdersFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.waiterOrdersFilterPreparing,
                    count: counts[_OrdersFilter.preparing] ?? 0,
                    selected: _filter == _OrdersFilter.preparing,
                    color: const Color(0xFFD97706),
                    onTap: () => _setFilter(_OrdersFilter.preparing),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.waiterOrdersFilterReady,
                    count: counts[_OrdersFilter.ready] ?? 0,
                    selected: _filter == _OrdersFilter.ready,
                    color: const Color(0xFF059669),
                    onTap: () => _setFilter(_OrdersFilter.ready),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.waiterOrdersFilterBilling,
                    count: counts[_OrdersFilter.billing] ?? 0,
                    selected: _filter == _OrdersFilter.billing,
                    color: const Color(0xFFD97706),
                    onTap: () => _setFilter(_OrdersFilter.billing),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.waiterOrdersFilterMine,
                    count: counts[_OrdersFilter.mine] ?? 0,
                    selected: _filter == _OrdersFilter.mine,
                    color: PosTheme.accent,
                    onTap: () => _setFilter(_OrdersFilter.mine),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => pos.refreshWaiterFloor(),
              child: allOrders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        PosEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: l10n.waiterOrdersEmptyTitle,
                          subtitle: l10n.waiterOrdersEmptySubtitle,
                          accent: accent,
                        ),
                      ],
                    )
                  : orders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 72),
                            PosEmptyState(
                              icon: Icons.filter_alt_off_rounded,
                              title: l10n.waiterOrdersNoFilterMatchesTitle,
                              subtitle:
                                  l10n.waiterOrdersNoFilterMatchesSubtitle,
                              accent: accent,
                              action: hasFilters
                                  ? TextButton(
                                      onPressed: _clearFilters,
                                      child: Text(l10n.waiterClearFilters),
                                    )
                                  : null,
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: orders.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            final orderId = parseJsonIntOrNull(order['id']);
                            final counts = _pipelineCounts(order);
                            final expanded = _isExpanded(orderId, counts);
                            return _OrderCard(
                              order: order,
                              currency: currency,
                              counts: counts,
                              expanded: expanded,
                              onToggleItems: orderId == null
                                  ? null
                                  : () => _toggleExpanded(orderId, counts),
                              onAddMore: () => _addMore(order),
                              onMarkServed: () => _markServed(order),
                              onMarkTicketServed: (ticketId) => _markServed(
                                order,
                                kitchenTicketId: ticketId,
                              ),
                              onBill: () {
                                final tableId =
                                    parseJsonIntOrNull(order['table_id']);
                                if (tableId == null) return;
                                final tableName =
                                    order['table_name']?.toString() ??
                                        l10n.cartTableNamed('$tableId');
                                showBillPreviewSheet(
                                  context,
                                  tableId: tableId,
                                  tableName: tableName,
                                  order: order,
                                );
                              },
                              onClearBill: order['bill_requested'] == true
                                  ? () => _clearBill(order)
                                  : null,
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineCounts {
  const _PipelineCounts({
    this.sent = 0,
    this.prep = 0,
    this.ready = 0,
    this.served = 0,
  });

  final int sent;
  final int prep;
  final int ready;
  final int served;
}

class _UrgencySummary extends StatelessWidget {
  const _UrgencySummary({
    required this.readyLabel,
    required this.billingLabel,
    required this.mineLabel,
    required this.readySelected,
    required this.billingSelected,
    required this.mineSelected,
    required this.onReady,
    required this.onBilling,
    required this.onMine,
  });

  final String readyLabel;
  final String billingLabel;
  final String mineLabel;
  final bool readySelected;
  final bool billingSelected;
  final bool mineSelected;
  final VoidCallback onReady;
  final VoidCallback onBilling;
  final VoidCallback onMine;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: readyLabel,
            color: const Color(0xFF059669),
            selected: readySelected,
            onTap: onReady,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: billingLabel,
            color: const Color(0xFFD97706),
            selected: billingSelected,
            onTap: onBilling,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: mineLabel,
            color: PosTheme.accent,
            selected: mineSelected,
            onTap: onMine,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(color);
    return Material(
      color: selected ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? soft.fg.withValues(alpha: PosTheme.isDark ? 0.4 : 0.45)
                  : PosTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? soft.fg : color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: selected ? soft.fg : PosTheme.ink,
                    ),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.currency,
    required this.counts,
    required this.expanded,
    required this.onToggleItems,
    required this.onAddMore,
    required this.onMarkServed,
    required this.onMarkTicketServed,
    required this.onBill,
    required this.onClearBill,
  });

  final Map<String, dynamic> order;
  final String currency;
  final _PipelineCounts counts;
  final bool expanded;
  final VoidCallback? onToggleItems;
  final VoidCallback onAddMore;
  final VoidCallback onMarkServed;
  final ValueChanged<int> onMarkTicketServed;
  final VoidCallback onBill;
  final VoidCallback? onClearBill;

  Color get _accent {
    if (order['bill_requested'] == true) return const Color(0xFFD97706);
    if (counts.ready > 0) return const Color(0xFF059669);
    if (counts.prep > 0) return const Color(0xFFD97706);
    if (counts.served > 0 && counts.sent == 0) return PosTheme.accent;
    return const Color(0xFF64748B);
  }

  String _statusLabel(AppLocalizations l10n) {
    if (order['bill_requested'] == true) return l10n.waiterCardBillPending;
    if (counts.ready > 0) return l10n.waiterCardNeedsYou;
    if (counts.prep > 0 || counts.sent > 0) {
      return l10n.waiterCardWaitingKitchen;
    }
    if (counts.served > 0) return l10n.waiterCardDelivered;
    return l10n.waiterCardWaitingKitchen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tableName = order['table_name']?.toString();
    final number = order['order_number']?.toString() ?? '#${order['id']}';
    final token = order['token']?.toString();
    final total = parseJsonDouble(order['amount_due'] ?? order['total']);
    final itemCount = parseJsonInt(order['item_count'], fallback: 0);
    final tableId = parseJsonIntOrNull(order['table_id']);
    final billRequested = order['bill_requested'] == true;
    final captain = (order['captain_name']?.toString() ?? '').trim();
    final lineItems = _captainItemsNewestFirst(
      (order['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[],
    );
    final relative = _relativeTime(order['created_at']?.toString(), l10n);
    final accent = _accent;
    final labels = [
      l10n.waiterPipelineSent,
      l10n.waiterPipelinePreparing,
      l10n.waiterPipelineReady,
      l10n.waiterPipelineServed,
    ];
    final hasReady = counts.ready > 0;
    final title = tableName?.isNotEmpty == true ? tableName! : number;

    final metaParts = <String>[
      number,
      if (token != null && token.isNotEmpty) l10n.waiterOrdersToken(token),
      l10n.waiterItemsCount(itemCount),
      if (relative.isNotEmpty) l10n.waiterCardAge(relative),
      if (captain.isNotEmpty) captain,
    ];

    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasReady || billRequested
                ? accent.withValues(alpha: 0.5)
                : PosTheme.border,
            width: hasReady || billRequested ? 1.5 : 1,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  metaParts.join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: PosTheme.inkMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _StatusPill(
                                label: _statusLabel(l10n),
                                color: accent,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatMoney(total, currency),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CaptainActionBanner(
                        counts: counts,
                        billRequested: billRequested,
                        onMarkServed: onMarkServed,
                      ),
                      if (lineItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              l10n.waiterCardItemsHeading,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: PosTheme.inkMuted,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            if (counts.ready > 0)
                              Text(
                                l10n.waiterOrdersReadyCount(counts.ready),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                ),
                              )
                            else if (counts.prep > 0)
                              Text(
                                l10n.waiterOrdersPrepCount(counts.prep),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (expanded)
                          _KotItemsList(
                            items: lineItems,
                            labels: labels,
                            kotRoundLabel: l10n.waiterKotRound,
                            onMarkTicketServed: onMarkTicketServed,
                            markServedLabel: l10n.waiterRunFoodAction,
                          )
                        else
                          _CollapsedItemsPreview(
                            items: lineItems,
                            labels: labels,
                            onMarkTicketServed: onMarkTicketServed,
                            markServedLabel: l10n.waiterRunFoodAction,
                          ),
                        if (onToggleItems != null) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: onToggleItems,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    expanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 18,
                                    color: PosTheme.inkMuted,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    expanded
                                        ? l10n.waiterCardHideTicket
                                        : l10n.waiterCardShowTicket,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: PosTheme.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onAddMore,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(l10n.waiterAddMore),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: billRequested
                                ? FilledButton.icon(
                                    onPressed:
                                        tableId == null ? null : onBill,
                                    icon: const Icon(
                                      Icons.receipt_long_rounded,
                                      size: 18,
                                    ),
                                    label: Text(l10n.waiterTableActionViewBill),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      backgroundColor:
                                          const Color(0xFFD97706),
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed:
                                        tableId == null ? null : onBill,
                                    icon: const Icon(
                                      Icons.request_quote_outlined,
                                      size: 18,
                                    ),
                                    label: Text(l10n.waiterRequestBill),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      if (onClearBill != null) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: onClearBill,
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: Text(l10n.waiterTableActionClearBill),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ],
                    ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: soft.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: soft.fg.withValues(alpha: PosTheme.isDark ? 0.28 : 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: soft.fg,
        ),
      ),
    );
  }
}

class _CaptainActionBanner extends StatelessWidget {
  const _CaptainActionBanner({
    required this.counts,
    required this.billRequested,
    required this.onMarkServed,
  });

  final _PipelineCounts counts;
  final bool billRequested;
  final VoidCallback onMarkServed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (counts.ready > 0) {
      return Material(
        color: const Color(0xFF059669),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onMarkServed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.room_service_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.waiterRunFoodTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.waiterRunFoodSubtitle(counts.ready),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.waiterRunFoodAction,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (billRequested) {
      return _InfoBanner(
        color: const Color(0xFFD97706),
        icon: Icons.request_quote_outlined,
        title: l10n.waiterCardBillPending,
        subtitle: l10n.waiterBillAlreadyRequestedHint,
      );
    }

    if (counts.prep > 0 || counts.sent > 0) {
      return _InfoBanner(
        color: const Color(0xFFD97706),
        icon: Icons.soup_kitchen_outlined,
        title: l10n.waiterKitchenWorkingTitle,
        subtitle: l10n.waiterKitchenWorkingSubtitle(counts.prep, counts.sent),
        soft: true,
      );
    }

    if (counts.served > 0) {
      return _InfoBanner(
        color: PosTheme.accent,
        icon: Icons.done_all_rounded,
        title: l10n.waiterAllServedTitle,
        subtitle: l10n.waiterAllServedSubtitle,
        soft: true,
      );
    }

    return const SizedBox.shrink();
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.soft = false,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final tones = posAccentSoft(color);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: tones.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tones.fg.withValues(alpha: soft ? 0.22 : 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: soft ? PosTheme.inkMuted : tones.fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: soft ? PosTheme.ink : tones.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: PosTheme.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedItemsPreview extends StatelessWidget {
  const _CollapsedItemsPreview({
    required this.items,
    required this.labels,
    required this.onMarkTicketServed,
    required this.markServedLabel,
  });

  final List<Map<String, dynamic>> items;
  final List<String> labels;
  final ValueChanged<int> onMarkTicketServed;
  final String markServedLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = items.take(3).toList();
    final more = items.length - preview.length;
    final readyHidden = items
        .skip(preview.length)
        .where(
          (item) =>
              mapOrderStatusToPipeline(item['kitchen_status']?.toString()) ==
              WaiterLinePipeline.ready,
        )
        .fold<int>(
          0,
          (sum, item) => sum + parseJsonInt(item['quantity'], fallback: 1),
        );
    final servedTicketIds = <int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in preview)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Builder(
              builder: (context) {
                final pipeline = mapOrderStatusToPipeline(
                  item['kitchen_status']?.toString(),
                );
                final ticketId = parseJsonIntOrNull(item['kitchen_ticket_id']);
                final canServe = pipeline == WaiterLinePipeline.ready &&
                    ticketId != null &&
                    !servedTicketIds.contains(ticketId);
                if (canServe) servedTicketIds.add(ticketId);
                return _TicketLineRow(
                  item: item,
                  pipeline: pipeline,
                  labels: labels,
                  canServe: canServe,
                  markServedLabel: markServedLabel,
                  onMarkServed: canServe
                      ? () => onMarkTicketServed(ticketId)
                      : null,
                );
              },
            ),
          ),
        if (readyHidden > 0)
          Text(
            l10n.waiterCardMoreReady(readyHidden),
            style: const TextStyle(
              color: Color(0xFF059669),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          )
        else if (more > 0)
          Text(
            l10n.waiterOrdersMoreItems(more),
            style: TextStyle(
              color: PosTheme.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _KotItemsList extends StatelessWidget {
  const _KotItemsList({
    required this.items,
    required this.labels,
    required this.kotRoundLabel,
    required this.onMarkTicketServed,
    required this.markServedLabel,
  });

  final List<Map<String, dynamic>> items;
  final List<String> labels;
  final String Function(int round) kotRoundLabel;
  final ValueChanged<int> onMarkTicketServed;
  final String markServedLabel;

  @override
  Widget build(BuildContext context) {
    final sorted = _captainItemsNewestFirst(items);
    final distinctRounds = sorted
        .map((item) => parseJsonInt(item['kot_round'], fallback: 1))
        .toSet();
    final showRoundHeaders = distinctRounds.length > 1 ||
        distinctRounds.any((round) => round > 1);
    final servedTicketIds = <int>{};
    final children = <Widget>[];
    int? lastRound;

    for (final item in sorted) {
      final round = parseJsonInt(item['kot_round'], fallback: 1);
      if (showRoundHeaders && lastRound != round) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: 6,
              top: lastRound == null ? 0 : 8,
            ),
            child: Text(
              kotRoundLabel(round),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: PosTheme.inkMuted,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
        lastRound = round;
      }

      final pipeline = mapOrderStatusToPipeline(
        item['kitchen_status']?.toString(),
      );
      final ticketId = parseJsonIntOrNull(item['kitchen_ticket_id']);
      final canServe = pipeline == WaiterLinePipeline.ready &&
          ticketId != null &&
          !servedTicketIds.contains(ticketId);
      if (canServe) {
        servedTicketIds.add(ticketId);
      }

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _TicketLineRow(
            item: item,
            pipeline: pipeline,
            labels: labels,
            canServe: canServe,
            markServedLabel: markServedLabel,
            onMarkServed:
                canServe ? () => onMarkTicketServed(ticketId) : null,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _TicketLineRow extends StatelessWidget {
  const _TicketLineRow({
    required this.item,
    required this.pipeline,
    required this.labels,
    required this.canServe,
    required this.markServedLabel,
    this.onMarkServed,
  });

  final Map<String, dynamic> item;
  final WaiterLinePipeline pipeline;
  final List<String> labels;
  final bool canServe;
  final String markServedLabel;
  final VoidCallback? onMarkServed;

  Color get _stripe {
    return switch (pipeline) {
      WaiterLinePipeline.ready => const Color(0xFF059669),
      WaiterLinePipeline.preparing => const Color(0xFFD97706),
      WaiterLinePipeline.served => PosTheme.accent,
      WaiterLinePipeline.sent => const Color(0xFF94A3B8),
    };
  }

  @override
  Widget build(BuildContext context) {
    final station = (item['kitchen_station_name']?.toString() ?? '').trim();
    final ready = pipeline == WaiterLinePipeline.ready;

    final readyTone = posStatusColors('ready');
    return Container(
      decoration: BoxDecoration(
        color: ready
            ? readyTone.bg
            : PosTheme.surfaceMuted.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? readyTone.fg.withValues(alpha: 0.4)
              : PosTheme.border.withValues(alpha: 0.8),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _stripe,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${parseJsonInt(item['quantity'], fallback: 1)}× ${item['name'] ?? 'Item'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: PosTheme.ink,
                            ),
                          ),
                          if (station.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              station,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: PosTheme.inkMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (canServe && onMarkServed != null)
                      FilledButton(
                        onPressed: onMarkServed,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        child: Text(markServedLabel),
                      )
                    else
                      _ItemStatusBadge(
                        pipeline: pipeline,
                        labels: labels,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemStatusBadge extends StatelessWidget {
  const _ItemStatusBadge({required this.pipeline, required this.labels});

  final WaiterLinePipeline pipeline;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final index =
        WaiterLinePipeline.values.indexOf(pipeline).clamp(0, labels.length - 1);
    final label = labels[index];
    final color = switch (pipeline) {
      WaiterLinePipeline.sent => const Color(0xFF64748B),
      WaiterLinePipeline.preparing => const Color(0xFFD97706),
      WaiterLinePipeline.ready => const Color(0xFF059669),
      WaiterLinePipeline.served => PosTheme.accent,
    };

    final soft = posAccentSoft(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: soft.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: soft.fg.withValues(alpha: PosTheme.isDark ? 0.28 : 0.28),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: soft.fg,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

/// Captain floor lines: ready-to-serve first, then newest KOT / line id.
List<Map<String, dynamic>> _captainItemsNewestFirst(
  List<Map<String, dynamic>> items,
) {
  int pipelineRank(WaiterLinePipeline pipeline) {
    return switch (pipeline) {
      WaiterLinePipeline.ready => 0,
      WaiterLinePipeline.preparing => 1,
      WaiterLinePipeline.sent => 2,
      WaiterLinePipeline.served => 3,
    };
  }

  final sorted = [...items];
  sorted.sort((a, b) {
    final aPipe = mapOrderStatusToPipeline(a['kitchen_status']?.toString());
    final bPipe = mapOrderStatusToPipeline(b['kitchen_status']?.toString());
    final statusCmp = pipelineRank(aPipe).compareTo(pipelineRank(bPipe));
    if (statusCmp != 0) return statusCmp;

    final roundCmp = parseJsonInt(b['kot_round'], fallback: 0)
        .compareTo(parseJsonInt(a['kot_round'], fallback: 0));
    if (roundCmp != 0) return roundCmp;

    return parseJsonInt(b['id'], fallback: 0)
        .compareTo(parseJsonInt(a['id'], fallback: 0));
  });
  return sorted;
}

String _relativeTime(String? iso, AppLocalizations l10n) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final local = dt.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inSeconds < 45) return l10n.timeJustNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
  return DateFormat('MMM d · h:mm a').format(local);
}
