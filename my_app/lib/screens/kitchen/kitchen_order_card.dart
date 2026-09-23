import 'package:flutter/material.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/kitchen_models.dart';
import '../../theme/pos_theme.dart';
import '../../utils/kitchen_board.dart';
import 'kitchen_print.dart';
import 'kitchen_theme.dart';

enum KitchenCardDensity { board, panel, dock }

class KitchenOrderCard extends StatefulWidget {
  const KitchenOrderCard({
    super.key,
    required this.order,
    required this.laneKey,
    required this.density,
    required this.urgent,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.moveToReadyLabel,
    this.onMoveToReady,
    this.markDoneLabel,
    this.onMarkDone,
    this.onBump,
    this.onItemToggle,
    this.splitCompact = false,
  });

  /// Back-compat: [compact] maps to [panel] vs [board].
  const KitchenOrderCard.legacy({
    super.key,
    required this.order,
    required this.laneKey,
    required bool compact,
    required this.urgent,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.moveToReadyLabel,
    this.onMoveToReady,
    this.markDoneLabel,
    this.onMarkDone,
    this.onBump,
  }) : density = compact ? KitchenCardDensity.panel : KitchenCardDensity.board,
       splitCompact = false,
       onItemToggle = null;

  final KitchenBoardOrder order;
  final String laneKey;
  final KitchenCardDensity density;
  final bool urgent;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final String? moveToReadyLabel;
  final VoidCallback? onMoveToReady;
  final String? markDoneLabel;
  final VoidCallback? onMarkDone;
  final VoidCallback? onBump;
  final void Function(KitchenBoardItem item, {String? status})? onItemToggle;
  final bool splitCompact;

  @override
  State<KitchenOrderCard> createState() => _KitchenOrderCardState();
}

class _KitchenOrderCardState extends State<KitchenOrderCard> {
  bool _expanded = false;
  bool _printingKot = false;

  Future<void> _handlePrintKot() async {
    if (_printingKot) return;
    setState(() => _printingKot = true);
    try {
      await printKitchenKot(context, widget.order);
    } finally {
      if (mounted) setState(() => _printingKot = false);
    }
  }

  Widget? _printKotAction({required Color color, bool compact = false}) {
    if (!kitchenOrderCanPrintKot(widget.order)) return null;
    if (compact) {
      return _DockIconAction(
        icon: Icons.print_outlined,
        tooltip: context.l10n.ordersPrintKot,
        color: color,
        loading: _printingKot,
        onTap: _handlePrintKot,
      );
    }
    return TextButton.icon(
      onPressed: _printingKot ? null : _handlePrintKot,
      icon: _printingKot
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.print_outlined, size: 16),
      label: Text(context.l10n.ordersPrintKot),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.density == KitchenCardDensity.dock) {
      return _buildDockCard(context);
    }
    return _buildBoardCard(context);
  }

  Widget _buildDockCard(BuildContext context) =>
      _buildTicketCard(context, compact: true, splitCompact: widget.splitCompact);

  Widget _buildBoardCard(BuildContext context) => _buildTicketCard(
        context,
        compact: widget.density == KitchenCardDensity.panel,
        spacious: widget.density == KitchenCardDensity.board,
      );

  Widget _buildTicketCard(
    BuildContext context, {
    required bool compact,
    bool spacious = false,
    bool splitCompact = false,
  }) {
    final table = kitchenOrderTable(widget.order);
    final token = kitchenOrderToken(widget.order);
    final laneStyle = kitchenLaneStyle(widget.laneKey, context);
    final isReady = widget.laneKey == 'ready';
    final elapsed = kitchenElapsedLabel(
      context,
      widget.order,
      laneKey: widget.laneKey,
    );
    final statusLabel = kitchenLaneTitleForKey(context, widget.laneKey);
    final itemCount =
        widget.order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final printAction =
        _printKotAction(color: laneStyle.color, compact: compact);
    final borderColor = kitchenLaneCardBorder(
      widget.laneKey,
      urgent: widget.urgent,
    );
    final cardBg = kitchenLaneCardBackground(widget.laneKey);
    final dockTight = compact && splitCompact;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(dockTight ? 12 : 14),
        border: Border.all(
          color: borderColor,
          width: widget.urgent ? 2 : 1,
        ),
        boxShadow: dockTight
            ? null
            : [
                BoxShadow(
                  color: (isReady ? Colors.green : laneStyle.color)
                      .withValues(alpha: isReady ? 0.14 : 0.08),
                  blurRadius: isReady ? 14 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dockTight ? 11 : 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!dockTight)
              _KotHeaderBand(
                laneStyle: laneStyle,
                statusLabel: statusLabel,
                elapsed: elapsed,
                urgent: widget.urgent,
                emphasized: isReady,
                compact: compact,
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                dockTight ? 8 : (compact ? 12 : 14),
                dockTight ? 8 : (compact ? 10 : 12),
                dockTight ? 8 : (compact ? 12 : 14),
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dockTight)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          _KotStatusChip(
                            label: statusLabel,
                            color: laneStyle.color,
                            icon: laneStyle.icon,
                            emphasized: isReady,
                          ),
                          const Spacer(),
                          if (elapsed.isNotEmpty)
                            _ElapsedChip(label: elapsed, urgent: widget.urgent),
                        ],
                      ),
                    ),
                  _KotOrderContext(
                    orderType: widget.order.type,
                    showSource: kitchenShouldShowSourceTag(widget.order),
                    sourceKey: kitchenOrderChannelKey(widget.order),
                    table: table,
                    token: token,
                    orderNumber: widget.order.orderNumber,
                    kotRound: widget.order.kotRound,
                    priority: widget.order.kitchenPriority,
                    compact: compact,
                    spacious: spacious,
                    emphasized: isReady,
                    flat: dockTight,
                    slim: dockTight,
                  ),
                  if (!dockTight &&
                      widget.order.customerName?.trim().isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: PosTheme.inkMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              widget.order.customerName!.trim(),
                              style: TextStyle(
                                color: PosTheme.inkMuted,
                                fontSize: compact ? 11.5 : 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!dockTight &&
                      widget.order.kitchenName?.trim().isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.soup_kitchen_outlined,
                            size: 14,
                            color: PosTheme.inkMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              widget.order.kitchenName!.trim(),
                              style: TextStyle(
                                color: PosTheme.inkMuted,
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.order.items.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  dockTight ? 8 : (compact ? 12 : 14),
                  dockTight ? 6 : (compact ? 10 : 12),
                  dockTight ? 8 : (compact ? 12 : 14),
                  0,
                ),
                child: _KotItemsPanel(
                  order: widget.order,
                  laneColor: laneStyle.color,
                  compact: compact,
                  spacious: spacious,
                  expanded: _expanded,
                  itemCount: itemCount,
                  splitCompact: dockTight,
                  onToggleExpand: () => setState(() => _expanded = !_expanded),
                  onItemToggle: widget.onItemToggle,
                ),
              ),
            if (widget.order.notes?.trim().isNotEmpty == true)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 14,
                  8,
                  compact ? 12 : 14,
                  0,
                ),
                child: _KotNotesCallout(
                  notes: widget.order.notes!.trim(),
                  expanded: _expanded,
                ),
              ),
            Padding(
              padding: EdgeInsets.all(dockTight ? 8 : (compact ? 10 : 12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _KotActionBar(
                    laneColor: isReady ? Colors.green.shade600 : laneStyle.color,
                    primaryLabel: widget.primaryActionLabel,
                    onPrimary: widget.onPrimaryAction,
                    printAction: printAction,
                    onBump: widget.onBump,
                    bumpColor: laneStyle.color,
                    compact: compact || dockTight,
                    moveToReadyLabel: widget.moveToReadyLabel,
                    onMoveToReady: widget.onMoveToReady,
                    markDoneLabel: widget.markDoneLabel,
                    onMarkDone: widget.onMarkDone,
                  ),
                  if (widget.secondaryActionLabel != null &&
                      widget.onSecondaryAction != null) ...[
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: widget.onSecondaryAction,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: compact ? 8 : 10,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(widget.secondaryActionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KotOrderContext extends StatelessWidget {
  const _KotOrderContext({
    required this.orderType,
    required this.showSource,
    required this.sourceKey,
    required this.table,
    required this.token,
    required this.orderNumber,
    required this.kotRound,
    required this.priority,
    required this.compact,
    required this.spacious,
    required this.emphasized,
    this.flat = false,
    this.slim = false,
  });

  final String? orderType;
  final bool showSource;
  final String sourceKey;
  final String? table;
  final String? token;
  final String orderNumber;
  final int kotRound;
  final int priority;
  final bool compact;
  final bool spacious;
  final bool emphasized;
  final bool flat;
  final bool slim;

  @override
  Widget build(BuildContext context) {
    final typeColor = kitchenOrderTypeColor(orderType);
    final typeLabel = kitchenOrderTypeLabel(context, orderType);
    final typeIcon = kitchenOrderTypeIcon(orderType);
    final primaryKind = table != null
        ? _KotPrimaryKind.table
        : (token != null ? _KotPrimaryKind.token : _KotPrimaryKind.order);
    final primaryValue = table ?? token ?? orderNumber;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: flat ? 0 : (compact ? 10 : 12),
        vertical: flat ? 0 : (compact ? 10 : 12),
      ),
      decoration: flat
          ? null
          : BoxDecoration(
              color: PosTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PosTheme.border.withValues(alpha: 0.85)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KotPrimaryMark(
            value: primaryValue,
            kind: primaryKind,
            color: typeColor,
            compact: compact,
            spacious: spacious,
            slim: slim,
          ),
          SizedBox(width: slim ? 8 : (compact ? 10 : 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: compact ? 5 : 6,
                  runSpacing: compact ? 5 : 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _KotTypeChip(
                      label: typeLabel,
                      icon: typeIcon,
                      color: typeColor,
                      compact: compact,
                    ),
                    if (showSource)
                      _KotTypeChip(
                        label: kitchenChannelLabel(context, sourceKey),
                        icon: kitchenChannelIcon(sourceKey),
                        color: kitchenChannelColor(sourceKey),
                        compact: compact,
                      ),
                    if (kotRound > 1)
                      _KotMetaChip(
                        label: context.posText(
                          'kitchenKotRound',
                          'KOT {round}',
                          {'round': kotRound},
                        ),
                        compact: compact,
                        accent: true,
                      ),
                    if (priority > 0)
                      _KotMetaChip(
                        label: '+$priority',
                        compact: compact,
                        urgent: true,
                      ),
                  ],
                ),
                if (table != null && token != null) ...[
                  SizedBox(height: compact ? 6 : 8),
                  _KotInlineFact(
                    icon: Icons.confirmation_number_outlined,
                    label: context.posText('newOrderAlertToken', 'Token'),
                    value: token!,
                    color: typeColor,
                    compact: compact,
                  ),
                ],
                if (orderNumber.isNotEmpty) ...[
                  SizedBox(height: compact ? 5 : 6),
                  Text(
                    '#$orderNumber',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 10.5 : 11.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _KotPrimaryKind { table, token, order }

class _KotPrimaryMark extends StatelessWidget {
  const _KotPrimaryMark({
    required this.value,
    required this.kind,
    required this.color,
    required this.compact,
    required this.spacious,
    this.slim = false,
  });

  final String value;
  final _KotPrimaryKind kind;
  final Color color;
  final bool compact;
  final bool spacious;
  final bool slim;

  @override
  Widget build(BuildContext context) {
    final size = slim ? 48.0 : (compact ? 56.0 : (spacious ? 68.0 : 62.0));
    final isTable = kind == _KotPrimaryKind.table;
    final showTokenLabel = kind == _KotPrimaryKind.token;
    final numberSize = isTable
        ? (compact ? 11.0 : 12.0)
        : (slim ? 22.0 : (compact ? 24.0 : (spacious ? 32.0 : 28.0)));

    final mark = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isTable)
          Icon(
            Icons.table_restaurant_rounded,
            color: color,
            size: compact ? 14 : 16,
          ),
        if (isTable) const SizedBox(height: 2),
        if (showTokenLabel)
          Text(
            context.posText('newOrderAlertToken', 'Token').toUpperCase(),
            style: TextStyle(
              color: color.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
              fontSize: compact ? 7.5 : 8,
              letterSpacing: 0.45,
            ),
          ),
        if (showTokenLabel) const SizedBox(height: 1),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: isTable ? 2 : 1,
          softWrap: isTable,
          overflow: isTable ? TextOverflow.ellipsis : TextOverflow.visible,
          style: TextStyle(
            fontSize: numberSize,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: isTable ? -0.2 : -0.4,
            color: color,
          ),
        ),
      ],
    );

    return Container(
      width: isTable ? size : null,
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
        maxHeight: size,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: slim ? 6 : (compact ? 6 : 8),
        vertical: slim ? 4 : (compact ? 5 : 6),
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isTable ? 0.08 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isTable ? 0.2 : 0.28),
          width: isTable ? 1 : 1.5,
        ),
      ),
      child: isTable
          ? FittedBox(fit: BoxFit.scaleDown, child: mark)
          : mark,
    );
  }
}

class _KotInlineFact extends StatelessWidget {
  const _KotInlineFact({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: compact ? 13 : 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: PosTheme.inkMuted,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 10.5 : 11,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 8,
            vertical: compact ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 12 : 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _KotTypeChip extends StatelessWidget {
  const _KotTypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tint = PosTheme.isDark ? posAccentSoft(color) : null;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: tint?.bg ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: tint?.fg.withValues(alpha: 0.28) ??
              color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 14, color: tint?.fg ?? color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: tint?.fg ?? color,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _KotMetaChip extends StatelessWidget {
  const _KotMetaChip({
    required this.label,
    required this.compact,
    this.accent = false,
    this.urgent = false,
  });

  final String label;
  final bool compact;
  final bool accent;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final color = urgent
        ? kitchenCalloutColors(danger: true).fg
        : (accent ? PosTheme.ink : PosTheme.inkMuted);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: urgent
            ? kitchenCalloutColors(danger: true).bg
            : (accent ? PosTheme.canvas : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: urgent
              ? kitchenCalloutColors(danger: true).border
              : PosTheme.border.withValues(alpha: accent ? 1 : 0.7),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10 : 10.5,
        ),
      ),
    );
  }
}

class _KotStatusChip extends StatelessWidget {
  const _KotStatusChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.emphasized,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: kitchenChipPlate(filled: emphasized, fill: color),
        borderRadius: BorderRadius.circular(7),
        border: emphasized ? null : Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: kitchenChipOnPlate(filled: emphasized, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: kitchenChipOnPlate(filled: emphasized, color: color),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _KotHeaderBand extends StatelessWidget {
  const _KotHeaderBand({
    required this.laneStyle,
    required this.statusLabel,
    required this.elapsed,
    required this.urgent,
    required this.emphasized,
    required this.compact,
  });

  final KitchenLaneStyle laneStyle;
  final String statusLabel;
  final String elapsed;
  final bool urgent;
  final bool emphasized;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: laneStyle.color.withValues(
          alpha: PosTheme.isDark
              ? (emphasized ? 0.28 : 0.18)
              : (emphasized ? 0.16 : 0.09),
        ),
        border: Border(
          bottom: BorderSide(
            color: laneStyle.color.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kitchenChipPlate(
                filled: emphasized,
                fill: laneStyle.color,
              ),
              borderRadius: BorderRadius.circular(8),
              border: emphasized
                  ? null
                  : Border.all(color: laneStyle.color.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  laneStyle.icon,
                  size: compact ? 12 : 14,
                  color: kitchenChipOnPlate(
                    filled: emphasized,
                    color: laneStyle.color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  statusLabel.toUpperCase(),
                  style: TextStyle(
                    color: kitchenChipOnPlate(
                      filled: emphasized,
                      color: laneStyle.color,
                    ),
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (elapsed.isNotEmpty) _ElapsedChip(label: elapsed, urgent: urgent),
        ],
      ),
    );
  }
}

class _KotItemsPanel extends StatelessWidget {
  const _KotItemsPanel({
    required this.order,
    required this.laneColor,
    required this.compact,
    required this.spacious,
    required this.expanded,
    required this.itemCount,
    required this.onToggleExpand,
    this.onItemToggle,
    this.splitCompact = false,
  });

  final KitchenBoardOrder order;
  final Color laneColor;
  final bool compact;
  final bool spacious;
  final bool expanded;
  final int itemCount;
  final VoidCallback onToggleExpand;
  final void Function(KitchenBoardItem item, {String? status})? onItemToggle;
  final bool splitCompact;

  String _previewLine() {
    final names = order.items.map((item) => item.name).where((n) => n.isNotEmpty);
    final joined = names.take(2).join(', ');
    final extra = order.items.length - 2;
    if (extra > 0) return '$joined +$extra';
    return joined;
  }

  @override
  Widget build(BuildContext context) {
    final previewLimit = splitCompact ? 0 : (spacious ? 5 : 3);
    final visible = expanded
        ? order.items
        : (splitCompact ? const <KitchenBoardItem>[] : order.items.take(previewLimit).toList());
    final hidden = order.items.length - visible.length;
    final canExpand = order.items.isNotEmpty;
    final previewLine = _previewLine();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(splitCompact ? 9 : 11),
        border: Border.all(color: PosTheme.border.withValues(alpha: 0.85)),
      ),
      child: Padding(
            padding: EdgeInsets.fromLTRB(
              splitCompact ? 8 : (compact ? 10 : 12),
              splitCompact ? 6 : (compact ? 8 : 10),
              splitCompact ? 8 : (compact ? 10 : 12),
              splitCompact ? 6 : (compact ? 8 : 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: canExpand ? onToggleExpand : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        splitCompact && !expanded && previewLine.isNotEmpty
                            ? (itemCount == 1
                                ? context.posText('kitchenItemsOne', '1 item')
                                : context.posText(
                                    'kitchenItemsCount',
                                    '{count} items',
                                    {'count': itemCount},
                                  )) +
                                ': $previewLine'
                            : (itemCount == 1
                                ? context.posText('kitchenItemsOne', '1 item')
                                : context.posText(
                                    'kitchenItemsCount',
                                    '{count} items',
                                    {'count': itemCount},
                                  )),
                        maxLines: expanded ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: splitCompact ? 10 : (compact ? 10.5 : 11.5),
                          fontWeight: FontWeight.w800,
                          color: PosTheme.inkMuted,
                          letterSpacing: 0.2,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (canExpand)
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: PosTheme.inkMuted,
                      ),
                  ],
                ),
                ),
                if (expanded) ...[
                  const SizedBox(height: 8),
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _KotItemRow(
                      item: visible[i],
                      laneColor: laneColor,
                      compact: compact,
                      hideStation: splitCompact,
                      onToggle: onItemToggle,
                    ),
                  ],
                ] else if (!splitCompact) ...[
                  const SizedBox(height: 8),
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _KotItemRow(
                      item: visible[i],
                      laneColor: laneColor,
                      compact: compact,
                      hideStation: splitCompact,
                      onToggle: onItemToggle,
                    ),
                  ],
                  if (hidden > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        context.posText(
                          'kitchenItemsMore',
                          '+{count} more',
                          {'count': hidden},
                        ),
                        style: TextStyle(
                          color: laneColor,
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
    );
  }
}

class _KotItemRow extends StatelessWidget {
  const _KotItemRow({
    required this.item,
    required this.laneColor,
    required this.compact,
    this.hideStation = false,
    this.onToggle,
  });

  final KitchenBoardItem item;
  final Color laneColor;
  final bool compact;
  final bool hideStation;
  final void Function(KitchenBoardItem item, {String? status})? onToggle;

  @override
  Widget build(BuildContext context) {
    final ready = item.isReady;
    final cooking = item.isCooking;
    final delivered = item.isDelivered;
    final canToggle = onToggle != null && item.id > 0 && !item.isLocked;
    final title = item.variantName?.trim().isNotEmpty == true
        ? '${item.name} (${item.variantName})'
        : item.name;
    final accent = delivered
        ? Colors.lightBlue
        : ready
            ? Colors.green
            : cooking
                ? Colors.amber
                : laneColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canToggle ? () => onToggle!(item) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 22 : 24,
                height: compact ? 22 : 24,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: delivered
                      ? Colors.lightBlue.shade600
                      : ready
                          ? Colors.green.shade600
                          : cooking
                              ? Colors.amber.shade600
                              : Colors.transparent,
                  border: Border.all(
                    color: delivered
                        ? Colors.lightBlue.shade600
                        : ready
                            ? Colors.green.shade600
                            : cooking
                                ? Colors.amber.shade600
                                : laneColor.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: delivered
                    ? const Icon(Icons.done_all_rounded, size: 13, color: Colors.white)
                    : ready
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : cooking
                            ? const Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.white)
                            : null,
              ),
              const SizedBox(width: 8),
              Container(
                constraints: BoxConstraints(minWidth: compact ? 26 : 30),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 12 : 13,
                    color: delivered
                        ? Colors.lightBlue.shade800
                        : ready
                            ? Colors.green.shade700
                            : cooking
                                ? Colors.amber.shade800
                                : laneColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 12.5 : 14,
                                height: 1.35,
                                color: delivered ? PosTheme.inkMuted : PosTheme.ink,
                                decoration: delivered
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: delivered ? PosTheme.inkMuted : null,
                                decorationThickness: delivered ? 2.25 : null,
                              ),
                        ),
                        if (cooking)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.posText('kitchenItemCooking', 'Cooking'),
                              style: TextStyle(
                                fontSize: compact ? 9 : 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        if (delivered)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.posText('kitchenItemDelivered', 'Delivered'),
                              style: TextStyle(
                                fontSize: compact ? 9 : 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: Colors.lightBlue.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!hideStation && item.stationName?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.stationName!.trim(),
                          style: TextStyle(
                            color: laneColor.withValues(alpha: 0.85),
                            fontSize: compact ? 9.5 : 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                    if (item.modifiers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child:                         Text(
                          item.modifiers.join(' · '),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: PosTheme.inkMuted,
                                fontSize: compact ? 10.5 : 11.5,
                                height: 1.35,
                                decoration: delivered
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: delivered ? PosTheme.inkMuted : null,
                                decorationThickness: delivered ? 2 : null,
                              ),
                        ),
                      ),
                    if (item.notes?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.notes!.trim(),
                          style: TextStyle(
                            color: kitchenCalloutColors().fg,
                            fontSize: compact ? 10.5 : 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (ready && canToggle) ...[
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: () => onToggle!(item, status: 'delivered'),
                  icon: Icon(Icons.done_all_rounded, size: compact ? 14 : 16),
                  label: Text(context.posText('kitchenItemServe', 'Serve')),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.lightBlue.shade600,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.lightBlue.shade900.withValues(alpha: 0.45),
                    minimumSize: Size(compact ? 72 : 84, compact ? 32 : 36),
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: TextStyle(
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KotNotesCallout extends StatelessWidget {
  const _KotNotesCallout({required this.notes, required this.expanded});

  final String notes;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tone = kitchenCalloutColors();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 15, color: tone.fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notes,
              maxLines: expanded ? 6 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone.fg,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KotActionBar extends StatelessWidget {
  const _KotActionBar({
    required this.laneColor,
    required this.primaryLabel,
    required this.onPrimary,
    required this.printAction,
    required this.onBump,
    required this.bumpColor,
    required this.compact,
    this.moveToReadyLabel,
    this.onMoveToReady,
    this.markDoneLabel,
    this.onMarkDone,
  });

  final Color laneColor;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final Widget? printAction;
  final VoidCallback? onBump;
  final Color bumpColor;
  final bool compact;
  final String? moveToReadyLabel;
  final VoidCallback? onMoveToReady;
  final String? markDoneLabel;
  final VoidCallback? onMarkDone;

  @override
  Widget build(BuildContext context) {
    final showMoveToReady = onMoveToReady != null && moveToReadyLabel != null;
    final showDone = onMarkDone != null && markDoneLabel != null;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: PosTheme.canvas.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ?printAction,
              if (printAction != null) const SizedBox(width: 6),
              if (onBump != null)
                _DockIconAction(
                  icon: Icons.arrow_upward_rounded,
                  tooltip: context.posText('kitchenBumpPriority', 'Priority'),
                  color: bumpColor,
                  onTap: onBump!,
                ),
              if (onBump != null) const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: laneColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
            ],
          ),
          if (showMoveToReady || showDone) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (showMoveToReady)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onMoveToReady,
                      style: kitchenReadyOutlineStyle(compact: compact),
                      child: Text(
                        moveToReadyLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (showMoveToReady && showDone) const SizedBox(width: 6),
                if (showDone)
                  Expanded(
                    child: FilledButton(
                      onPressed: onMarkDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.lightBlue.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                      child: Text(
                        markDoneLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DockIconAction extends StatelessWidget {
  const _DockIconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PosTheme.border),
            ),
            child: loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

class _ElapsedChip extends StatelessWidget {
  const _ElapsedChip({required this.label, required this.urgent});

  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final urgentTone = kitchenCalloutColors(danger: true);
    final color = urgent ? urgentTone.fg : PosTheme.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: urgent
            ? urgentTone.bg
            : kitchenChipPlate(filled: false).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: urgent ? urgentTone.border : PosTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
