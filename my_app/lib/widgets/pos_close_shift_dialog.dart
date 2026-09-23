import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../services/pos_api.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/pos_user_facing_error.dart';
import 'pos_ui.dart';

/// Close-shift modal with expected-cash summary (matches web POS).
class PosCloseShiftDialog extends StatefulWidget {
  const PosCloseShiftDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const PosCloseShiftDialog(),
    );
    return result == true;
  }

  @override
  State<PosCloseShiftDialog> createState() => _PosCloseShiftDialogState();
}

class _PosCloseShiftDialogState extends State<PosCloseShiftDialog> {
  final _cashController = TextEditingController();
  final _notesController = TextEditingController();
  final _cashFocus = FocusNode();

  PosShiftCloseSummary? _summary;
  bool _loadingSummary = true;
  bool _closing = false;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _notesController.dispose();
    _cashFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final summary =
          await context.read<PosController>().fetchShiftCloseSummary();
      if (!mounted) return;
      _cashController.text = summary.expectedCash.toStringAsFixed(2);
      setState(() {
        _summary = summary;
        _loadingSummary = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _cashFocus.requestFocus();
        _cashController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _cashController.text.length,
        );
      });
    } on PosApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = posUserFacingError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = context.l10n.shiftSummaryLoadFailed;
      });
    }
  }

  double get _countedCash =>
      double.tryParse(_cashController.text.trim()) ?? 0;

  double? get _variance {
    final summary = _summary;
    if (summary == null) return null;
    return ((_countedCash - summary.expectedCash) * 100).round() / 100;
  }

  Future<void> _submit() async {
    if (_closing || _loadingSummary || _summary == null) return;
    setState(() => _closing = true);
    try {
      await context.read<PosController>().closeShift(
            _countedCash,
            notes: _notesController.text.trim(),
          );
      if (!mounted) return;
      showPosSnackBar(context, context.l10n.shiftClosedSnack);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _closing = false);
      showPosErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final currency = pos.currency;
    final media = MediaQuery.sizeOf(context);
    final variance = _variance;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: media.width < 420 ? 16 : 28,
        vertical: 24,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: media.height * 0.92,
        ),
        child: Material(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  gradient: PosTheme.modalHeaderGradient(
                    tone: PosModalHeaderTone.danger,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.stop_circle_outlined,
                        color: PosTheme.modalHeaderIconColor(
                          tone: PosModalHeaderTone.danger,
                        ),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.shiftCloseTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.shiftCloseSubtitle,
                            style: const TextStyle(
                              color: Color(0xD9FFFFFF),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loadingSummary)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Column(
                              children: [
                                const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.shiftSummaryLoading,
                                  style: TextStyle(
                                    color: PosTheme.inkMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_summaryError != null)
                        _ErrorBlock(
                          message: _summaryError!,
                          onRetry: _loadSummary,
                        )
                      else if (_summary != null) ...[
                        _SummaryCard(
                          summary: _summary!,
                          currency: currency,
                          countedCash: _cashController.text.trim().isEmpty
                              ? null
                              : _countedCash,
                          variance: variance,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.shiftCashCounted,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: PosTheme.ink.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _cashController,
                          focusNode: _cashFocus,
                          enabled: !_closing,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: PosTheme.canvas,
                            prefixIcon: Padding(
                              padding:
                                  const EdgeInsets.only(left: 14, right: 6),
                              child: Text(
                                currency,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFBE123C),
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            hintText: '0.00',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: PosTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: PosTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE11D48),
                                width: 1.6,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.shiftNotes,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: PosTheme.ink.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          enabled: !_closing,
                          maxLines: 2,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: PosTheme.canvas,
                            hintText: l10n.shiftCloseNotesHint,
                            hintStyle: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: PosTheme.inkFaint,
                            ),
                            prefixIcon: Icon(
                              Icons.notes_rounded,
                              size: 20,
                              color: PosTheme.inkMuted,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: PosTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: PosTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE11D48),
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: PosTheme.canvas,
                  border: Border(
                    top: BorderSide(
                      color: PosTheme.border.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _closing
                            ? null
                            : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: PosTheme.inkMuted,
                          side: BorderSide(color: PosTheme.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l10n.commonCancel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: (_closing ||
                                _loadingSummary ||
                                _summary == null)
                            ? null
                            : _submit,
                        icon: _closing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.stop_circle_outlined, size: 18),
                        label: Text(
                          _closing ? l10n.shiftClosing : l10n.opsCloseShift,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFFE11D48).withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.currency,
    required this.countedCash,
    required this.variance,
  });

  final PosShiftCloseSummary summary;
  final String currency;
  final double? countedCash;
  final double? variance;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paidLabel = summary.ordersCount == 1
        ? l10n.shiftPaidOrderOne
        : l10n.shiftPaidOrders(summary.ordersCount);
    final unpaidSuffix = summary.unpaidOrdersCount > 0
        ? l10n.shiftUnpaidSuffix(
            formatMoney(summary.unpaidOrdersTotal, currency),
            summary.unpaidOrdersCount,
          )
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.shiftSalesSection,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: PosTheme.inkFaint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(summary.ordersTotal, currency),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: PosTheme.ink,
            ),
          ),
          Text(
            '$paidLabel$unpaidSuffix',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PosTheme.inkMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.shiftByMethodSection,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: PosTheme.inkFaint,
            ),
          ),
          const SizedBox(height: 8),
          if (summary.paymentMethods.isEmpty)
            Text(
              l10n.shiftNoPaidSales,
              style: TextStyle(
                fontSize: 13,
                color: PosTheme.inkMuted,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            ...summary.paymentMethods.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${formatPaymentMethod(entry.key)} (${entry.value.count})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PosTheme.ink,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(entry.value.total, currency),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (summary.tipsTotal > 0) ...[
            const SizedBox(height: 4),
            Text(
              l10n.shiftTipsOnOrders(
                formatMoney(summary.tipsTotal, currency),
              ),
              style: TextStyle(
                fontSize: 12,
                color: PosTheme.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: PosTheme.border),
          ),
          Text(
            l10n.shiftCashDrawerSection,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: PosTheme.inkFaint,
            ),
          ),
          const SizedBox(height: 8),
          _MoneyRow(
            label: l10n.shiftOpeningFloat,
            value: formatMoney(summary.openingFloat, currency),
          ),
          _MoneyRow(
            label: l10n.shiftCashSales,
            value: formatMoney(summary.cashFromSales, currency),
          ),
          if (summary.changeGivenTotal > 0)
            _MoneyRow(
              label: l10n.shiftChangeGiven,
              value: formatMoney(summary.changeGivenTotal, currency),
              muted: true,
            ),
          const SizedBox(height: 6),
          _MoneyRow(
            label: l10n.shiftExpectedDrawer,
            value: formatMoney(summary.expectedCash, currency),
            emphasize: true,
            valueColor: const Color(0xFF047857),
          ),
          if (countedCash != null && variance != null) ...[
            const SizedBox(height: 6),
            _MoneyRow(
              label: l10n.shiftCounted,
              value: formatMoney(countedCash!, currency),
            ),
            const SizedBox(height: 6),
            _VarianceBanner(variance: variance!, currency: currency),
          ],
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.muted = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final bool muted;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: emphasize ? 13.5 : 13,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: muted ? PosTheme.inkFaint : PosTheme.inkMuted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 16 : 13.5,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
              color: valueColor ?? PosTheme.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _VarianceBanner extends StatelessWidget {
  const _VarianceBanner({
    required this.variance,
    required this.currency,
  });

  final double variance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final balanced = variance == 0;
    final over = variance > 0;
    final tone = balanced
        ? null
        : posStatusColors(over ? 'paid' : 'cancelled');
    final bg = tone?.bg ?? PosTheme.surface;
    final fg = tone?.fg ?? PosTheme.ink;
    final label = balanced
        ? l10n.shiftBalanced
        : over
            ? l10n.shiftOver
            : l10n.shiftShort;
    final amount = '${over ? '+' : ''}${formatMoney(variance, currency)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            l10n.shiftVariance,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const Spacer(),
          Text(
            '$amount · $label',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tone = posStatusColors('pending');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.fg.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: tone.fg),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tone.fg,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.l10n.commonTryAgain),
          ),
        ],
      ),
    );
  }
}
