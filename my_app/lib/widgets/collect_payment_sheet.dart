import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../theme/pos_theme.dart';
import '../utils/json_parse.dart';
import 'cash_register_sheet.dart';
import 'pos_ui.dart';
import 'split_bill_sheet.dart';

enum CollectPaymentMode { full, split }

/// Unified collect-payment dialog: Full amount | Split payments.
///
/// Returns [PaymentSubmission] when full amount is confirmed, or `true` when
/// split multi-pay finishes the bill. `null` if dismissed unpaid.
///
/// For cart checkout, pass [cartTotal] + [createUnpaidOrder] instead of [order].
/// Choosing Split creates an unpaid ticket once, then opens the split UI.
class CollectPaymentSheet extends StatefulWidget {
  const CollectPaymentSheet({
    super.key,
    this.order,
    this.cartTotal,
    this.createUnpaidOrder,
    required this.currency,
    required this.tipSettings,
    this.paymentGateways = const [],
    this.orderLabel,
    this.orderDetail,
    this.initialMode,
    this.offlineMode = false,
    this.allowSplit = true,
    this.initialPaymentMethod,
  }) : assert(
          order != null || cartTotal != null,
          'Provide an existing order or a cart total for checkout.',
        );

  final Map<String, dynamic>? order;
  final double? cartTotal;

  /// Creates a pay-later / unpaid POS ticket when Split is chosen from cart.
  final Future<Map<String, dynamic>> Function()? createUnpaidOrder;

  final String currency;
  final TipSettings tipSettings;
  final List<PaymentGatewayOption> paymentGateways;
  final String? orderLabel;
  final String? orderDetail;
  final CollectPaymentMode? initialMode;
  final bool offlineMode;

  /// When false (e.g. offline cart), only Full amount is available.
  final bool allowSplit;

  /// Pre-select cash / card / a gateway slug in the full-amount pane.
  final String? initialPaymentMethod;

  static CollectPaymentMode defaultModeForOrder(Map<String, dynamic> order) {
    final alreadyPartial = '${order['payment_status']}' == 'partial' ||
        parseJsonDouble(order['amount_paid']) > 0.001;
    final billRequest = order['bill_request'] is Map
        ? Map<String, dynamic>.from(order['bill_request'] as Map)
        : null;
    if (alreadyPartial || billRequest?['is_split'] == true) {
      return CollectPaymentMode.split;
    }
    return CollectPaymentMode.full;
  }

  static Future<Object?> open(
    BuildContext context, {
    required Map<String, dynamic> order,
    required String currency,
    TipSettings tipSettings = const TipSettings(),
    List<PaymentGatewayOption> paymentGateways = const [],
    String? orderLabel,
    String? orderDetail,
    CollectPaymentMode? initialMode,
  }) {
    return _present(
      context,
      CollectPaymentSheet(
        order: order,
        currency: currency,
        tipSettings: tipSettings,
        paymentGateways: paymentGateways,
        orderLabel: orderLabel,
        orderDetail: orderDetail,
        initialMode: initialMode,
        allowSplit: true,
      ),
    );
  }

  /// Cart Pay — Full amount charges the cart; Split creates an unpaid ticket first.
  static Future<Object?> openForCart(
    BuildContext context, {
    required double total,
    required Future<Map<String, dynamic>> Function() createUnpaidOrder,
    required String currency,
    TipSettings tipSettings = const TipSettings(),
    List<PaymentGatewayOption> paymentGateways = const [],
    String? orderLabel,
    String? orderDetail,
    bool offlineMode = false,
    String? initialPaymentMethod,
  }) {
    return _present(
      context,
      CollectPaymentSheet(
        cartTotal: total,
        createUnpaidOrder: createUnpaidOrder,
        currency: currency,
        tipSettings: tipSettings,
        paymentGateways: paymentGateways,
        orderLabel: orderLabel,
        orderDetail: orderDetail,
        offlineMode: offlineMode,
        allowSplit: !offlineMode,
        initialMode: CollectPaymentMode.full,
        initialPaymentMethod: initialPaymentMethod,
      ),
    );
  }

  static Future<Object?> _present(
    BuildContext context,
    CollectPaymentSheet sheet,
  ) {
    final compact =
        MediaQuery.sizeOf(context).width < PosTheme.compactWidthBreakpoint;

    if (compact) {
      return Navigator.of(context, rootNavigator: true).push<Object>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => sheet,
        ),
      );
    }

    return showDialog<Object>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => sheet,
    );
  }

  @override
  State<CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends State<CollectPaymentSheet> {
  late CollectPaymentMode _mode;
  Map<String, dynamic>? _order;
  bool _creatingSplitOrder = false;
  String? _splitCreateError;

  @override
  void initState() {
    super.initState();
    _order = widget.order == null
        ? null
        : Map<String, dynamic>.from(widget.order!);
    final allowSplit = widget.allowSplit;
    final preferred = widget.initialMode ??
        (_order != null
            ? CollectPaymentSheet.defaultModeForOrder(_order!)
            : CollectPaymentMode.full);
    _mode = (!allowSplit && preferred == CollectPaymentMode.split)
        ? CollectPaymentMode.full
        : preferred;
  }

  bool get _isFullscreenRoute {
    final route = ModalRoute.of(context);
    return route is PageRoute && route.fullscreenDialog;
  }

  bool get _isCartCheckout => widget.order == null;

  double get _due {
    if (_order != null) {
      return parseJsonDouble(_order!['amount_due'] ?? _order!['total']);
    }
    return widget.cartTotal ?? 0;
  }

  void _close() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _onModeChanged(CollectPaymentMode mode) async {
    if (mode == _mode || _creatingSplitOrder) return;

    if (mode == CollectPaymentMode.split && !widget.allowSplit) {
      return;
    }

    if (mode == CollectPaymentMode.split &&
        _order == null &&
        widget.createUnpaidOrder != null) {
      setState(() {
        _creatingSplitOrder = true;
        _splitCreateError = null;
        _mode = CollectPaymentMode.split;
      });
      try {
        final created = await widget.createUnpaidOrder!();
        if (!mounted) return;
        setState(() {
          _order = Map<String, dynamic>.from(created);
          _creatingSplitOrder = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _creatingSplitOrder = false;
          _mode = CollectPaymentMode.full;
          _splitCreateError = e.toString();
        });
        showPosErrorSnackBar(context, e);
      }
      return;
    }

    setState(() {
      _mode = mode;
      _splitCreateError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(940.0, size.width - 28);
    final dialogHeight = math.min(size.height - 40, 780.0);
    final label = widget.orderLabel ??
        _order?['order_number']?.toString() ??
        (_order != null ? '#${_order!['id'] ?? ''}' : l10n.payCollectPayment);
    final detail = widget.orderDetail?.trim();
    final subtitle = [
      label,
      if (detail != null && detail.isNotEmpty) detail,
    ].join(' · ');

    final header = Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(
          bottom: BorderSide(color: PosTheme.border.withValues(alpha: 0.9)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PosTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PosTheme.border),
                ),
                child: Icon(
                  Icons.payments_rounded,
                  color: PosTheme.inkMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.payCollectPayment,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: PosTheme.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: PosTheme.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _creatingSplitOrder ? null : _close,
                tooltip: l10n.commonClose,
                color: PosTheme.inkMuted,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (widget.allowSplit) ...[
            const SizedBox(height: 12),
            _ModeToggle(
              mode: _mode,
              fullLabel: l10n.collectModeFull,
              splitLabel: l10n.collectModeSplit,
              enabled: !_creatingSplitOrder,
              onChanged: _onModeChanged,
            ),
          ],
        ],
      ),
    );

    final body = Expanded(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey('${_mode}_${_order?['id'] ?? 'cart'}'),
          child: _buildBody(),
        ),
      ),
    );

    final content = Column(
      children: [
        header,
        body,
      ],
    );

    if (_isFullscreenRoute) {
      return Scaffold(
        backgroundColor: PosTheme.surface,
        body: SafeArea(child: content),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: Material(
          color: PosTheme.surface,
          elevation: 24,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosTheme.radiusXl),
            side: BorderSide(
              color: PosTheme.border.withValues(alpha: 0.7),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_mode == CollectPaymentMode.full) {
      // After Split created a ticket, Full amount charges that open order.
      return CashRegisterSheet(
        total: _due,
        currency: widget.currency,
        tipSettings: widget.tipSettings,
        paymentGateways: widget.paymentGateways,
        embedded: true,
        showPayLater: _isCartCheckout && _order == null,
        offlineMode: widget.offlineMode,
        initialMethod: widget.initialPaymentMethod,
      );
    }

    if (_creatingSplitOrder) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_order == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            _splitCreateError ??
                context.l10n.splitBillLoadFailed,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PosTheme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SplitBillSheet(
      order: _order!,
      currency: widget.currency,
      paymentGateways: widget.paymentGateways,
      embedded: true,
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.fullLabel,
    required this.splitLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final CollectPaymentMode mode;
  final String fullLabel;
  final String splitLabel;
  final ValueChanged<CollectPaymentMode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: PosTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ModeSegment(
                selected: mode == CollectPaymentMode.full,
                icon: Icons.bolt_rounded,
                label: fullLabel,
                onTap: enabled
                    ? () => onChanged(CollectPaymentMode.full)
                    : null,
              ),
            ),
            Expanded(
              child: _ModeSegment(
                selected: mode == CollectPaymentMode.split,
                icon: Icons.call_split_rounded,
                label: splitLabel,
                onTap: enabled
                    ? () => onChanged(CollectPaymentMode.split)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PosTheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? PosTheme.border : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? PosTheme.ink : PosTheme.inkMuted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: -0.1,
                    color: selected ? PosTheme.ink : PosTheme.inkMuted,
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
