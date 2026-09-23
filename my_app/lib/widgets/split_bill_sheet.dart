import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../services/pos_api.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/json_parse.dart';
import 'cash_register_sheet.dart';
import 'pos_overlay.dart';
import 'pos_ui.dart';

/// Amount-based multi-payment UI — visual language matches [CashRegisterSheet].
class SplitBillSheet extends StatefulWidget {
  const SplitBillSheet({
    super.key,
    required this.order,
    required this.currency,
    this.paymentGateways = const [],
    this.asSidePanel = false,
    this.embedded = false,
  });

  final Map<String, dynamic> order;
  final String currency;
  final List<PaymentGatewayOption> paymentGateways;
  final bool asSidePanel;

  /// When true, omit outer header/close (parent owns chrome).
  final bool embedded;

  /// Returns true when the order is fully paid after the sheet closes.
  static Future<bool?> open(
    BuildContext context, {
    required Map<String, dynamic> order,
    required String currency,
  }) {
    final side = preferPosSidePanel(context);
    return showPosOverlay<bool>(
      context: context,
      sidePanelWidth: 440,
      builder: (_) {
        final child = SplitBillSheet(
          order: order,
          currency: currency,
          asSidePanel: side,
        );
        if (side) return PosSidePanelShell(child: child);
        return PosMobileSheetFrame(child: child);
      },
    );
  }

  @override
  State<SplitBillSheet> createState() => _SplitBillSheetState();
}

class _SplitBillSheetState extends State<SplitBillSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _cashController = TextEditingController();
  final _api = PosApi();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _method = 'cash';
  List<Map<String, dynamic>> _payments = const [];
  double _totalPaid = 0;
  double _remaining = 0;
  String _paymentStatus = 'pending';

  double get _orderTotal => parseJsonDouble(widget.order['total']);

  double get _chargeAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0;

  double get _tenderNum => double.tryParse(_cashController.text.trim()) ?? 0;

  double get _change =>
      ((_tenderNum - _chargeAmount) * 100).roundToDouble() / 100;

  bool get _canSubmitCash =>
      _method != 'cash' || _tenderNum + 0.0001 >= _chargeAmount;

  bool get _isPartial =>
      _chargeAmount > 0 && _chargeAmount + 0.001 < _remaining;

  bool get _isFullRemaining =>
      _chargeAmount > 0 && _chargeAmount + 0.001 >= _remaining;

  bool _isQrMethod(String method) =>
      method == 'phonepe' || method == 'paytm';

  bool get _selectedIsQr => _isQrMethod(_method);

  @override
  void initState() {
    super.initState();
    _paymentStatus = '${widget.order['payment_status'] ?? 'pending'}';
    _remaining = parseJsonDouble(
      widget.order['amount_due'] ?? widget.order['total'],
    );
    _totalPaid = parseJsonDouble(widget.order['amount_paid']);
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<PosController>().session;
    final orderId = parseJsonIntOrNull(widget.order['id']);
    if (session == null || orderId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.fetchOrderPayments(session, orderId: orderId);
      if (!mounted) return;
      _applySummary(data);
    } on PosApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySummary(Map<String, dynamic> data) {
    final payments = (data['payments'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final remaining = parseJsonDouble(data['remaining']);
    setState(() {
      _payments = payments;
      _totalPaid = parseJsonDouble(data['total_paid']);
      _remaining = remaining;
      _paymentStatus = '${data['payment_status'] ?? _paymentStatus}';
      _amountController.text = remaining > 0 ? _formatAmount(remaining) : '';
      _cashController.text = remaining > 0 ? _formatAmount(remaining) : '';
    });
  }

  String _formatAmount(double value) => value.toStringAsFixed(2);

  void _setCharge(double value) {
    final v = math.max(0.0, math.min(value, _remaining));
    final text = _formatAmount(v);
    setState(() {
      _amountController.text = text;
      if (_method == 'cash') {
        _cashController.text = text;
      }
      // QR gateways only work for the full remaining balance.
      if (_selectedIsQr && v + 0.001 < _remaining) {
        _method = 'cash';
        _cashController.text = text;
      }
    });
  }

  Future<void> _recordPayment() async {
    final l10n = context.l10n;
    final session = context.read<PosController>().session;
    final orderId = parseJsonIntOrNull(widget.order['id']);
    if (session == null || orderId == null) return;

    final amount = _chargeAmount;
    if (amount <= 0) {
      showPosSnackBar(context, l10n.splitBillInvalidAmount, error: true);
      return;
    }
    if (amount > _remaining + 0.001) {
      showPosSnackBar(context, l10n.splitBillAmountExceeds, error: true);
      return;
    }

    // PhonePe / Paytm need the full-pay QR flow (same as Full amount).
    if (_selectedIsQr) {
      if (_isPartial) {
        showPosSnackBar(context, l10n.splitBillQrFullOnly, error: true);
        return;
      }
      Navigator.of(context, rootNavigator: true).pop(
        PaymentSubmission(method: _method),
      );
      return;
    }

    double? cashTendered;
    if (_method == 'cash') {
      if (!_canSubmitCash) {
        showPosSnackBar(context, l10n.payShort, error: true);
        return;
      }
      cashTendered = (_tenderNum * 100).roundToDouble() / 100;
    }

    setState(() => _saving = true);
    try {
      final data = await _api.addOrderPayment(
        session,
        orderId: orderId,
        amount: amount,
        method: _method,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        cashTendered: cashTendered,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _noteController.clear();
      _applySummary(data);

      final status = '${data['payment_status'] ?? ''}';
      if (status == 'paid' || _remaining <= 0.001) {
        showPosSnackBar(context, l10n.splitBillFullyPaid);
        Navigator.pop(context, true);
        return;
      }
      showPosSnackBar(
        context,
        l10n.splitBillPaymentRecorded(
          formatMoney(amount, widget.currency),
        ),
      );
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _close() {
    final isPaid = _remaining <= 0.001 || _paymentStatus == 'paid';
    Navigator.pop(context, isPaid);
  }

  String _methodLabel(AppLocalizations l10n, String method) {
    return switch (method) {
      'cash' => l10n.payCash,
      'card' => l10n.payCard,
      'wallet' => l10n.payWallet,
      'other' => l10n.payOther,
      'phonepe' || 'paytm' => 'UPI Payment',
      _ => () {
          for (final g in widget.paymentGateways) {
            if (g.slug == method) return g.label;
          }
          return method;
        }(),
    };
  }

  String _methodSubtitle(AppLocalizations l10n, String method) {
    if (_isQrMethod(method) && _isPartial) {
      return l10n.splitBillQrFullOnly;
    }
    return switch (method) {
      'cash' => l10n.payCashSubtitle,
      'card' => l10n.payCardSubtitle,
      'wallet' => l10n.payWalletSubtitle,
      'other' => l10n.payOtherSubtitle,
      'phonepe' || 'paytm' => l10n.payUpiQr,
      _ => l10n.payUpiQr,
    };
  }

  IconData _methodIcon(String method) {
    return switch (method) {
      'cash' => Icons.payments_outlined,
      'card' => Icons.credit_card_rounded,
      'wallet' => Icons.account_balance_wallet_outlined,
      'other' => Icons.more_horiz_rounded,
      'phonepe' || 'paytm' => Icons.qr_code_2_rounded,
      _ => Icons.qr_code_2_rounded,
    };
  }

  List<({String id, IconData icon})> _methodEntries() {
    return [
      (id: 'cash', icon: Icons.payments_outlined),
      (id: 'card', icon: Icons.credit_card_rounded),
      (id: 'wallet', icon: Icons.account_balance_wallet_outlined),
      (id: 'other', icon: Icons.more_horiz_rounded),
      for (final gateway in widget.paymentGateways)
        (
          id: gateway.slug,
          icon: _methodIcon(gateway.slug),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 780;
    final label = widget.order['order_number']?.toString() ??
        '#${widget.order['id'] ?? ''}';
    final isPaid = _remaining <= 0.001 || _paymentStatus == 'paid';

    if (_loading) {
      return Material(
        color: PosTheme.surface,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Material(
        color: PosTheme.surface,
        child: PosEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.splitBillLoadFailed,
          subtitle: _error,
          accent: accent,
          action: TextButton(
            onPressed: _load,
            child: Text(l10n.commonRetry),
          ),
        ),
      );
    }

    final amountCard = Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: PosTheme.ctaGradient(accent),
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        boxShadow: PosTheme.buttonShadow(accent),
      ),
      child: Column(
        children: [
          Text(
            l10n.payAmountDue,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(isPaid ? 0 : _remaining, widget.currency),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
              letterSpacing: -0.8,
            ),
          ),
          if (_totalPaid > 0 || _payments.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _StatPill(
                  label: l10n.splitBillPaidSoFar,
                  value: formatMoney(_totalPaid, widget.currency),
                ),
                _StatPill(
                  label: l10n.splitBillOrderTotal,
                  value: formatMoney(_orderTotal, widget.currency),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final paymentsList = _payments.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.splitBillPayments,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: PosTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _payments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final payment = _payments[i];
                    final method = '${payment['method'] ?? ''}';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: PosTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PosTheme.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: soft.bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _methodLabel(l10n, method),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: soft.fg,
                              ),
                            ),
                          ),
                          if ((payment['note']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${payment['note']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: PosTheme.inkMuted,
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          Text(
                            formatMoney(
                              parseJsonDouble(payment['amount']),
                              widget.currency,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );

    final chargeCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: PosTheme.inkMuted),
              const SizedBox(width: 8),
              Text(
                l10n.splitBillAmount,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: PosTheme.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (_) {
              if (_method == 'cash') {
                _cashController.text = _amountController.text;
              }
              setState(() {});
            },
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: PosTheme.surfaceMuted,
              hintText: '0.00',
              prefixText: '  ',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickChip(
                label: l10n.splitBillFillRemaining,
                selected: !_isPartial && _chargeAmount > 0,
                accent: accent,
                onTap: () => _setCharge(_remaining),
              ),
              _QuickChip(
                label: l10n.splitBillQuickHalf,
                selected: (_chargeAmount - _remaining / 2).abs() < 0.02 &&
                    _isPartial,
                accent: accent,
                onTap: () => _setCharge(_remaining / 2),
              ),
              _QuickChip(
                label: l10n.splitBillQuickThird,
                selected: (_chargeAmount - _remaining / 3).abs() < 0.02 &&
                    _isPartial,
                accent: accent,
                onTap: () => _setCharge(_remaining / 3),
              ),
            ],
          ),
          if (_isPartial) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: l10n.splitBillNoteOptional,
                hintText: l10n.splitBillNoteHint,
                isDense: true,
                filled: true,
                fillColor: PosTheme.surfaceMuted,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final methods = _methodEntries();

    final methodGrid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.payMethodLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: PosTheme.ink,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in methods)
                  SizedBox(
                    width: tileWidth,
                    child: _MethodCard(
                      label: _methodLabel(l10n, m.id),
                      subtitle: _methodSubtitle(l10n, m.id),
                      icon: m.icon,
                      selected: _method == m.id,
                      enabled: !_isQrMethod(m.id) || _isFullRemaining,
                      accent: accent,
                      soft: soft,
                      onTap: () {
                        if (_isQrMethod(m.id) && _isPartial) {
                          showPosSnackBar(
                            context,
                            l10n.splitBillQrFullOnly,
                            error: true,
                          );
                          return;
                        }
                        setState(() {
                          _method = m.id;
                          if (m.id == 'cash') {
                            _cashController.text = _amountController.text;
                          }
                        });
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );

    final rightPanel = _method == 'cash'
        ? _SplitCashPanel(
            cashController: _cashController,
            canSubmitCash: _canSubmitCash,
            change: _change.clamp(0.0, double.infinity),
            currency: widget.currency,
            accent: accent,
            chargeAmount: _chargeAmount,
            onExact: () {
              _cashController.text = _formatAmount(_chargeAmount);
              setState(() {});
            },
            onQuickAdd: (delta) {
              _cashController.text = _formatAmount(
                ((_tenderNum + delta) * 100).roundToDouble() / 100,
              );
              setState(() {});
            },
            onClear: () {
              _cashController.clear();
              setState(() {});
            },
            onChanged: (_) => setState(() {}),
          )
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: PosTheme.surface,
              borderRadius: BorderRadius.circular(PosTheme.radiusLg),
              border: Border.all(color: PosTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _selectedIsQr
                      ? Icons.qr_code_2_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 40,
                  color: accent,
                ),
                const SizedBox(height: 12),
                Text(
                  _methodLabel(l10n, _method),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatMoney(_chargeAmount, widget.currency),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedIsQr
                      ? l10n.payQrHelp
                      : _isPartial
                          ? l10n.splitBillCollectHint
                          : _methodSubtitle(l10n, _method),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: PosTheme.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          );

    final leftColumn = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 22 : 16, 16, wide ? 18 : 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          amountCard,
          if (_payments.isNotEmpty) ...[
            const SizedBox(height: 14),
            paymentsList,
          ],
          if (!isPaid) ...[
            const SizedBox(height: 14),
            chargeCard,
          ],
        ],
      ),
    );

    final rightColumn = Container(
      color: PosTheme.canvas,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(wide ? 18 : 16, 16, wide ? 22 : 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isPaid) ...[
              methodGrid,
              const SizedBox(height: 14),
              rightPanel,
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    l10n.splitBillPaidCheck,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final footerLabel = _saving
        ? l10n.splitBillRecording
        : _selectedIsQr
            ? l10n.payShowQr
            : _isPartial
                ? l10n.splitBillRecordPayment(_methodLabel(l10n, _method))
                : l10n.payCharge(formatMoney(_chargeAmount, widget.currency));

    final footer = Container(
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
              onPressed: _saving ? null : _close,
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
          if (!isPaid) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PosPrimaryButton(
                label: footerLabel,
                icon: _selectedIsQr
                    ? Icons.qr_code_2_rounded
                    : _isPartial
                        ? Icons.add_rounded
                        : Icons.check_rounded,
                color: accent,
                onPressed: _saving ||
                        _chargeAmount <= 0 ||
                        (_selectedIsQr && _isPartial) ||
                        (_method == 'cash' && !_canSubmitCash)
                    ? null
                    : _recordPayment,
              ),
            ),
          ],
        ],
      ),
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
              Expanded(flex: 4, child: rightColumn),
            ],
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftColumn,
                Divider(height: 1, color: PosTheme.border),
                Container(
                  color: PosTheme.canvas,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isPaid) ...[
                        methodGrid,
                        const SizedBox(height: 14),
                        rightPanel,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );

    final content = Column(
      children: [
        if (!widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.collectModeSplit,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        Expanded(child: bodyPane),
        footer,
      ],
    );

    return Material(
      color: PosTheme.surface,
      child: widget.embedded ? content : SafeArea(child: content),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
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
            border: Border.all(color: selected ? accent : PosTheme.border),
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

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.accent,
    required this.soft,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final Color accent;
  final ({Color bg, Color fg}) soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? PosTheme.inkFaint
        : selected
            ? soft.fg
            : PosTheme.ink;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected && enabled ? soft.bg : PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected && enabled ? accent : PosTheme.border,
                width: selected && enabled ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: selected && enabled ? accent : PosTheme.inkMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
  }
}

class _SplitCashPanel extends StatelessWidget {
  const _SplitCashPanel({
    required this.cashController,
    required this.canSubmitCash,
    required this.change,
    required this.currency,
    required this.accent,
    required this.chargeAmount,
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
  final double chargeAmount;
  final VoidCallback onExact;
  final ValueChanged<double> onQuickAdd;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.payCashTendered,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickChip(
                label: l10n.payExact,
                selected: false,
                accent: accent,
                onTap: onExact,
              ),
              for (final delta in const [5.0, 10.0, 20.0, 50.0])
                _QuickChip(
                  label: '+${delta.toStringAsFixed(0)}',
                  selected: false,
                  accent: accent,
                  onTap: () => onQuickAdd(delta),
                ),
              _QuickChip(
                label: l10n.commonClear,
                selected: false,
                accent: accent,
                onTap: onClear,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: PosTheme.surfaceMuted,
              hintText: chargeAmount > 0
                  ? chargeAmount.toStringAsFixed(2)
                  : '0.00',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final tone =
                  posStatusColors(canSubmitCash ? 'paid' : 'cancelled');
              return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tone.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tone.fg.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    l10n.payChangeDue,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: tone.fg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(change.clamp(0.0, double.infinity), currency),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: tone.fg,
                  ),
                ),
              ],
            ),
          );
            },
          ),
        ],
      ),
    );
  }
}
