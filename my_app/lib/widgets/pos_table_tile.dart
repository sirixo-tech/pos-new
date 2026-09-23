import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/pos_l10n.dart';
import '../theme/pos_theme.dart';
import '../utils/pos_table_layout.dart';
import '../utils/waiter_table_status.dart';

/// Compact floor summary for a table tile.
class PosTableFloorInfo {
  const PosTableFloorInfo({
    this.seats,
    this.billLabel,
    this.seatedLabel,
  });

  final int? seats;
  final String? billLabel;
  final String? seatedLabel;

  bool get hasContent =>
      seats != null ||
      (billLabel != null && billLabel!.isNotEmpty) ||
      (seatedLabel != null && seatedLabel!.isNotEmpty);

  bool get hasLiveTicket =>
      (billLabel != null && billLabel!.isNotEmpty) ||
      (seatedLabel != null && seatedLabel!.isNotEmpty);
}

/// Compact, status-colored table chip for floor / picker grids.
class PosTableTile extends StatelessWidget {
  const PosTableTile({
    super.key,
    required this.name,
    required this.status,
    required this.onTap,
    this.selected = false,
    this.compact = false,
    this.actionHint,
    this.hasOpenTicket = false,
    /// When true, distinguish occupied tables with vs without an open ticket.
    this.orderAware = false,
    this.floorInfo,
  });

  final String name;
  final WaiterTableStatus status;
  final VoidCallback onTap;
  final bool selected;
  final bool compact;
  final String? actionHint;
  final bool hasOpenTicket;
  final bool orderAware;
  final PosTableFloorInfo? floorInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final style = waiterTableStatusStyle(status, isDark: isDark);
    final radius = BorderRadius.circular(compact ? 14 : 16);
    final info = floorInfo;
    final bill = info?.billLabel?.trim();
    final seated = info?.seatedLabel?.trim();
    final seats = info?.seats;
    final live = info?.hasLiveTicket == true;
    final awaitingOrder = orderAware &&
        status == WaiterTableStatus.occupied &&
        !hasOpenTicket &&
        !live;
    final label = awaitingOrder
        ? l10n.waiterTableActionStartOrder
        : (actionHint ?? _statusLabel(l10n, status));
    // Amber attention chip — stands out on the red occupied tile.
    const noOrderAccent = Color(0xFFFBBF24);
    const noOrderAccentLight = Color(0xFFD97706);
    const noOrderFill = Color(0xFFFFFBEB);
    const noOrderBorder = Color(0xFFFCD34D);
    final attentionAccent = isDark ? noOrderAccent : noOrderAccentLight;

    // Dark cards: bright primary ink, softer secondary, clear CTA plate.
    final titleColor = isDark ? Colors.white : style.foreground;
    final billColor = isDark ? Colors.white : style.foreground;
    final metaColor = isDark
        ? Colors.white.withValues(alpha: 0.82)
        : style.foreground;
    final metaFill = isDark
        ? Colors.black.withValues(alpha: 0.38)
        : style.dot.withValues(alpha: 0.12);
    final iconMuted = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : style.foreground.withValues(alpha: 0.75);
    final ctaBg = awaitingOrder
        ? (isDark
            ? attentionAccent.withValues(alpha: 0.22)
            : noOrderAccentLight.withValues(alpha: 0.16))
        : (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : style.dot.withValues(alpha: 0.14));
    final ctaFg = awaitingOrder
        ? attentionAccent
        : (isDark ? Colors.white : style.foreground);
    final ctaBorder = awaitingOrder
        ? attentionAccent.withValues(alpha: isDark ? 0.55 : 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.14)
            : style.dot.withValues(alpha: 0.18));
    final cardBorder = selected
        ? accent
        : awaitingOrder
            ? (isDark ? noOrderBorder : noOrderBorder)
            : (isDark ? style.border.withValues(alpha: 0.75) : style.border);

    return Material(
      color: style.background,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: style.dot.withValues(alpha: 0.18),
        highlightColor: style.dot.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.fromLTRB(
            compact ? 9 : 10,
            compact ? 9 : 10,
            compact ? 9 : 10,
            compact ? 8 : 9,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: cardBorder,
              width: selected || awaitingOrder ? 2 : (isDark ? 1 : 1.25),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : awaitingOrder
                    ? [
                        BoxShadow(
                          color: attentionAccent.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.35 : 0.04),
                          blurRadius: isDark ? 10 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 8 : 9,
                    height: compact ? 8 : 9,
                    decoration: BoxDecoration(
                      color: awaitingOrder ? attentionAccent : style.dot,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (awaitingOrder ? attentionAccent : style.dot)
                              .withValues(alpha: isDark ? 0.55 : 0.45),
                          blurRadius: isDark ? 6 : 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 13.5 : 15,
                        letterSpacing: -0.25,
                        height: 1.15,
                        color: titleColor,
                      ),
                    ),
                  ),
                  if (hasOpenTicket || live)
                    Icon(
                      Icons.receipt_long_rounded,
                      size: compact ? 14 : 15,
                      color: iconMuted,
                    )
                  else if (awaitingOrder)
                    Icon(
                      Icons.pending_actions_rounded,
                      size: compact ? 14 : 15,
                      color: attentionAccent,
                    )
                  else if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: compact ? 14 : 15,
                      color: accent,
                    ),
                ],
              ),
              if (bill != null && bill.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  bill,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 17 : 19,
                    letterSpacing: -0.5,
                    height: 1.05,
                    color: billColor,
                  ),
                ),
              ],
              if (seats != null ||
                  (!awaitingOrder &&
                      seated != null &&
                      seated.isNotEmpty)) ...[
                SizedBox(height: bill != null && bill.isNotEmpty ? 6 : 8),
                // One compact meta line — side-by-side chips truncate on narrow tiles.
                _MetaLine(
                  seatsLabel: seats != null
                      ? l10n.waiterTableSeatsCount(seats)
                      : null,
                  seatedLabel: !awaitingOrder &&
                          seated != null &&
                          seated.isNotEmpty
                      ? seated
                      : null,
                  color: metaColor,
                  fill: metaFill,
                  compact: compact,
                ),
              ],
              if (awaitingOrder) ...[
                SizedBox(
                  height: seats != null ||
                          (bill != null && bill.isNotEmpty)
                      ? 5
                      : 6,
                ),
                _DetailChip(
                  icon: Icons.restaurant_menu_rounded,
                  label: l10n.waiterNoOrderBadge,
                  color: attentionAccent,
                  fill: isDark
                      ? posAccentSoft(attentionAccent).bg
                      : noOrderFill,
                  compact: compact,
                ),
              ],
              const Spacer(),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 8,
                  vertical: compact ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: ctaBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: ctaBorder),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 10.5 : 11.5,
                    height: 1.15,
                    letterSpacing: 0.1,
                    color: ctaFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(AppLocalizations l10n, WaiterTableStatus status) {
    return switch (status) {
      WaiterTableStatus.available => l10n.waiterStatusAvailable,
      WaiterTableStatus.occupied => l10n.waiterStatusOccupied,
      WaiterTableStatus.billing => l10n.waiterStatusBilling,
      WaiterTableStatus.reserved => l10n.waiterStatusReserved,
      WaiterTableStatus.cleaning => l10n.waiterStatusCleaning,
    };
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.seatsLabel,
    required this.seatedLabel,
    required this.color,
    required this.fill,
    required this.compact,
  });

  final String? seatsLabel;
  final String? seatedLabel;
  final Color color;
  final Color fill;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasSeats = seatsLabel != null && seatsLabel!.isNotEmpty;
    final hasSeated = seatedLabel != null && seatedLabel!.isNotEmpty;
    if (!hasSeats && !hasSeated) return const SizedBox.shrink();

    final label = [
      if (hasSeats) seatsLabel!,
      if (hasSeated) seatedLabel!,
    ].join(' · ');
    final icon = hasSeats
        ? Icons.event_seat_outlined
        : Icons.schedule_rounded;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 7,
        vertical: compact ? 3.5 : 4,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: compact ? 12 : 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w600,
                height: 1.15,
                letterSpacing: -0.1,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.fill,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color fill;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 2.5 : 3,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive wrap of [PosTableTile]s with capped cell size for large screens.
class PosTableGrid extends StatelessWidget {
  const PosTableGrid({
    super.key,
    required this.tables,
    required this.onTableTap,
    this.selectedId,
    this.billRequestedIds = const {},
    this.openTicketTableIds = const {},
    this.orderAware = false,
    this.floorInfoForTable,
    this.actionHintForStatus,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final List<Map<String, dynamic>> tables;
  final void Function(Map<String, dynamic> table) onTableTap;
  final int? selectedId;
  final Set<int> billRequestedIds;
  final Set<int> openTicketTableIds;
  /// When true, occupied tables without an open ticket get a “No order” cue.
  final bool orderAware;
  final PosTableFloorInfo? Function(Map<String, dynamic> table)?
      floorInfoForTable;
  final String Function(WaiterTableStatus status)? actionHintForStatus;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (tables.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final extent = posTableMaxCrossAxisExtent(width);
        // Use compact type only when cells are truly narrow.
        final compact = extent < 160;
        final spacing = posTableGridSpacing(width);
        final ratio = posTableGridChildAspectRatio(width);

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: tables.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: extent,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            final table = tables[index];
            final id = table['id'];
            final intId = id is int ? id : int.tryParse('$id');
            final name = table['name']?.toString() ?? l10n.cartTable;
            final status = parseWaiterTableStatus(
              table['status']?.toString(),
              billRequested:
                  intId != null && billRequestedIds.contains(intId),
            );
            return PosTableTile(
              name: name,
              status: status,
              selected: intId != null && intId == selectedId,
              compact: compact,
              hasOpenTicket:
                  intId != null && openTicketTableIds.contains(intId),
              orderAware: orderAware,
              floorInfo: floorInfoForTable?.call(table),
              actionHint: actionHintForStatus?.call(status),
              onTap: () => onTableTap(table),
            );
          },
        );
      },
    );
  }
}

/// Compact status legend for floor / picker headers.
class PosTableStatusLegend extends StatelessWidget {
  const PosTableStatusLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = <(WaiterTableStatus, String)>[
      (WaiterTableStatus.available, l10n.waiterStatusAvailable),
      (WaiterTableStatus.occupied, l10n.waiterStatusOccupied),
      (WaiterTableStatus.billing, l10n.waiterStatusBilling),
      (WaiterTableStatus.cleaning, l10n.waiterStatusCleaning),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _LegendChip(
              status: items[i].$1,
              label: items[i].$2,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.status,
    required this.label,
    required this.isDark,
  });

  final WaiterTableStatus status;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final style = waiterTableStatusStyle(status, isDark: isDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: style.dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PosTheme.inkMuted,
          ),
        ),
      ],
    );
  }
}
