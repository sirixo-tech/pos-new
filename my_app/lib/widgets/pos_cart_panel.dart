import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/cart_quick_pay_settings.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/json_parse.dart';
import '../utils/pos_layout.dart';
import '../utils/tax_calculator.dart';
import 'discount_dialog.dart';
import 'pos_item_type_badge.dart';
import 'pos_overlay.dart';
import 'pos_table_tile.dart';
import 'pos_ui.dart';

class PosCartPanel extends StatefulWidget {
  const PosCartPanel({
    super.key,
    this.onPay,
    this.onPayMethod,
    this.onPark,
    this.onOpenHeld,
    this.compact = false,
    this.splitCompact = false,
    this.primaryLabel,
    this.primaryIcon,
    this.primaryColor,
    this.lockServiceContext = false,
  });

  final VoidCallback? onPay;

  /// Optional quick-pay hint: `cash`, `card`, `upi`, or `more`.
  final ValueChanged<String>? onPayMethod;
  final VoidCallback? onPark;
  final VoidCallback? onOpenHeld;
  final bool compact;
  final bool splitCompact;

  /// Overrides the Pay button label (e.g. waiter “Send to Kitchen”).
  final String? primaryLabel;

  /// Overrides the Pay button icon.
  final IconData? primaryIcon;

  /// Overrides the Pay button color (defaults to [PosTheme.payAccent]).
  final Color? primaryColor;

  /// When true, order type / table are shown read-only (waiter table session).
  final bool lockServiceContext;

  @override
  State<PosCartPanel> createState() => _PosCartPanelState();
}

class _PosCartPanelState extends State<PosCartPanel> {
  List<Map<String, dynamic>> _tables = const [];
  List<Map<String, dynamic>> _tableAreas = const [];
  List<Map<String, dynamic>> _tablesWithoutArea = const [];
  bool _tablesLoaded = false;
  bool _tablesLoading = false;

  void _scheduleTablesLoad(PosController pos) {
    if (_tablesLoaded || _tablesLoading || pos.orderType != 'dine_in') return;
    _tablesLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() {});
      try {
        final data = await pos.fetchTables();
        final tables = _mapList(data['tables']);
        final areas = _mapList(data['table_areas']);
        final withoutArea = _mapList(data['tables_without_area']);
        if (!mounted) return;
        setState(() {
          _tables = tables;
          _tableAreas = areas;
          _tablesWithoutArea =
              withoutArea.isNotEmpty ? withoutArea : _tablesWithoutAreaFrom(tables);
          _tablesLoaded = true;
          _tablesLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _tablesLoading = false);
      }
    });
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static List<Map<String, dynamic>> _tablesWithoutAreaFrom(
    List<Map<String, dynamic>> tables,
  ) {
    return tables.where((t) {
      final areaId = t['table_area_id'];
      return areaId == null || '$areaId'.isEmpty;
    }).toList();
  }

  Future<void> _openCustomerPicker(PosController pos, Color accent) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _CustomerPickerDialog(
        accent: accent,
        initialCustomerId: pos.customerId,
        initialCustomerName: pos.customerName,
        onSearch: pos.searchCustomers,
        onCreate: ({
          required String name,
          String? phone,
          String? email,
        }) =>
            pos.createCustomer(name: name, phone: phone, email: email),
        onApply: ({int? id, String? name}) {
          if (name == null || name.trim().isEmpty) {
            pos.clearCustomer();
          } else {
            pos.setCustomer(id: id, name: name.trim());
          }
        },
        onClear: pos.clearCustomer,
      ),
    );
  }

  Future<void> _openDiscount(PosController pos) async {
    final result = await DiscountDialog.show(
      context,
      subtotal: pos.cartSubtotal,
      currency: pos.currency,
      current: pos.discount,
    );
    if (result == null || !mounted) return;
    if (result.cleared) {
      pos.setDiscount(null);
    } else {
      pos.setDiscount(result.discount);
    }
  }

  Future<void> _clearTicket(PosController pos) async {
    if (pos.cart.isEmpty && !pos.hasParkedTicket) return;
    final l10n = context.l10n;
    final ok = await showPosConfirmDialog(
      context,
      title: l10n.cartClearTitle,
      message: l10n.cartClearMessage,
      confirmLabel: l10n.commonClear,
      destructive: true,
    );
    if (!ok || !mounted) return;
    pos.clearCart();
  }

  String _tableLabel(int? id) {
    final l10n = context.l10n;
    if (id == null) return l10n.cartSelectTable;
    for (final t in _tables) {
      if (t['id'] == id || '${t['id']}' == '$id') {
        return t['name']?.toString() ?? l10n.cartTableNamed('$id');
      }
    }
    final waiterTables = context.read<PosController>().waiterTables;
    for (final t in waiterTables) {
      if (t['id'] == id || '${t['id']}' == '$id') {
        return t['name']?.toString() ?? l10n.cartTableNamed('$id');
      }
    }
    return l10n.cartTableNamed('$id');
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final l10n = context.l10n;

    final customerId = context.select((PosController p) => p.customerId);
    final customerName = context.select((PosController p) => p.customerName);
    final orderType = context.select((PosController p) => p.orderType);
    final tableId = context.select((PosController p) => p.tableId);
    final parkedOrderId = context.select((PosController p) => p.parkedOrderId);
    final parkedLocalUuid =
        context.select((PosController p) => p.parkedLocalUuid);
    final hasParkedTicket = parkedOrderId != null || parkedLocalUuid != null;
    final parkedOrderLabel =
        context.select((PosController p) => p.parkedOrderLabel);
    final parkedAmountPaid =
        context.select((PosController p) => p.parkedAmountPaid);
    final itemCount = context.select((PosController p) => p.cartItemCount);
    final hasDiscount =
        context.select((PosController p) => p.discountAmount > 0);
    final allowedOrderTypes = context.select(
      (PosController p) =>
          p.bootstrap?.restaurant.ordering.activePosOrderTypes ??
          const ['dine_in', 'takeaway', 'delivery'],
    );
    final pos = context.read<PosController>();

    _scheduleTablesLoad(pos);

    final hasCustomer =
        customerId != null || (customerName?.isNotEmpty ?? false);
    final canClear = itemCount > 0 || hasParkedTicket;
    final showDiscount =
        !widget.lockServiceContext && !pos.isWaiterMode;

    if (orderType == 'delivery' &&
        allowedOrderTypes.isNotEmpty &&
        !allowedOrderTypes.contains('delivery')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final fallback = allowedOrderTypes.contains('dine_in')
            ? 'dine_in'
            : allowedOrderTypes.first;
        context.read<PosController>().setOrderType(fallback);
      });
    }

    final headerCompact = widget.compact || widget.splitCompact;

    return Container(
      width: headerCompact ? null : double.infinity,
      decoration: BoxDecoration(
        color: PosTheme.canvas,
        border: Border(
          left: headerCompact
              ? BorderSide.none
              : BorderSide(color: PosTheme.border.withValues(alpha: 0.9)),
        ),
      ),
      child: Column(
        children: [
          Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  widget.splitCompact ? 10 : 14,
                  headerCompact ? 4 : 14,
                  widget.splitCompact ? 10 : 14,
                  headerCompact ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  color: PosTheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: PosTheme.border.withValues(alpha: 0.85),
                    ),
                  ),
                  boxShadow: widget.compact
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.splitCompact)
                      widget.lockServiceContext
                          ? _LockedServiceContext(
                              orderType: orderType,
                              tableLabel: orderType == 'dine_in'
                                  ? _tableLabel(tableId)
                                  : null,
                              accent: accent,
                              soft: soft,
                            )
                          : _SplitServiceRow(
                              accent: accent,
                              soft: soft,
                              orderType: orderType,
                              allowedTypes: allowedOrderTypes,
                              onOrderTypeChanged: pos.setOrderType,
                              tableLabel: orderType == 'dine_in'
                                  ? _tableLabel(tableId)
                                  : null,
                              tableCount: _tables.length,
                              onTableTap: null,
                              hasCustomer: hasCustomer,
                              customerName: customerName,
                              onCustomerTap: () =>
                                  _openCustomerPicker(pos, accent),
                              canClear: canClear,
                              onClear: () => _clearTicket(pos),
                              showDiscount: showDiscount,
                              hasDiscount: hasDiscount,
                              onDiscount: () => _openDiscount(pos),
                            )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _CustomerChip(
                              accent: accent,
                              soft: soft,
                              hasCustomer: hasCustomer,
                              name: customerName,
                              onTap: () => _openCustomerPicker(pos, accent),
                            ),
                          ),
                          if (showDiscount) ...[
                            const SizedBox(width: 8),
                            _HeaderDiscountButton(
                              accent: accent,
                              active: hasDiscount,
                              onPressed: () => _openDiscount(pos),
                            ),
                          ],
                          const SizedBox(width: 8),
                          _ClearTicketButton(
                            enabled: canClear,
                            onPressed: canClear
                                ? () => _clearTicket(pos)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (widget.lockServiceContext)
                        _LockedServiceContext(
                          orderType: orderType,
                          tableLabel: orderType == 'dine_in'
                              ? _tableLabel(tableId)
                              : null,
                          accent: accent,
                          soft: soft,
                        )
                      else ...[
                        _OrderTypeRow(
                          value: orderType,
                          onChanged: pos.setOrderType,
                          accent: accent,
                          allowedTypes: allowedOrderTypes,
                          iconOnly: widget.splitCompact,
                        ),
                      ],
                    ],
                    if (hasParkedTicket) ...[
                      const SizedBox(height: 10),
                      _HeldBanner(
                        label: parkedOrderLabel ??
                            parkedLocalUuid ??
                            '#$parkedOrderId',
                        alreadyPaid: parkedAmountPaid,
                        remaining: pos.cartAmountDue,
                        currency: pos.currency,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _CartLinesPane(accent: accent),
              ),
              _CartFooterPane(
                accent: accent,
                soft: soft,
                onPay: widget.onPay,
                onPayMethod: widget.onPayMethod,
                onPark: widget.onPark,
                primaryLabel: widget.primaryLabel,
                primaryIcon: widget.primaryIcon,
                primaryColor: widget.primaryColor,
              ),
            ],
          ),
    );
  }
}

Future<void> showPosTablePicker(BuildContext context) async {
  final pos = context.read<PosController>();
  final accent = Theme.of(context).colorScheme.primary;
  List<Map<String, dynamic>> tables = const [];
  List<Map<String, dynamic>> tableAreas = const [];
  List<Map<String, dynamic>> tablesWithoutArea = const [];
  try {
    final data = await pos.fetchTables();
    tables = _PosCartPanelState._mapList(data['tables']);
    tableAreas = _PosCartPanelState._mapList(data['table_areas']);
    final withoutArea =
        _PosCartPanelState._mapList(data['tables_without_area']);
    tablesWithoutArea = withoutArea.isNotEmpty
        ? withoutArea
        : _PosCartPanelState._tablesWithoutAreaFrom(tables);
  } catch (_) {}
  if (!context.mounted) return;
  if (pos.orderType != 'dine_in') {
    pos.setOrderType('dine_in');
  }
  final result = await showModalBottomSheet<_TablePick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => PosKeyboardSheetHost(
      child: _TablePickerSheet(
        accent: accent,
        selectedId: pos.tableId,
        tableAreas: tableAreas,
        tablesWithoutArea:
            tablesWithoutArea.isNotEmpty ? tablesWithoutArea : tables,
      ),
    ),
  );
  if (!context.mounted || result == null) return;
  pos.setTableId(result.id, name: result.name);
}

class _CartLinesPane extends StatefulWidget {
  const _CartLinesPane({required this.accent});

  final Color accent;

  @override
  State<_CartLinesPane> createState() => _CartLinesPaneState();
}

class _CartLinesPaneState extends State<_CartLinesPane> {
  int? _expandedIndex;
  int _appliedRevealGeneration = -1;

  @override
  Widget build(BuildContext context) {
    context.select((PosController p) => p.cartEpoch);
    final revealGeneration =
        context.select((PosController p) => p.cartRevealGeneration);
    final currency = context.select((PosController p) => p.currency);
    final pos = context.read<PosController>();
    final cartLen = pos.cart.length;

    if (revealGeneration != _appliedRevealGeneration) {
      _appliedRevealGeneration = revealGeneration;
      final reveal = pos.cartRevealIndex;
      _expandedIndex =
          reveal != null && reveal >= 0 && reveal < cartLen ? reveal : null;
    } else if (_expandedIndex != null && _expandedIndex! >= cartLen) {
      _expandedIndex = cartLen == 0 ? null : cartLen - 1;
    }

    if (pos.cart.isEmpty) {
      return const _EmptyCart();
    }

    final expandedIndex = _expandedIndex;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: cartLen,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final line = pos.cart[index];
        return _CartLineRow(
          key: ValueKey(
            'cart-${index}-${line.menuItem.id}-${line.variant?.id ?? 0}',
          ),
          line: line,
          currency: currency,
          accent: widget.accent,
          expanded: expandedIndex == index,
          onToggleExpanded: () {
            setState(() {
              _expandedIndex = _expandedIndex == index ? null : index;
            });
          },
          onIncrement: () {
            HapticFeedback.selectionClick();
            pos.updateCartQty(line, line.quantity + 1);
          },
          onDecrement: () {
            HapticFeedback.selectionClick();
            pos.updateCartQty(line, line.quantity - 1);
          },
          onRemove: () {
            HapticFeedback.selectionClick();
            if (_expandedIndex == index) {
              _expandedIndex = null;
            } else if (_expandedIndex != null && _expandedIndex! > index) {
              _expandedIndex = _expandedIndex! - 1;
            }
            pos.removeFromCart(line);
          },
          onNotesChanged: (value) => pos.updateCartLineNotes(line, value),
        );
      },
    );
  }
}

class _CartFooterPane extends StatefulWidget {
  const _CartFooterPane({
    required this.accent,
    required this.soft,
    this.onPay,
    this.onPayMethod,
    this.onPark,
    this.primaryLabel,
    this.primaryIcon,
    this.primaryColor,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final VoidCallback? onPay;
  final ValueChanged<String>? onPayMethod;
  final VoidCallback? onPark;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final Color? primaryColor;

  @override
  State<_CartFooterPane> createState() => _CartFooterPaneState();
}

class _CartFooterPaneState extends State<_CartFooterPane> {
  String _quickPay = 'cash';
  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final soft = widget.soft;
    final onPay = widget.onPay;
    final onPark = widget.onPark;
    final primaryLabel = widget.primaryLabel;
    final primaryIcon = widget.primaryIcon;
    final primaryColor = widget.primaryColor;
    context.select((PosController p) => p.cartEpoch);
    final submitting = context.select((PosController p) => p.submitting);
    final currency = context.select((PosController p) => p.currency);
    final discountAmount =
        context.select((PosController p) => p.discountAmount);
    final serviceChargeLabel = context.select(
      (PosController p) => p.bootstrap?.restaurant.serviceCharge.label,
    );
    context.select((PosController p) => (p.orderType, p.discount, p.parkedAmountPaid));
    final layout = context.watch<CartQuickPaySettings>();
    final visiblePay = layout.visibleKeys;
    final activePay =
        visiblePay.contains(_quickPay) ? _quickPay : visiblePay.first;
    final pos = context.read<PosController>();
    final preview = pos.cartTotalsPreview;
    final tax = preview.taxComputation;
    final includedRate = includedTaxRateSum(tax.breakdown);
    final scTaxable =
        pos.bootstrap?.restaurant.serviceCharge.taxable ?? false;
    final displaySubtotal = exclusiveAmount(pos.cartSubtotal, includedRate);
    final displayDiscount = exclusiveAmount(discountAmount, includedRate);
    final displayServiceCharge = scTaxable
        ? exclusiveAmount(preview.serviceChargeAmount, includedRate)
        : preview.serviceChargeAmount;
    final l10n = context.l10n;
    final cartEmpty = pos.cart.isEmpty;
    final alreadyPaid = pos.parkedAmountPaid;
    final showPartial = alreadyPaid > 0.001;
    final payable = pos.cartAmountDue;
    final canPay = !cartEmpty && !submitting && payable > 0.001;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(
          top: BorderSide(
            color: PosTheme.border.withValues(alpha: 0.9),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _TotalRow(
            label: l10n.commonSubtotal,
            value: formatMoney(displaySubtotal, currency),
          ),
          if (displayDiscount > 0)
            _TotalRow(
              label: l10n.discountLabel,
              value: '− ${formatMoney(displayDiscount, currency)}',
              emphasize: true,
            ),
          for (final line in preview.extraChargeLines)
            _TotalRow(
              label: line.label,
              value: formatMoney(
                line.taxable
                    ? exclusiveAmount(line.amount, includedRate)
                    : line.amount,
                currency,
              ),
            ),
          if (displayServiceCharge > 0)
            _TotalRow(
              label: serviceChargeLabel ?? l10n.cartServiceCharge,
              value: formatMoney(displayServiceCharge, currency),
            ),
          if (tax.totalTax > 0)
            _TotalRow(
              label: l10n.cartTax,
              value: formatMoney(tax.totalTax, currency),
            ),
          if (showPartial) ...[
            const SizedBox(height: 4),
            _TotalRow(
              label: context.posText('cartBillTotal', 'Bill total'),
              value: formatMoney(preview.total, currency),
            ),
            _TotalRow(
              label: context.posText('cartAlreadyPaid', 'Already paid'),
              value: '− ${formatMoney(alreadyPaid, currency)}',
              emphasize: true,
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: soft.bg,
              borderRadius: BorderRadius.circular(PosTheme.radiusSm),
              border: Border.all(
                color: accent.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    showPartial
                        ? context.posText('cartRemaining', 'Remaining')
                        : l10n.cartPayable,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: soft.fg,
                    ),
                  ),
                ),
                Text(
                  formatMoney(payable, currency),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: -0.4,
                    color: accent,
                    fontFeatures: const [
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (primaryLabel == null && onPark != null) ...[
            _QuickPayRow(
              selected: activePay,
              enabled: canPay,
              methods: visiblePay,
              onSelected: (value) {
                setState(() => _quickPay = value);
                context.read<PosController>().cartQuickPayMethod = value;
              },
            ),
            const SizedBox(height: 10),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 280;
              final showShortcuts =
                  usePosDesktopLayout(context) && constraints.maxWidth >= 300;
              final payFlex = onPark == null ? 1 : (narrow ? 1 : 2);

              return Row(
                children: [
                  if (onPark != null)
                    Expanded(
                      child: _HoldButton(
                        enabled: !cartEmpty && !submitting,
                        onPressed: onPark,
                        shortcutLabel: showShortcuts ? 'F2' : null,
                      ),
                    ),
                  if (onPark != null) SizedBox(width: narrow ? 6 : 8),
                  Expanded(
                    flex: payFlex,
                    child: PosPrimaryButton(
                      label: primaryLabel ?? l10n.cartPay,
                      icon: primaryIcon ?? Icons.payments_rounded,
                      color: primaryColor ?? PosTheme.payAccent,
                      loading: submitting,
                      shortcutLabel: showShortcuts && primaryLabel == null
                          ? 'F3'
                          : null,
                      onPressed: canPay
                          ? () {
                              if (primaryLabel != null ||
                                  widget.onPayMethod == null ||
                                  activePay == 'more') {
                                onPay?.call();
                                return;
                              }
                              widget.onPayMethod!(activePay);
                            }
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CustomerChip extends StatelessWidget {
  const _CustomerChip({
    required this.accent,
    required this.soft,
    required this.hasCustomer,
    required this.onTap,
    this.name,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final bool hasCustomer;
  final String? name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: hasCustomer ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(PosTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusSm),
            border: Border.all(
              color: hasCustomer
                  ? accent.withValues(alpha: 0.28)
                  : PosTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasCustomer
                    ? Icons.person_rounded
                    : Icons.person_add_alt_1_rounded,
                size: 18,
                color: hasCustomer ? soft.fg : PosTheme.inkMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasCustomer
                      ? (name ?? context.l10n.cartCustomerFallback)
                      : context.l10n.cartAddCustomer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: hasCustomer ? soft.fg : PosTheme.inkMuted,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: hasCustomer ? soft.fg : PosTheme.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog({
    required this.accent,
    required this.onSearch,
    required this.onCreate,
    required this.onApply,
    required this.onClear,
    this.initialCustomerId,
    this.initialCustomerName,
  });

  final Color accent;
  final int? initialCustomerId;
  final String? initialCustomerName;
  final Future<List<Map<String, dynamic>>> Function(String query) onSearch;
  final Future<Map<String, dynamic>> Function({
    required String name,
    String? phone,
    String? email,
  }) onCreate;
  final void Function({int? id, String? name}) onApply;
  final VoidCallback onClear;

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  late final TextEditingController _searchController;
  late final TextEditingController _createNameController;
  late final TextEditingController _createPhoneController;
  late final TextEditingController _createEmailController;
  Timer? _debounce;
  List<Map<String, dynamic>> _results = const [];
  bool _searching = false;
  bool _creating = false;
  bool _createMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _createNameController = TextEditingController();
    _createPhoneController = TextEditingController();
    _createEmailController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runSearch('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _createNameController.dispose();
    _createPhoneController.dispose();
    _createEmailController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.onSearch(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searching = false;
        _error = e.toString();
      });
    }
  }

  void _pick(int? id, String name) {
    widget.onApply(id: id, name: name.trim().isEmpty ? null : name.trim());
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.onClear();
    Navigator.of(context).pop();
  }

  Future<void> _create() async {
    final name = _createNameController.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final customer = await widget.onCreate(
        name: name,
        phone: _createPhoneController.text.trim().isEmpty
            ? null
            : _createPhoneController.text.trim(),
        email: _createEmailController.text.trim().isEmpty
            ? null
            : _createEmailController.text.trim(),
      );
      if (!mounted) return;
      final id = customer['id'];
      final intId = id is int ? id : int.tryParse('$id');
      final customerName =
          customer['name']?.toString().trim().isNotEmpty == true
              ? customer['name'].toString().trim()
              : name;
      widget.onApply(id: intId, name: customerName);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final soft = posAccentSoft(widget.accent);
    final hasCustomer = widget.initialCustomerId != null ||
        (widget.initialCustomerName?.trim().isNotEmpty ?? false);

    return Dialog(
      backgroundColor: PosTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: soft.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _createMode
                          ? Icons.person_add_alt_1_rounded
                          : Icons.person_rounded,
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
                          _createMode
                              ? context.posText(
                                  'cartNewCustomerTitle',
                                  'New customer',
                                )
                              : l10n.cartAddCustomer,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: PosTheme.ink,
                          ),
                        ),
                        Text(
                          _createMode
                              ? context.posText(
                                  'cartNewCustomerHint',
                                  'Saved to your customer list for next time.',
                                )
                              : l10n.cartCustomerSearchHint,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: PosTheme.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    onPressed: _creating
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_createMode)
                Flexible(child: _buildCreateForm(l10n))
              else
                Flexible(child: _buildSearchBody(l10n)),
              const SizedBox(height: 14),
              if (_createMode)
                Row(
                  children: [
                    TextButton(
                      onPressed: _creating
                          ? null
                          : () => setState(() {
                                _createMode = false;
                                _error = null;
                              }),
                      child: Text(
                        context.posText('commonBack', 'Back'),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _creating
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.commonCancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _creating ||
                              _createNameController.text.trim().isEmpty
                          ? null
                          : _create,
                      child: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              context.posText(
                                'cartCreateCustomer',
                                'Create & select',
                              ),
                            ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    if (hasCustomer)
                      TextButton(
                        onPressed: _clear,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                        ),
                        child: Text(l10n.cartClearCustomer),
                      ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        final q = _searchController.text.trim();
                        if (q.isNotEmpty &&
                            _createNameController.text.trim().isEmpty) {
                          _createNameController.text = q;
                        }
                        setState(() {
                          _createMode = true;
                          _error = null;
                        });
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: Text(
                        context.posText('cartNewCustomer', 'New customer'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBody(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.cartCustomerSearchHint,
            filled: true,
            fillColor: PosTheme.surfaceMuted,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.commonClear,
                        onPressed: () {
                          _searchController.clear();
                          _runSearch('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      )),
          ),
          onChanged: (v) {
            setState(() {});
            _onSearchChanged(v);
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PosTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(PosTheme.radiusMd),
              border: Border.all(color: PosTheme.border),
            ),
            child: _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _searching
                            ? l10n.commonLoading
                            : context.posText(
                                'cartCustomerEmpty',
                                'No matches. Create a new customer below.',
                              ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PosTheme.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: PosTheme.border),
                    itemBuilder: (context, index) {
                      final c = _results[index];
                      final id = c['id'];
                      final intId = id is int ? id : int.tryParse('$id');
                      final name = c['name']?.toString() ??
                          l10n.cartCustomerFallback;
                      final phone = c['phone']?.toString();
                      return ListTile(
                        leading: Icon(
                          Icons.person_outline_rounded,
                          color: PosTheme.inkMuted,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: phone != null && phone.isNotEmpty
                            ? Text(phone)
                            : null,
                        onTap: () => _pick(intId, name),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateForm(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _createNameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.posText('adminName', 'Name'),
              filled: true,
              fillColor: PosTheme.surfaceMuted,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _createPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.posText('cartCustomerPhone', 'Phone'),
              filled: true,
              fillColor: PosTheme.surfaceMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _createEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.posText('cartCustomerEmail', 'Email'),
              filled: true,
              fillColor: PosTheme.surfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TablePick {
  const _TablePick(this.id, {this.name});
  final int? id;
  final String? name;
}

class _TablePickerTrigger extends StatelessWidget {
  const _TablePickerTrigger({
    required this.accent,
    required this.soft,
    required this.selectedId,
    required this.label,
    required this.tableCount,
    required this.onTap,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final int? selectedId;
  final String label;
  final int tableCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectedId != null;
    return Material(
      color: selected ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(PosTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusSm),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.35)
                  : PosTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? soft.bg : PosTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? soft.fg.withValues(alpha: 0.28)
                        : PosTheme.border,
                  ),
                ),
                child: Icon(
                  Icons.table_restaurant_rounded,
                  size: 18,
                  color: selected ? soft.fg : PosTheme.inkMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.cartTable,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? soft.fg : PosTheme.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      selected ? label : context.l10n.cartSelectTable,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        color: selected ? soft.fg : PosTheme.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (tableCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PosTheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: PosTheme.border),
                  ),
                  child: Text(
                    '$tableCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ),
              Icon(
                Icons.grid_view_rounded,
                size: 18,
                color: selected ? soft.fg : PosTheme.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TablePickerSheet extends StatelessWidget {
  const _TablePickerSheet({
    required this.accent,
    required this.selectedId,
    required this.tableAreas,
    required this.tablesWithoutArea,
  });

  final Color accent;
  final int? selectedId;
  final List<Map<String, dynamic>> tableAreas;
  final List<Map<String, dynamic>> tablesWithoutArea;

  static List<Map<String, dynamic>> _areaTables(Map<String, dynamic> area) {
    return (area['tables'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const [];
  }

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    final size = MediaQuery.sizeOf(context);
    final maxHeight = posMobileSheetHeight(context);
    final sheetMaxWidth = size.width >= 900 ? 720.0 : size.width;
    final hasAreas = tableAreas.any((a) => _areaTables(a).isNotEmpty);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: sheetMaxWidth,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: PosTheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PosTheme.radiusXl),
            ),
            border: size.width >= 900
                ? Border.all(color: PosTheme.border)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: soft.bg,
                        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Icon(
                        Icons.table_restaurant_rounded,
                        color: soft.fg,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.cartSelectTable,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.2,
                              color: PosTheme.ink,
                            ),
                          ),
                          Text(
                            context.l10n.cartTablesLegend,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: PosTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: PosTheme.border),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: PosTableStatusLegend(),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  shrinkWrap: true,
                  children: [
                    _NoTableTile(
                      accent: accent,
                      selected: selectedId == null,
                      onTap: () =>
                          Navigator.pop(context, const _TablePick(null)),
                    ),
                    if (hasAreas) ...[
                      for (final area in tableAreas) ...[
                        if (_areaTables(area).isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            (area['name']?.toString() ?? 'Area').toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: PosTheme.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 8),
                          PosTableGrid(
                            tables: _areaTables(area),
                            selectedId: selectedId,
                            onTableTap: (table) {
                              final intId = parseJsonIntOrNull(table['id']);
                              Navigator.pop(
                                context,
                                _TablePick(
                                  intId,
                                  name: table['name']?.toString(),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ],
                    if (tablesWithoutArea.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      if (hasAreas)
                        Text(
                          context.l10n.cartTablesOther,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: PosTheme.inkFaint,
                          ),
                        ),
                      if (hasAreas) const SizedBox(height: 8),
                      PosTableGrid(
                        tables: tablesWithoutArea,
                        selectedId: selectedId,
                        onTableTap: (table) {
                          final intId = parseJsonIntOrNull(table['id']);
                          Navigator.pop(
                            context,
                            _TablePick(
                              intId,
                              name: table['name']?.toString(),
                            ),
                          );
                        },
                      ),
                    ],
                    if (!hasAreas && tablesWithoutArea.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: PosEmptyState(
                          icon: Icons.table_bar_outlined,
                          title: context.l10n.cartNoTablesTitle,
                          subtitle: context.l10n.cartNoTablesSubtitle,
                          accent: accent,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoTableTile extends StatelessWidget {
  const _NoTableTile({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? posAccentSoft(accent).bg : Colors.transparent,
      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusMd),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : PosTheme.border,
              width: selected ? 2 : 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.do_not_disturb_alt_rounded,
                size: 18,
                color: selected ? accent : PosTheme.inkMuted,
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.cartNoTable,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: selected ? accent : PosTheme.inkMuted,
                ),
              ),
              const Spacer(),
              if (selected)
                Icon(Icons.check_circle_rounded, color: accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeldBanner extends StatelessWidget {
  const _HeldBanner({
    required this.label,
    this.alreadyPaid = 0,
    this.remaining = 0,
    this.currency = 'USD',
  });

  final String label;
  final double alreadyPaid;
  final double remaining;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(PosTheme.holdAmberDark);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: soft.bg,
        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
        border: Border.all(
          color: soft.fg.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pause_circle_filled_rounded,
            size: 18,
            color: soft.fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.cartHeldTicket(label),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: soft.fg,
                  ),
                ),
                if (alreadyPaid > 0.001) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.posText(
                      'cartPartialBalance',
                      '{paid} paid · {due} remaining',
                      {
                        'paid': formatMoney(alreadyPaid, currency),
                        'due': formatMoney(remaining, currency),
                      },
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: soft.fg.withValues(alpha: 0.9),
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

class _QuickPayRow extends StatelessWidget {
  const _QuickPayRow({
    required this.selected,
    required this.enabled,
    required this.methods,
    required this.onSelected,
  });

  final String selected;
  final bool enabled;
  final List<String> methods;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < methods.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _QuickPayPill(
              label: CartQuickPaySettings.labelFor(context, methods[i]),
              icon: CartQuickPaySettings.iconFor(methods[i]),
              selected: selected == methods[i],
              enabled: enabled,
              onTap: () => onSelected(methods[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickPayPill extends StatelessWidget {
  const _QuickPayPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final tone = posAccentSoft(accent);
    return Material(
      color: selected ? tone.bg : PosTheme.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? accent.withValues(alpha: 0.35) : PosTheme.border,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? tone.fg
                    : (enabled ? PosTheme.inkMuted : PosTheme.inkFaint),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? tone.fg
                      : (enabled ? PosTheme.ink : PosTheme.inkFaint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.enabled,
    this.onPressed,
    this.shortcutLabel,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final String? shortcutLabel;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(PosTheme.holdAmberDark);
    final ink = enabled ? soft.fg : PosTheme.inkFaint;
    final label = context.l10n.cartHold;

    return Material(
      color: enabled ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusMd),
            border: Border.all(
              color: enabled
                  ? soft.fg.withValues(alpha: 0.45)
                  : PosTheme.border,
              width: 1.4,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final showLabel = w >= 72;
              final showShortcut =
                  shortcutLabel != null && shortcutLabel!.isNotEmpty && w >= 108;

              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pause_rounded, size: 18, color: ink),
                    if (showLabel) ...[
                      const SizedBox(width: 5),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: ink,
                        ),
                      ),
                    ],
                    if (showShortcut) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: enabled
                              ? PosTheme.holdAmber.withValues(alpha: 0.22)
                              : PosTheme.surface,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: enabled
                                ? PosTheme.holdAmber.withValues(alpha: 0.45)
                                : PosTheme.border,
                          ),
                        ),
                        child: Text(
                          shortcutLabel!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: ink,
                            letterSpacing: 0.2,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ClearTicketButton extends StatelessWidget {
  const _ClearTicketButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tone = posStatusColors('cancelled');
    return Tooltip(
      message: context.l10n.cartClearTooltip,
      child: Material(
        color: enabled ? tone.bg : PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(PosTheme.radiusSm),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PosTheme.radiusSm),
              border: Border.all(
                color: enabled
                    ? tone.fg.withValues(alpha: 0.28)
                    : PosTheme.border,
              ),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: enabled ? tone.fg : PosTheme.inkFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderDiscountButton extends StatelessWidget {
  const _HeaderDiscountButton({
    required this.accent,
    required this.active,
    required this.onPressed,
  });

  final Color accent;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Tooltip(
      message: context.l10n.discountLabel,
      child: Material(
        color: active ? soft.bg : PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(PosTheme.radiusSm),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PosTheme.radiusSm),
              border: Border.all(
                color: active
                    ? accent.withValues(alpha: 0.35)
                    : PosTheme.border,
              ),
            ),
            child: Icon(
              Icons.percent_rounded,
              size: 20,
              color: active ? soft.fg : PosTheme.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PosEmptyState(
      icon: Icons.receipt_long_outlined,
      title: l10n.cartEmptyPanelTitle,
      subtitle: l10n.cartEmptyPanelSubtitle,
      accent: Theme.of(context).colorScheme.primary,
    );
  }
}

class _LockedServiceContext extends StatelessWidget {
  const _LockedServiceContext({
    required this.orderType,
    required this.accent,
    required this.soft,
    this.tableLabel,
  });

  final String orderType;
  final String? tableLabel;
  final Color accent;
  final ({Color bg, Color fg}) soft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typeLabel = switch (orderType) {
      'takeaway' => l10n.orderTypeTakeaway,
      'delivery' => l10n.orderTypeDelivery,
      _ => l10n.orderTypeDineIn,
    };
    final typeIcon = switch (orderType) {
      'takeaway' => Icons.shopping_bag_outlined,
      'delivery' => Icons.delivery_dining_rounded,
      _ => Icons.restaurant_rounded,
    };

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: soft.bg,
            borderRadius: BorderRadius.circular(PosTheme.radiusSm),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Icon(typeIcon, size: 18, color: soft.fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: soft.fg,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (tableLabel != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: PosTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(PosTheme.radiusSm),
              border: Border.all(color: PosTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.table_restaurant_rounded,
                  size: 18,
                  color: PosTheme.inkMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tableLabel!,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: PosTheme.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderTypeRow extends StatelessWidget {
  const _OrderTypeRow({
    required this.value,
    required this.onChanged,
    required this.accent,
    this.allowedTypes = const ['dine_in', 'takeaway', 'delivery'],
    this.iconOnly = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final Color accent;
  final List<String> allowedTypes;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allTypes = [
      ('dine_in', l10n.orderTypeDineIn, Icons.restaurant_rounded),
      ('takeaway', l10n.orderTypeTakeaway, Icons.shopping_bag_outlined),
      ('delivery', l10n.orderTypeDelivery, Icons.delivery_dining_rounded),
    ];
    final types =
        allTypes.where((type) => allowedTypes.contains(type.$1)).toList();
    final soft = posAccentSoft(accent);

    if (types.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        children: types.map((type) {
          final selected = value == type.$1;
          return Expanded(
            child: Material(
              color: selected ? PosTheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(PosTheme.radiusSm),
              child: InkWell(
                onTap: () => onChanged(type.$1),
                borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.symmetric(
                    vertical: iconOnly ? 6 : 9,
                    horizontal: iconOnly ? 4 : 0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                    border: selected
                        ? Border.all(color: accent.withValues(alpha: 0.28))
                        : null,
                    boxShadow: selected && !iconOnly
                        ? PosTheme.cardShadow(accent)
                        : null,
                  ),
                  child: iconOnly
                      ? Icon(
                          type.$3,
                          size: 16,
                          color: selected ? soft.fg : PosTheme.inkMuted,
                        )
                      : Column(
                          children: [
                            Icon(
                              type.$3,
                              size: 17,
                              color: selected ? soft.fg : PosTheme.inkMuted,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              type.$2,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected ? soft.fg : PosTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SplitServiceRow extends StatelessWidget {
  const _SplitServiceRow({
    required this.accent,
    required this.soft,
    required this.orderType,
    required this.allowedTypes,
    required this.onOrderTypeChanged,
    required this.hasCustomer,
    required this.onCustomerTap,
    this.tableLabel,
    this.tableCount = 0,
    this.onTableTap,
    this.customerName,
    this.canClear = false,
    this.onClear,
    this.showDiscount = false,
    this.hasDiscount = false,
    this.onDiscount,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final String orderType;
  final List<String> allowedTypes;
  final ValueChanged<String> onOrderTypeChanged;
  final bool hasCustomer;
  final VoidCallback onCustomerTap;
  final String? tableLabel;
  final int tableCount;
  final VoidCallback? onTableTap;
  final String? customerName;
  final bool canClear;
  final VoidCallback? onClear;
  final bool showDiscount;
  final bool hasDiscount;
  final VoidCallback? onDiscount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderTypeRow(
          value: orderType,
          onChanged: onOrderTypeChanged,
          accent: accent,
          allowedTypes: allowedTypes,
          iconOnly: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MiniContextChip(
                icon: hasCustomer
                    ? Icons.person_rounded
                    : Icons.person_add_alt_1_rounded,
                label: hasCustomer
                    ? (customerName ?? context.l10n.cartCustomerFallback)
                    : context.l10n.cartAddCustomer,
                accent: accent,
                emphasized: hasCustomer,
                onTap: onCustomerTap,
              ),
            ),
            if (showDiscount) ...[
              const SizedBox(width: 8),
              _HeaderDiscountButton(
                accent: accent,
                active: hasDiscount,
                onPressed: onDiscount,
              ),
            ],
            const SizedBox(width: 8),
            _ClearTicketButton(
              enabled: canClear,
              onPressed: canClear ? onClear : null,
            ),
            if (orderType == 'dine_in' && onTableTap != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _MiniContextChip(
                  icon: Icons.table_restaurant_rounded,
                  label: tableLabel ?? context.l10n.cartSelectTable,
                  accent: accent,
                  emphasized: tableLabel != null &&
                      tableLabel != context.l10n.cartSelectTable,
                  onTap: onTableTap!,
                  badge: tableCount > 0 ? '$tableCount' : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _MiniContextChip extends StatelessWidget {
  const _MiniContextChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.emphasized = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool emphasized;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Material(
      color: emphasized ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(PosTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusSm),
            border: Border.all(
              color: emphasized
                  ? accent.withValues(alpha: 0.28)
                  : PosTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: emphasized ? soft.fg : PosTheme.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    color: emphasized ? soft.fg : PosTheme.ink,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent,
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

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({
    super.key,
    required this.line,
    required this.currency,
    required this.accent,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onNotesChanged,
  });

  final CartLine line;
  final String currency;
  final Color accent;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final ValueChanged<String> onNotesChanged;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    final modifiers = line.selectedModifiers.map((m) => m.name).join(', ');
    final lang = Localizations.localeOf(context).languageCode;
    final lineName = line.displayNameFor(lang);
    final hasNote = line.notes?.trim().isNotEmpty == true;

    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PosTheme.radiusMd),
          border: Border.all(color: PosTheme.border),
          boxShadow: PosTheme.cardShadow(),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(PosTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 42,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: PosTheme.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${line.quantity}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: PosTheme.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (normalizePosItemType(
                                    line.menuItem.itemType,
                                  ) !=
                                  null) ...[
                                PosItemTypeMark(
                                  type: line.menuItem.itemType!,
                                  size: 13,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  lineName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    letterSpacing: -0.15,
                                    color: PosTheme.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!expanded && modifiers.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                modifiers,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: PosTheme.inkMuted,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          if (!expanded && hasNote)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                line.notes!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  color: PosTheme.holdAmberDark
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatMoney(line.lineTotal, currency),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: soft.fg,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CartLineRemoveButton(onTap: onRemove),
                  ],
                ),
              ),
            ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (modifiers.isNotEmpty) ...[
                    Text(
                      modifiers,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: PosTheme.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 300;
                      final quantity = _LabeledField(
                        label: context.posText('cartLineQty', 'Quantity'),
                        child: _QtyStepper(
                          quantity: line.quantity,
                          accent: accent,
                          onDecrement: onDecrement,
                          onIncrement: onIncrement,
                        ),
                      );
                      final price = _LabeledField(
                        label: context.posText(
                          'cartLineUnitPrice',
                          'Unit price',
                        ),
                        child: _UnitPriceBox(
                          value: formatMoney(line.unitPrice, currency),
                        ),
                      );
                      if (stacked) {
                        return Column(
                          children: [
                            quantity,
                            const SizedBox(height: 10),
                            price,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: quantity),
                          const SizedBox(width: 12),
                          Expanded(child: price),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _CartLineNoteField(
                    initialValue: line.notes ?? '',
                    onChanged: onNotesChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: PosTheme.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _UnitPriceBox extends StatelessWidget {
  const _UnitPriceBox({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        border: Border.all(color: PosTheme.border.withValues(alpha: 0.7)),
      ),
      child: Text(
        value,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: PosTheme.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _CartLineRemoveButton extends StatelessWidget {
  const _CartLineRemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = posStatusColors('cancelled');
    return Tooltip(
      message: context.l10n.cartRemoveLine,
      child: Material(
        color: tone.bg,
        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PosTheme.radiusSm),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PosTheme.radiusSm),
              border: Border.all(color: tone.fg.withValues(alpha: 0.28)),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: tone.fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _CartLineNoteField extends StatefulWidget {
  const _CartLineNoteField({
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_CartLineNoteField> createState() => _CartLineNoteFieldState();
}

class _CartLineNoteFieldState extends State<_CartLineNoteField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _CartLineNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        !_controller.value.composing.isValid &&
        !FocusScope.of(context).hasFocus) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      onEditingComplete: () {
        _debounce?.cancel();
        widget.onChanged(_controller.text);
        FocusScope.of(context).unfocus();
      },
      textInputAction: TextInputAction.done,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: PosTheme.ink,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: context.posText('cartItemNoteHint', 'Add line note'),
        hintStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: PosTheme.inkFaint,
        ),
        prefixIcon: Icon(
          Icons.chat_bubble_outline_rounded,
          size: 16,
          color: PosTheme.inkMuted,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        filled: true,
        fillColor: PosTheme.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: PosTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.accent,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final Color accent;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        children: [
          _QtyButton(
            icon: Icons.remove_rounded,
            accent: accent,
            onTap: onDecrement,
          ),
          Expanded(
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: soft.fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _QtyButton(
            icon: Icons.add_rounded,
            accent: accent,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(PosTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
        child: Container(
          width: 40,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusSm),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 18, color: soft.fg),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? Colors.red.shade600 : PosTheme.inkMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: color,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: emphasize ? Colors.red.shade600 : PosTheme.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
