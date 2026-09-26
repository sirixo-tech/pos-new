import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/kitchen_models.dart';
import '../../providers/kitchen_controller.dart';
import '../../providers/pos_controller.dart';
import '../../services/kitchen_dock_storage.dart';
import '../../theme/pos_theme.dart';
import '../../utils/kitchen_board.dart';
import 'kitchen_channel_filter.dart';
import 'kitchen_order_card.dart';
import 'kitchen_theme.dart';
import 'kot_filter_order_dialog.dart';

enum KitchenDockFilter { all, ready, cooking, incoming }

/// Compact kitchen / KOT panel for the register POS (cashier + kitchen side-by-side).
class KitchenDockPanel extends StatefulWidget {
  const KitchenDockPanel({
    super.key,
    required this.onClose,
    this.showCloseButton = true,
    this.splitCompact = false,
  });

  final VoidCallback onClose;
  final bool showCloseButton;
  final bool splitCompact;

  @override
  State<KitchenDockPanel> createState() => _KitchenDockPanelState();
}

class _KitchenDockPanelState extends State<KitchenDockPanel> {
  @override
  Widget build(BuildContext context) {
    return Consumer<KitchenController>(
      builder: (context, kitchen, _) {
        if (kitchen.loading && kitchen.lastRefresh == null) {
          return ColoredBox(
            color: PosTheme.canvas,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final queueRequired = kitchen.bootstrap?.queueRequired ?? false;
        final entries = kitchenDockEntries(
          kitchen.lanes,
          queueRequired,
          sort: kitchen.selectedSort,
        );
        final channelScoped = kitchen.selectedChannel == null
            ? entries
            : entries
                .where(
                  (entry) => kitchenOrderMatchesChannel(
                    entry.order,
                    kitchen.selectedChannel,
                  ),
                )
                .toList();

        return ColoredBox(
          color: PosTheme.canvas,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DockHeader(
                kitchen: kitchen,
                filter: KitchenDockFilter.all,
                readyCount: 0,
                cookingCount: 0,
                incomingCount: 0,
                scopedTotal: channelScoped.length,
                channelOrders: [for (final entry in entries) entry.order],
                onFilterChanged: (_) {},
                onClose: widget.onClose,
                showCloseButton: widget.showCloseButton,
                splitCompact: widget.splitCompact,
                onOpenFullDisplay: () async {
                  final pos = context.read<PosController>();
                  if (!pos.canUseKitchen) return;
                  final branchId = pos.session?.branchId;
                  if (branchId != null) {
                    await KitchenDockStorage.persistOpen(branchId, true);
                  }
                  await pos.switchWorkMode(PosWorkMode.kitchen);
                },
              ),
              if (kitchen.errorMessage != null && kitchen.totalActive == 0)
                Expanded(
                  child: _DockErrorState(
                    message: kitchen.errorMessage!,
                    onRetry: () => kitchen.refresh(userInitiated: true),
                  ),
                )
              else
                Expanded(
                  child: _DockUnifiedList(
                    entries: channelScoped,
                    allEntries: entries,
                    filter: KitchenDockFilter.all,
                    channelFilter: kitchen.selectedChannel,
                    queueRequired: queueRequired,
                    splitCompact: widget.splitCompact,
                    onAdvance: kitchen.advanceOrder,
                    onBump: kitchen.bumpPriority,
                    onItemToggle: kitchen.toggleItemReady,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DockHeader extends StatelessWidget {
  const _DockHeader({
    required this.kitchen,
    required this.filter,
    required this.readyCount,
    required this.cookingCount,
    required this.incomingCount,
    required this.scopedTotal,
    required this.channelOrders,
    required this.onFilterChanged,
    required this.onClose,
    required this.showCloseButton,
    required this.onOpenFullDisplay,
    this.splitCompact = false,
  });

  final KitchenController kitchen;
  final KitchenDockFilter filter;
  final int readyCount;
  final int cookingCount;
  final int incomingCount;
  final int scopedTotal;
  final List<KitchenBoardOrder> channelOrders;
  final ValueChanged<KitchenDockFilter> onFilterChanged;
  final VoidCallback onClose;
  final bool showCloseButton;
  final VoidCallback onOpenFullDisplay;
  final bool splitCompact;

  @override
  Widget build(BuildContext context) {
    final _ = (
      filter,
      readyCount,
      cookingCount,
      incomingCount,
      scopedTotal,
      onFilterChanged,
    );
    return Container(
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(
          bottom: BorderSide(color: PosTheme.border.withValues(alpha: 0.75)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              splitCompact ? 10 : 12,
              splitCompact ? 8 : 10,
              splitCompact ? 6 : 6,
              splitCompact ? 6 : 8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.soup_kitchen_rounded,
                  size: splitCompact ? 22 : 24,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.posText('kitchenDockTitle', 'Kitchen'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: splitCompact ? 13 : 15.5,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.posText('kitchenRefresh', 'Refresh'),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: kitchen.refreshing
                      ? null
                      : () => kitchen.refresh(userInitiated: true),
                  icon: kitchen.refreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: Colors.green.shade600,
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip:
                      context.posText('kitchenOpenFullBoard', 'Full display'),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onOpenFullDisplay,
                  icon: Icon(
                    Icons.open_in_full_rounded,
                    size: 18,
                    color: Colors.green.shade600,
                  ),
                ),
                if (showCloseButton) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip:
                        context.posText('kitchenDockClose', 'Close panel'),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: onClose,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              splitCompact ? 10 : 12,
              0,
              splitCompact ? 10 : 12,
              splitCompact ? 8 : 10,
            ),
            child: KitchenFilterCarousel(
              compact: true,
              child: Row(
                children: [
                  KitchenKotFilterChips(
                    orders: channelOrders,
                    selectedChannel: kitchen.selectedChannel,
                    onChanged: kitchen.setChannelFilter,
                    compact: true,
                  ),
                  const SizedBox(width: 2),
                  KitchenKotFilterTuneButton(compact: true),
                  const SizedBox(width: 5),
                  KitchenSortMenu(
                    selected: kitchen.selectedSort,
                    onChanged: kitchen.setTicketSort,
                    compact: true,
                  ),
                  if (kitchen.bootstrap?.kitchens.isNotEmpty == true) ...[
                    const SizedBox(width: 5),
                    KitchenStationMenu(
                      stations: kitchen.bootstrap!.kitchens,
                      selectedId: kitchen.selectedKitchenId,
                      onChanged: kitchen.setKitchenFilter,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockUnifiedList extends StatelessWidget {
  const _DockUnifiedList({
    required this.entries,
    required this.allEntries,
    required this.filter,
    required this.channelFilter,
    required this.queueRequired,
    required this.splitCompact,
    required this.onAdvance,
    required this.onBump,
    required this.onItemToggle,
  });

  final List<KitchenDockEntry> entries;
  final List<KitchenDockEntry> allEntries;
  final KitchenDockFilter filter;
  final String? channelFilter;
  final bool queueRequired;
  final bool splitCompact;
  final Future<void> Function(
    KitchenBoardOrder order,
    String nextStatus, {
    required KitchenLane lane,
  }) onAdvance;
  final Future<void> Function(KitchenBoardOrder order) onBump;
  final Future<void> Function(
    KitchenBoardOrder order,
    KitchenBoardItem item, {
    String? status,
  }) onItemToggle;

  @override
  Widget build(BuildContext context) {
    if (allEntries.isEmpty) {
      return _DockEmptyState();
    }

    if (entries.isEmpty) {
      return _DockFilteredEmptyState(
        filter: filter,
        channelFilter: channelFilter,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        splitCompact ? 8 : 10,
        splitCompact ? 6 : 8,
        splitCompact ? 8 : 10,
        splitCompact ? 8 : 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: splitCompact ? 6 : 8),
        child: _buildCard(context, entries[index]),
      ),
    );
  }

  Widget _buildCard(BuildContext context, KitchenDockEntry entry) {
    final lane = entry.lane;
    final order = entry.order;
    final skipStatus = lane.skipStatus;
    return KitchenOrderCard(
      order: order,
      laneKey: lane.key,
      density: KitchenCardDensity.dock,
      splitCompact: splitCompact,
      urgent: isKitchenOrderUrgent(
        order,
        inPreparingLane: lane.key == 'preparing',
      ),
      primaryActionLabel: kitchenLaneActionLabel(
        context,
        lane,
        queueRequired: queueRequired,
        orderStatus: order.status,
      ),
      onPrimaryAction: () => onAdvance(order, lane.nextStatus, lane: lane),
      secondaryActionLabel: skipStatus == null
          ? null
          : context.posText(lane.skipActionKey!, 'Start cooking now'),
      onSecondaryAction: skipStatus == null
          ? null
          : () => onAdvance(order, skipStatus, lane: lane),
      moveToReadyLabel: kitchenShowsMarkAsReady(lane, order)
          ? kitchenMoveToReadyLabel(context)
          : null,
      onMoveToReady: kitchenShowsMarkAsReady(lane, order)
          ? () => onAdvance(order, 'ready', lane: lane)
          : null,
      onBump: () => onBump(order),
      onItemToggle: (item, {status}) =>
          onItemToggle(order, item, status: status),
    );
  }
}

class _DockEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: PosTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: PosTheme.border),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 28,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.posText('kitchenNoOrders', 'All clear'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              context.posText(
                'kitchenDockEmptyHint',
                'Orders appear after payment or Send to Kitchen.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PosTheme.inkMuted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockFilteredEmptyState extends StatelessWidget {
  const _DockFilteredEmptyState({
    required this.filter,
    this.channelFilter,
  });

  final KitchenDockFilter filter;
  final String? channelFilter;

  @override
  Widget build(BuildContext context) {
    final channel = channelFilter == null
        ? ''
        : kitchenChannelLabel(context, channelFilter!);
    final _ = filter;
    final message = channel.isNotEmpty
        ? context.posText(
            'kitchenDockChannelEmpty',
            'No {channel} tickets',
            {'channel': channel},
          )
        : context.posText(
            'kitchenDockFilterEmpty',
            'No matching orders',
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: PosTheme.inkMuted.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PosTheme.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockErrorState extends StatelessWidget {
  const _DockErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.posText('kitchenRefresh', 'Refresh')),
            ),
          ],
        ),
      ),
    );
  }
}
