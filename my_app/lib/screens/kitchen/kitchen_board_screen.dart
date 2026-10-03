import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/kitchen_models.dart';
import '../../providers/kitchen_controller.dart';
import '../../theme/pos_theme.dart';
import '../../utils/kitchen_board.dart';
import 'kitchen_order_card.dart';
import 'kitchen_theme.dart';

/// Full-screen kitchen / KOT board for wall tablets.
class KitchenBoardScreen extends StatelessWidget {
  const KitchenBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KitchenController>(
      builder: (context, kitchen, _) {
        if (kitchen.loading && kitchen.lastRefresh == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (kitchen.errorMessage != null && kitchen.totalActive == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(kitchen.errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => kitchen.refresh(userInitiated: true),
                    child: Text(context.posText('kitchenRefresh', 'Refresh')),
                  ),
                ],
              ),
            ),
          );
        }

        final lanes = kitchenLanesFor(
          kitchen.bootstrap?.queueRequired ?? false,
        );
        final laneMap = kitchen.lanes;

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            if (constraints.maxWidth < 900) {
              return DefaultTabController(
                length: lanes.length,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabs: [
                        for (final lane in lanes)
                          Tab(
                            text:
                                '${kitchenLaneTitle(context, lane)} (${kitchenOrdersMatchingChannel(laneMap[lane.key] ?? const [], kitchen.selectedChannel).length})',
                          ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final lane in lanes)
                            _KitchenLaneColumn(
                              lane: lane,
                              orders: kitchenOrdersMatchingChannel(
                                laneMap[lane.key] ?? const [],
                                kitchen.selectedChannel,
                              ),
                              queueRequired:
                                  kitchen.bootstrap?.queueRequired ?? false,
                              compact: true,
                              onAdvance: (order, status) => kitchen
                                  .advanceOrder(order, status, lane: lane),
                              onBump: kitchen.bumpPriority,
                              onItemToggle: kitchen.toggleItemReady,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final lane in lanes) ...[
                  Expanded(
                    child: _KitchenLaneColumn(
                      lane: lane,
                      orders: kitchenOrdersMatchingChannel(
                        laneMap[lane.key] ?? const [],
                        kitchen.selectedChannel,
                      ),
                      queueRequired: kitchen.bootstrap?.queueRequired ?? false,
                      compact: compact,
                      onAdvance: (order, status) =>
                          kitchen.advanceOrder(order, status, lane: lane),
                      onBump: kitchen.bumpPriority,
                      onItemToggle: kitchen.toggleItemReady,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _KitchenLaneColumn extends StatelessWidget {
  const _KitchenLaneColumn({
    required this.lane,
    required this.orders,
    required this.queueRequired,
    required this.compact,
    required this.onAdvance,
    required this.onBump,
    required this.onItemToggle,
  });

  final KitchenLane lane;
  final List<KitchenBoardOrder> orders;
  final bool queueRequired;
  final bool compact;
  final void Function(KitchenBoardOrder order, String status) onAdvance;
  final Future<void> Function(KitchenBoardOrder order) onBump;
  final Future<void> Function(
    KitchenBoardOrder order,
    KitchenBoardItem item, {
    String? status,
  })
  onItemToggle;

  Color _accent(BuildContext context) =>
      kitchenLaneStyle(lane.key, context).color;

  String _title(BuildContext context) => kitchenLaneTitle(context, lane);

  String _actionLabel(BuildContext context, KitchenBoardOrder order) =>
      kitchenLaneActionLabel(
        context,
        lane,
        queueRequired: queueRequired,
        orderStatus: order.status,
      );

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return Padding(
      padding: EdgeInsets.all(compact ? 4 : 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PosTheme.surface,
            border: Border.all(color: PosTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 4, color: accent),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 10 : 14,
                  compact ? 10 : 12,
                  compact ? 10 : 14,
                  8,
                ),
                child: Row(
                  children: [
                    Icon(
                      kitchenLaneStyle(lane.key, context).icon,
                      color: accent,
                      size: compact ? 18 : 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _title(context).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 11 : 13,
                          letterSpacing: 0.6,
                          color: accent,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${orders.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 14 : 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? Center(
                        child: Text(
                          context.posText('kitchenNoOrders', 'All clear'),
                          style: TextStyle(color: PosTheme.inkMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 8 : 10,
                          0,
                          compact ? 8 : 10,
                          10,
                        ),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: compact ? 8 : 10),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final nextStatus = lane.nextStatus;
                          final skipStatus = lane.skipStatus;
                          return KitchenOrderCard(
                            order: order,
                            laneKey: lane.key,
                            density: compact
                                ? KitchenCardDensity.panel
                                : KitchenCardDensity.board,
                            urgent: isKitchenOrderUrgent(
                              order,
                              inPreparingLane: lane.key == 'preparing',
                            ),
                            primaryActionLabel: _actionLabel(context, order),
                            onPrimaryAction: () => onAdvance(order, nextStatus),
                            secondaryActionLabel: skipStatus == null
                                ? null
                                : context.posText(
                                    lane.skipActionKey!,
                                    'Start cooking now',
                                  ),
                            onSecondaryAction: skipStatus == null
                                ? null
                                : () => onAdvance(order, skipStatus),
                            moveToReadyLabel:
                                kitchenShowsMarkAsReady(lane, order)
                                ? kitchenMoveToReadyLabel(context)
                                : null,
                            onMoveToReady: kitchenShowsMarkAsReady(lane, order)
                                ? () => onAdvance(order, 'ready')
                                : null,
                            onBump: () => onBump(order),
                            onItemToggle: (item, {status}) =>
                                onItemToggle(order, item, status: status),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
