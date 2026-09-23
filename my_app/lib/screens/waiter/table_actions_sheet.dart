import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/pos_l10n.dart';
import '../../theme/pos_theme.dart';
import '../../utils/format.dart';
import '../../utils/json_parse.dart';
import '../../utils/waiter_table_status.dart';
import '../../widgets/pos_overlay.dart';

enum WaiterTableAction {
  seatGuests,
  addMore,
  viewBill,
  clearBillRequest,
  markCleaning,
  markAvailable,
  markReserved,
}

/// Status-aware table actions — POS bottom sheet on phones, side panel on wide.
Future<WaiterTableAction?> showTableActionsSheet(
  BuildContext context, {
  required String tableName,
  required WaiterTableStatus status,
  Map<String, dynamic>? order,
  required String currency,
  int? seatCapacity,
}) {
  final side = preferPosSidePanel(context);
  return showPosOverlay<WaiterTableAction>(
    context: context,
    sidePanelWidth: 420,
    useSafeArea: true,
    builder: (ctx) {
      final body = _TableActionsBody(
        tableName: tableName,
        status: status,
        order: order,
        currency: currency,
        seatCapacity: seatCapacity,
        asSidePanel: side,
      );
      if (side) {
        return PosSidePanelShell(child: body);
      }
      final maxH = posMobileSheetHeight(ctx, factor: 0.78);
      final width = MediaQuery.sizeOf(ctx).width.clamp(0.0, 480.0);
      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: maxH,
          width: width,
          child: PosBottomSheetShell(child: body),
        ),
      );
    },
  );
}

class _TableActionsBody extends StatelessWidget {
  const _TableActionsBody({
    required this.tableName,
    required this.status,
    required this.order,
    required this.currency,
    required this.asSidePanel,
    this.seatCapacity,
  });

  final String tableName;
  final WaiterTableStatus status;
  final Map<String, dynamic>? order;
  final String currency;
  final bool asSidePanel;
  final int? seatCapacity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = waiterTableStatusStyle(status, isDark: isDark);
    final soft = posAccentSoft(style.dot);
    final hasOrder = order != null;
    final itemCount = parseJsonInt(order?['item_count'], fallback: 0);
    final amountDue = parseJsonDouble(
      order?['amount_due'] ?? order?['total'],
    );
    final orderLabel = order?['order_number']?.toString() ??
        (order?['token'] != null ? 'T${order!['token']}' : null);
    final captain = (order?['captain_name']?.toString() ?? '').trim();
    final seated = _seatedForLabel(order?['created_at']?.toString(), l10n);

    final specs = _actionsForStatus(
      l10n: l10n,
      status: status,
      hasOrder: hasOrder,
    );
    final primary =
        specs.where((s) => s.primary).firstOrNull ?? specs.firstOrNull;
    final secondary = specs.where((s) => s != primary).toList();

    final primaryColor = switch (primary?.action) {
      WaiterTableAction.viewBill || WaiterTableAction.clearBillRequest =>
        const Color(0xFFD97706),
      WaiterTableAction.markCleaning => const Color(0xFF64748B),
      WaiterTableAction.markAvailable || WaiterTableAction.seatGuests =>
        const Color(0xFF10B981),
      _ => style.dot,
    };
    final primarySoft = posAccentSoft(primaryColor);

    final metaChips = <(IconData, String)>[
      if (orderLabel != null && orderLabel.isNotEmpty)
        (Icons.tag_rounded, orderLabel),
      if (seatCapacity != null)
        (Icons.event_seat_rounded, l10n.waiterTableSeatsCount(seatCapacity!)),
      if (hasOrder) (Icons.shopping_bag_outlined, l10n.waiterItemsCount(itemCount)),
      if (hasOrder) (Icons.payments_outlined, formatMoney(amountDue, currency)),
      if (seated.isNotEmpty) (Icons.schedule_rounded, seated),
      if (captain.isNotEmpty) (Icons.room_service_rounded, captain),
    ];

    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: PosTheme.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, asSidePanel ? 16 : 4, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: soft.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: soft.fg.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    Icons.table_restaurant_rounded,
                    color: soft.fg,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tableName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: PosTheme.ink,
                            ),
                      ),
                      const SizedBox(height: 6),
                      _StatusChip(
                        label: _statusLabel(l10n, status),
                        style: style,
                      ),
                    ],
                  ),
                ),
                Material(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.close_rounded, color: soft.fg),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (metaChips.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final chip in metaChips)
                          _MetaChip(icon: chip.$1, label: chip.$2),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: soft.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: soft.fg.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: soft.fg,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusHint(l10n, status, hasOrder: hasOrder),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: soft.fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (primary != null) ...[
                    const SizedBox(height: 16),
                    _PrimaryActionCard(
                      spec: primary,
                      color: primaryColor,
                      soft: primarySoft,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context, primary.action);
                      },
                    ),
                  ],
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      l10n.waiterTableActionsMore,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: PosTheme.inkMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < secondary.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _ActionTile(
                        spec: secondary[i],
                        accent: accent,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context, secondary[i].action);
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomPad),
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                foregroundColor: PosTheme.inkMuted,
                side: BorderSide(color: PosTheme.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(l10n.commonClose),
            ),
          ),
        ],
      ),
    );
  }

  /// Floor lifecycle actions — only what makes sense for this status.
  List<_ActionSpec> _actionsForStatus({
    required AppLocalizations l10n,
    required WaiterTableStatus status,
    required bool hasOrder,
  }) {
    return switch (status) {
      WaiterTableStatus.occupied => [
          _ActionSpec(
            action: WaiterTableAction.addMore,
            icon: hasOrder
                ? Icons.add_circle_outline_rounded
                : Icons.restaurant_menu_rounded,
            title: hasOrder
                ? l10n.waiterAddMore
                : l10n.waiterTableActionStartOrder,
            subtitle: hasOrder
                ? l10n.waiterTableActionAddMoreHint
                : l10n.waiterTableActionStartOrderHint,
            primary: true,
          ),
          if (hasOrder)
            _ActionSpec(
              action: WaiterTableAction.viewBill,
              icon: Icons.request_quote_outlined,
              title: l10n.waiterRequestBill,
              subtitle: l10n.waiterTableActionRequestBillHint,
            )
          else
            _ActionSpec(
              action: WaiterTableAction.markAvailable,
              icon: Icons.event_available_outlined,
              title: l10n.waiterTableActionFreeTable,
              subtitle: l10n.waiterTableActionFreeTableHint,
            ),
        ],
      WaiterTableStatus.billing => hasOrder
          ? [
              _ActionSpec(
                action: WaiterTableAction.viewBill,
                icon: Icons.receipt_long_rounded,
                title: l10n.waiterTableActionViewBill,
                subtitle: l10n.waiterTableActionViewBillHint,
                primary: true,
              ),
              _ActionSpec(
                action: WaiterTableAction.clearBillRequest,
                icon: Icons.undo_rounded,
                title: l10n.waiterTableActionClearBill,
                subtitle: l10n.waiterTableActionClearBillHint,
              ),
              _ActionSpec(
                action: WaiterTableAction.addMore,
                icon: Icons.add_circle_outline_rounded,
                title: l10n.waiterAddMore,
                subtitle: l10n.waiterTableActionAddMoreHint,
              ),
              _ActionSpec(
                action: WaiterTableAction.markCleaning,
                icon: Icons.cleaning_services_outlined,
                title: l10n.waiterTableActionMarkCleaning,
                subtitle: l10n.waiterTableActionMarkCleaningHint,
              ),
            ]
          : [
              _ActionSpec(
                action: WaiterTableAction.markCleaning,
                icon: Icons.cleaning_services_outlined,
                title: l10n.waiterTableActionMarkCleaning,
                subtitle: l10n.waiterTableActionMarkCleaningHint,
                primary: true,
              ),
              _ActionSpec(
                action: WaiterTableAction.markAvailable,
                icon: Icons.event_available_outlined,
                title: l10n.waiterTableActionFreeTable,
                subtitle: l10n.waiterTableActionFreeTableHint,
              ),
            ],
      WaiterTableStatus.reserved => [
          _ActionSpec(
            action: WaiterTableAction.seatGuests,
            icon: Icons.restaurant_menu_rounded,
            title: l10n.waiterTableActionStartOrder,
            subtitle: l10n.waiterTableActionStartOrderHint,
            primary: true,
          ),
          _ActionSpec(
            action: WaiterTableAction.markAvailable,
            icon: Icons.event_busy_outlined,
            title: l10n.waiterTableActionCancelReservation,
            subtitle: l10n.waiterTableActionCancelReservationHint,
          ),
        ],
      WaiterTableStatus.cleaning => [
          _ActionSpec(
            action: WaiterTableAction.markAvailable,
            icon: Icons.check_circle_outline_rounded,
            title: l10n.waiterTableActionReadyToSeat,
            subtitle: l10n.waiterTableActionReadyToSeatHint,
            primary: true,
          ),
        ],
      WaiterTableStatus.available => [
          _ActionSpec(
            action: WaiterTableAction.seatGuests,
            icon: Icons.restaurant_menu_rounded,
            title: l10n.waiterTableActionStartOrder,
            subtitle: l10n.waiterTableActionStartOrderHint,
            primary: true,
          ),
          _ActionSpec(
            action: WaiterTableAction.markReserved,
            icon: Icons.event_available_outlined,
            title: l10n.waiterTableActionReserve,
            subtitle: l10n.waiterTableActionReserveHint,
          ),
          _ActionSpec(
            action: WaiterTableAction.markCleaning,
            icon: Icons.cleaning_services_outlined,
            title: l10n.waiterTableActionMarkCleaning,
            subtitle: l10n.waiterTableActionMarkCleaningHint,
          ),
        ],
    };
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

  String _statusHint(
    AppLocalizations l10n,
    WaiterTableStatus status, {
    required bool hasOrder,
  }) {
    return switch (status) {
      WaiterTableStatus.available => l10n.waiterTableStatusHintAvailable,
      WaiterTableStatus.occupied => hasOrder
          ? l10n.waiterTableStatusHintOccupied
          : l10n.waiterTableStatusHintOccupiedEmpty,
      WaiterTableStatus.billing => hasOrder
          ? l10n.waiterTableStatusHintBilling
          : l10n.waiterTableStatusHintBillingDone,
      WaiterTableStatus.reserved => l10n.waiterTableStatusHintReserved,
      WaiterTableStatus.cleaning => l10n.waiterTableStatusHintCleaning,
    };
  }

  String _seatedForLabel(String? iso, AppLocalizations l10n) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 45) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    return l10n.timeDaysAgo(diff.inDays);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.style});

  final String label;
  final WaiterTableStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: style.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              color: style.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PosTheme.inkMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: PosTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.spec,
    required this.color,
    required this.soft,
    required this.onTap,
  });

  final _ActionSpec spec;
  final Color color;
  final ({Color bg, Color fg}) soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: soft.bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: soft.fg.withValues(alpha: 0.35)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                soft.bg,
                Color.lerp(soft.bg, color, PosTheme.isDark ? 0.18 : 0.12)!,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(spec.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.2,
                          color: soft.fg,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spec.subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: soft.fg.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: soft.fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionSpec {
  const _ActionSpec({
    required this.action,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.primary = false,
  });

  final WaiterTableAction action;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.spec,
    required this.accent,
    required this.onTap,
  });

  final _ActionSpec spec;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PosTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: soft.fg.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(spec.icon, color: soft.fg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: PosTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: PosTheme.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
