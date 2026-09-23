import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import 'pos_ui.dart';

class PaymentSubmission {
  const PaymentSubmission({
    required this.method,
    this.cashTendered,
    this.tip,
  });

  final String method;
  final double? cashTendered;
  final double? tip;
}

class CashRegisterSheet extends StatefulWidget {
  const CashRegisterSheet({
    super.key,
    required this.total,
    required this.currency,
    required this.tipSettings,
    this.paymentGateways = const [],
    this.offlineMode = false,
    this.orderLabel,
    this.orderDetail,
    this.embedded = false,
    this.showPayLater = true,
    this.initialMethod,
  });

  final double total;
  final String currency;
  final TipSettings tipSettings;
  final List<PaymentGatewayOption> paymentGateways;

  /// When true, QR / gateway methods are hidden (cash & external only).
  final bool offlineMode;

  /// e.g. order number / token shown in the header.
  final String? orderLabel;

  /// Secondary line (table, customer, item count).
  final String? orderDetail;

  /// When true, render body+footer only (parent owns dialog chrome).
  final bool embedded;

  /// Show the pay-later method (hidden for collect-on-existing-order).
  final bool showPayLater;

  /// Pre-select a method (cash / card / gateway slug).
  final String? initialMethod;

  static Future<PaymentSubmission?> show(
    BuildContext context, {
    required double total,
    required String currency,
    TipSettings tipSettings = const TipSettings(),
    List<PaymentGatewayOption> paymentGateways = const [],
    bool offlineMode = false,
    String? orderLabel,
    String? orderDetail,
  }) {
    final compact =
        MediaQuery.sizeOf(context).width < PosTheme.compactWidthBreakpoint;
    final sheet = CashRegisterSheet(
      total: total,
      currency: currency,
      tipSettings: tipSettings,
      paymentGateways: paymentGateways,
      offlineMode: offlineMode,
      orderLabel: orderLabel,
      orderDetail: orderDetail,
      showPayLater: true,
    );

    if (compact) {
      return Navigator.of(context, rootNavigator: true).push<PaymentSubmission>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => sheet,
        ),
      );
    }

    return showDialog<PaymentSubmission>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => sheet,
    );
  }

  @override
  State<CashRegisterSheet> createState() => _CashRegisterSheetState();
}

class _CashRegisterSheetState extends State<CashRegisterSheet> {
  String _method = 'cash';
  String _tipMode = 'none';
  double? _tipPercent;
  final _tipCustomController = TextEditingController();
  final _cashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final preferred = widget.initialMethod?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      _method = preferred;
    }
    _cashController.text = _formatAmount(widget.total);
  }

  @override
  void dispose() {
    _tipCustomController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  double get _tipAmount {
    if (!widget.tipSettings.enabled) return 0;
    if (_tipMode == 'percent' && _tipPercent != null) {
      return _round2((widget.total * _tipPercent!) / 100);
    }
    if (_tipMode == 'custom') {
      return _round2(
        (double.tryParse(_tipCustomController.text.trim()) ?? 0)
            .clamp(0.0, double.infinity),
      );
    }
    return 0;
  }

  double get _grandTotal => _round2(widget.total + _tipAmount);

  double get _tenderNum => double.tryParse(_cashController.text.trim()) ?? 0;

  double get _change =>
      _round2((_tenderNum - _grandTotal).clamp(0.0, double.infinity));

  bool get _canSubmitCash =>
      _method != 'cash' || _tenderNum + 0.0001 >= _grandTotal;

  String _formatAmount(double n) => n.toStringAsFixed(2);

  double _round2(double n) => (n * 100).roundToDouble() / 100;

  void _setExact() {
    _cashController.text = _formatAmount(_grandTotal);
    setState(() {});
  }

  void _quickAdd(double delta) {
    _cashController.text = _formatAmount(_round2(_tenderNum + delta));
    setState(() {});
  }

  void _syncCashIfNeeded() {
    if (_method == 'cash') {
      _cashController.text = _formatAmount(_grandTotal);
    }
  }

  void _close() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _submit() {
    if (_method == 'cash' && !_canSubmitCash) return;
    final methods = _methods;
    final method = methods.any((m) => m.id == _method)
        ? _method
        : methods.first.id;
    Navigator.of(context, rootNavigator: true).pop(
      PaymentSubmission(
        method: method,
        cashTendered: method == 'cash' ? _round2(_tenderNum) : null,
        tip: _tipAmount > 0 ? _tipAmount : null,
      ),
    );
  }

  bool get _isFullscreenRoute {
    final route = ModalRoute.of(context);
    return route is PageRoute && route.fullscreenDialog;
  }

  List<_PayMethod> get _methods {
    final l10n = context.l10n;
    final gateways = widget.offlineMode
        ? const <_PayMethod>[]
        : widget.paymentGateways.map((gateway) {
            final label = switch (gateway.slug) {
              'phonepe' || 'paytm' => 'UPI QR',
              _ => gateway.label,
            };
            return _PayMethod(
              id: gateway.slug,
              label: label,
              subtitle: l10n.payUpiQr,
              icon: Icons.qr_code_2_rounded,
            );
          });

    return [
      _PayMethod(
        id: 'cash',
        label: l10n.payCash,
        subtitle: l10n.payCashSubtitle,
        icon: Icons.payments_outlined,
      ),
      _PayMethod(
        id: 'card',
        label: l10n.payCard,
        subtitle: l10n.payCardSubtitle,
        icon: Icons.credit_card_rounded,
      ),
      _PayMethod(
        id: 'wallet',
        label: l10n.payWallet,
        subtitle: l10n.payWalletSubtitle,
        icon: Icons.account_balance_wallet_outlined,
      ),
      _PayMethod(
        id: 'other',
        label: l10n.payOther,
        subtitle: l10n.payOtherSubtitle,
        icon: Icons.more_horiz_rounded,
      ),
      ...gateways,
      if (!widget.offlineMode && widget.showPayLater)
        _PayMethod(
          id: 'pay_later',
          label: l10n.payLater,
          subtitle: l10n.payLaterSubtitle,
          icon: Icons.schedule_rounded,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 780;
    final tipsEnabled = widget.tipSettings.enabled && widget.total > 0;
    final presets = widget.tipSettings.presets;
    final dialogWidth = math.min(920.0, size.width - 32);
    final maxBodyHeight = _isFullscreenRoute
        ? size.height
        : math.max(280.0, size.height * 0.88 - 140);
    final methods = _methods;
    final selected =
        methods.cast<_PayMethod?>().firstWhere(
              (m) => m?.id == _method,
              orElse: () => null,
            ) ??
            methods.first;

    final amountCard = _AmountDueCard(
      grandTotal: _grandTotal,
      total: widget.total,
      tipAmount: _tipAmount,
      currency: widget.currency,
      accent: accent,
      orderLabel: widget.orderLabel,
      orderDetail: widget.orderDetail,
    );

    final tipSection = tipsEnabled
        ? _TipSection(
            currency: widget.currency,
            tipAmount: _tipAmount,
            tipMode: _tipMode,
            tipPercent: _tipPercent,
            presets: presets,
            tipCustomController: _tipCustomController,
            accent: accent,
            onTipNone: () => setState(() {
              _tipMode = 'none';
              _tipPercent = null;
              _tipCustomController.clear();
              _syncCashIfNeeded();
            }),
            onTipPercent: (p) => setState(() {
              _tipMode = 'percent';
              _tipPercent = p;
              _tipCustomController.clear();
              _syncCashIfNeeded();
            }),
            onTipCustomFocus: () => setState(() {
              _tipMode = 'custom';
              _tipPercent = null;
            }),
            onTipCustomChanged: (_) => setState(() {
              _tipMode = 'custom';
              _tipPercent = null;
              _syncCashIfNeeded();
            }),
          )
        : null;

    final methodGrid = _MethodGrid(
      methods: methods,
      selectedId: _method,
      accent: accent,
      soft: soft,
      onSelect: (id) => setState(() {
        _method = id;
        if (id == 'cash') {
          _cashController.text = _formatAmount(_grandTotal);
        }
      }),
    );

    final detailPanel = _method == 'cash'
        ? _CashPanel(
            cashController: _cashController,
            canSubmitCash: _canSubmitCash,
            change: _change,
            currency: widget.currency,
            accent: accent,
            onExact: _setExact,
            onQuickAdd: _quickAdd,
            onClear: () {
              _cashController.clear();
              setState(() {});
            },
            onChanged: (_) => setState(() {}),
          )
        : _MethodDetailPanel(
            method: selected,
            amount: formatMoney(_grandTotal, widget.currency),
            accent: accent,
            soft: soft,
          );

    final leftColumn = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 22 : 16, 16, wide ? 18 : 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          amountCard,
          if (tipSection != null) ...[
            const SizedBox(height: 14),
            tipSection,
          ],
          const SizedBox(height: 14),
          methodGrid,
        ],
      ),
    );

    final rightColumn = Container(
      color: PosTheme.canvas,
      padding: EdgeInsets.fromLTRB(wide ? 18 : 16, 16, wide ? 22 : 16, 16),
      child: detailPanel,
    );

    final footer = _DialogFooter(
      method: _method,
      amountLabel: formatMoney(_grandTotal, widget.currency),
      canSubmit: _method != 'cash' || _canSubmitCash,
      onCancel: _close,
      onSubmit: _submit,
      accent: accent,
    );

    final header = _DialogHeader(
      onClose: _close,
      subtitle: selected.label,
      orderLabel: widget.orderLabel,
      orderDetail: widget.orderDetail,
    );

    final bodyPane = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: SingleChildScrollView(child: leftColumn),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: PosTheme.border,
              ),
              Expanded(
                flex: 4,
                child: SingleChildScrollView(child: rightColumn),
              ),
            ],
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftColumn,
                Divider(height: 1, color: PosTheme.border),
                rightColumn,
              ],
            ),
          );

    if (widget.embedded) {
      return Column(
        children: [
          Expanded(child: bodyPane),
          footer,
        ],
      );
    }

    if (_isFullscreenRoute) {
      return Scaffold(
        backgroundColor: PosTheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              header,
              Expanded(child: bodyPane),
              footer,
            ],
          ),
        ),
      );
    }

    // Desktop dialog: fixed body height + two independently scrolling panes.
    // Avoid IntrinsicHeight inside ScrollView (unbounded height → broken layout).
    final bodyHeight = math.min(maxBodyHeight, 620.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: size.height - 48,
        ),
        child: Material(
          color: PosTheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosTheme.radiusXl),
            side: BorderSide(color: PosTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                SizedBox(height: bodyHeight, child: bodyPane),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayMethod {
  const _PayMethod({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.onClose,
    required this.subtitle,
    this.orderLabel,
    this.orderDetail,
  });

  final VoidCallback onClose;
  final String subtitle;
  final String? orderLabel;
  final String? orderDetail;

  @override
  Widget build(BuildContext context) {
    final hasOrder = orderLabel != null && orderLabel!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(
          bottom: BorderSide(color: PosTheme.border.withValues(alpha: 0.9)),
        ),
      ),
      child: Row(
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
              Icons.point_of_sale_rounded,
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
                  hasOrder
                      ? context.l10n.payCollectPayment
                      : context.l10n.payTakePayment,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: PosTheme.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasOrder
                      ? [
                          orderLabel!.trim(),
                          if (orderDetail != null &&
                              orderDetail!.trim().isNotEmpty)
                            orderDetail!.trim(),
                        ].join(' · ')
                      : subtitle,
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
            onPressed: onClose,
            tooltip: context.l10n.commonClose,
            color: PosTheme.inkMuted,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _AmountDueCard extends StatelessWidget {
  const _AmountDueCard({
    required this.grandTotal,
    required this.total,
    required this.tipAmount,
    required this.currency,
    required this.accent,
    this.orderLabel,
    this.orderDetail,
  });

  final double grandTotal;
  final double total;
  final double tipAmount;
  final String currency;
  final Color accent;
  final String? orderLabel;
  final String? orderDetail;

  @override
  Widget build(BuildContext context) {
    final hasOrder = orderLabel != null && orderLabel!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      decoration: BoxDecoration(
        color: Color.lerp(PosTheme.surfaceMuted, accent, 0.06),
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        children: [
          if (hasOrder) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: PosTheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: PosTheme.border),
              ),
              child: Text(
                [
                  orderLabel!.trim(),
                  if (orderDetail != null && orderDetail!.trim().isNotEmpty)
                    orderDetail!.trim(),
                ].join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PosTheme.inkMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            context.l10n.payAmountDue,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: PosTheme.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(grandTotal, currency),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: PosTheme.ink,
              height: 1,
              letterSpacing: -0.6,
            ),
          ),
          if (tipAmount > 0) ...[
            const SizedBox(height: 10),
            Text(
              context.l10n.payAmountWithTip(
                formatMoney(tipAmount, currency),
                formatMoney(total, currency),
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PosTheme.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TipSection extends StatelessWidget {
  const _TipSection({
    required this.currency,
    required this.tipAmount,
    required this.tipMode,
    required this.tipPercent,
    required this.presets,
    required this.tipCustomController,
    required this.accent,
    required this.onTipNone,
    required this.onTipPercent,
    required this.onTipCustomFocus,
    required this.onTipCustomChanged,
  });

  final String currency;
  final double tipAmount;
  final String tipMode;
  final double? tipPercent;
  final List<double> presets;
  final TextEditingController tipCustomController;
  final Color accent;
  final VoidCallback onTipNone;
  final ValueChanged<double> onTipPercent;
  final VoidCallback onTipCustomFocus;
  final ValueChanged<String> onTipCustomChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism_outlined,
                  size: 16, color: PosTheme.inkMuted),
              const SizedBox(width: 8),
              Text(
                context.l10n.payTip,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: PosTheme.ink,
                ),
              ),
              const Spacer(),
              if (tipAmount > 0)
                Text(
                  '+ ${formatMoney(tipAmount, currency)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TipChip(
                label: context.l10n.payTipNone,
                selected: tipMode == 'none',
                accent: accent,
                onTap: onTipNone,
              ),
              ...presets.map(
                (pct) => _TipChip(
                  label:
                      '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%',
                  selected: tipMode == 'percent' && tipPercent == pct,
                  accent: accent,
                  onTap: () => onTipPercent(pct),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: tipCustomController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onTap: onTipCustomFocus,
            onChanged: onTipCustomChanged,
            decoration: InputDecoration(
              labelText: context.l10n.payTipCustom,
              hintText: '0.00',
              isDense: true,
              filled: true,
              fillColor: PosTheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: tipMode == 'custom' ? accent : PosTheme.border,
                  width: tipMode == 'custom' ? 2 : 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: tipMode == 'custom' ? accent : PosTheme.border,
                  width: tipMode == 'custom' ? 2 : 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : PosTheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : PosTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? Colors.white : PosTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodGrid extends StatelessWidget {
  const _MethodGrid({
    required this.methods,
    required this.selectedId,
    required this.accent,
    required this.soft,
    required this.onSelect,
  });

  final List<_PayMethod> methods;
  final String selectedId;
  final Color accent;
  final ({Color bg, Color fg}) soft;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.payMethodLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: PosTheme.ink,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 420 ? 3 : 2;
            final tileWidth =
                (width - (columns - 1) * 10) / columns;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: methods.map((m) {
                final active = selectedId == m.id;
                return SizedBox(
                  width: tileWidth,
                  child: Material(
                    color: active
                        ? Color.lerp(PosTheme.surface, soft.bg, 0.35)!
                        : PosTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => onSelect(m.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active
                                ? accent.withValues(alpha: 0.28)
                                : PosTheme.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              m.icon,
                              size: 22,
                              color: active ? PosTheme.ink : PosTheme.inkMuted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              m.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: active ? PosTheme.ink : PosTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: PosTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _MethodDetailPanel extends StatelessWidget {
  const _MethodDetailPanel({
    required this.method,
    required this.amount,
    required this.accent,
    required this.soft,
  });

  final _PayMethod method;
  final String amount;
  final Color accent;
  final ({Color bg, Color fg}) soft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPayLater = method.id == 'pay_later';
    final isQr = method.id == 'phonepe' || method.id == 'paytm';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: PosTheme.border),
        boxShadow: PosTheme.cardShadow(),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: soft.bg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(method.icon, color: soft.fg, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            isPayLater
                ? l10n.payPlaceWithout
                : isQr
                    ? l10n.payShowQr
                    : l10n.payConfirmMethod(method.label),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 28,
              color: accent,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPayLater
                ? l10n.payLaterHelp
                : isQr
                    ? l10n.payQrHelp
                    : l10n.payTerminalHelp,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PosTheme.inkMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashPanel extends StatelessWidget {
  const _CashPanel({
    required this.cashController,
    required this.canSubmitCash,
    required this.change,
    required this.currency,
    required this.accent,
    required this.onExact,
    required this.onQuickAdd,
    required this.onClear,
    required this.onChanged,
  });

  final TextEditingController cashController;
  final bool canSubmitCash;
  final double change;
  final String currency;
  final Color accent;
  final VoidCallback onExact;
  final ValueChanged<double> onQuickAdd;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;

  List<double> get _quickAdds {
    switch (normalizeCurrencyCode(currency)) {
      case 'JPY':
      case 'KRW':
      case 'VND':
      case 'IDR':
        return const [100, 500, 1000, 5000];
      case 'INR':
        return const [10, 20, 50, 100, 500];
      case 'KWD':
      case 'BHD':
      case 'OMR':
        return const [1, 5, 10, 20];
      default:
        return const [5, 10, 20, 50];
    }
  }

  String _quickLabel(double amount) {
    final symbol = currencySymbol(currency).trim();
    final whole = amount == amount.roundToDouble();
    final n = whole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    return '+$symbol$n';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ok = canSubmitCash;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: PosTheme.border),
        boxShadow: PosTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.payCashTendered,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickBtn(label: l10n.payExact, accent: accent, onTap: onExact),
              ..._quickAdds.map(
                (amount) => _QuickBtn(
                  label: _quickLabel(amount),
                  accent: accent,
                  onTap: () => onQuickAdd(amount),
                ),
              ),
              _QuickBtn(
                label: l10n.commonClear,
                accent: accent,
                onTap: onClear,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: cashController,
            onChanged: onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: l10n.payReceived,
              filled: true,
              fillColor: PosTheme.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: PosTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: PosTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final tone = posStatusColors(ok ? 'paid' : 'cancelled');
              return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: tone.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: tone.fg.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.payments_rounded : Icons.warning_amber_rounded,
                  color: tone.fg,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ok ? l10n.payChangeDue : l10n.payShort,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: tone.fg,
                    ),
                  ),
                ),
                Text(
                  formatMoney(change, currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: tone.fg,
                  ),
                ),
              ],
            ),
          );
            },
          ),
          if (!ok)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.payShortHelp,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PosTheme.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.method,
    required this.amountLabel,
    required this.canSubmit,
    required this.onCancel,
    required this.onSubmit,
    required this.accent,
  });

  final String method;
  final String amountLabel;
  final bool canSubmit;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = method == 'pay_later'
        ? l10n.payPlaceOrder
        : l10n.payCharge(amountLabel);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: PosTheme.canvas,
        border: Border(
          top: BorderSide(color: PosTheme.border.withValues(alpha: 0.9)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                foregroundColor: PosTheme.inkMuted,
                side: BorderSide(color: PosTheme.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              child: Text(l10n.commonCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PosPrimaryButton(
              label: label,
              icon: method == 'pay_later'
                  ? Icons.receipt_long_rounded
                  : Icons.check_rounded,
              color: accent,
              glow: false,
              onPressed: canSubmit ? onSubmit : null,
            ),
          ),
        ],
      ),
    );
  }
}
