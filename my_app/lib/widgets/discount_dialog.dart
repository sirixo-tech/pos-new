import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';

/// Result of [DiscountDialog.show]. Null means cancelled.
class DiscountDialogResult {
  const DiscountDialogResult.apply(this.discount) : cleared = false;
  const DiscountDialogResult.clear()
      : discount = null,
        cleared = true;

  final CartDiscount? discount;
  final bool cleared;
}

class DiscountDialog extends StatefulWidget {
  const DiscountDialog({
    super.key,
    required this.subtotal,
    required this.currency,
    this.current,
  });

  final double subtotal;
  final String currency;
  final CartDiscount? current;

  static Future<DiscountDialogResult?> show(
    BuildContext context, {
    required double subtotal,
    required String currency,
    CartDiscount? current,
  }) {
    return showDialog<DiscountDialogResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => DiscountDialog(
        subtotal: subtotal,
        currency: currency,
        current: current,
      ),
    );
  }

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late String _type;
  final _valueController = TextEditingController();
  final _reasonController = TextEditingController();
  final _valueFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _type = widget.current?.type ?? 'percent';
    if (widget.current != null && widget.current!.value > 0) {
      _valueController.text = widget.current!.value.toString();
    }
    _reasonController.text = widget.current?.reason ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _valueFocus.requestFocus();
      _valueController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _valueController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _valueController.dispose();
    _reasonController.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  double get _numeric => double.tryParse(_valueController.text.trim()) ?? 0;

  double get _amount {
    if (_numeric <= 0 || widget.subtotal <= 0) return 0;
    if (_type == 'percent') {
      final pct = _numeric.clamp(0, 100);
      return ((pct / 100) * widget.subtotal * 100).round() / 100;
    }
    final capped = _numeric > widget.subtotal ? widget.subtotal : _numeric;
    return (capped * 100).round() / 100;
  }

  bool get _canApply => _numeric > 0 && _amount > 0 && widget.subtotal > 0;

  void _setType(String type) {
    if (_type == type) return;
    setState(() => _type = type);
  }

  void _apply() {
    if (!_canApply) return;
    Navigator.pop(
      context,
      DiscountDialogResult.apply(
        CartDiscount(
          type: _type,
          value: (_numeric * 100).round() / 100,
          reason: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final newBase = (widget.subtotal - _amount).clamp(0, double.infinity);
    final media = MediaQuery.sizeOf(context);
    final hasCurrent = widget.current != null;
    final l10n = context.l10n;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: media.width < 420 ? 16 : 28,
        vertical: 24,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: media.height * 0.9,
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
                  gradient: PosTheme.modalHeaderGradient(seed: accent),
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
                        Icons.local_offer_rounded,
                        color: PosTheme.modalHeaderIconColor(),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasCurrent
                                ? l10n.discountEditTitle
                                : l10n.discountApplyTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.discountOffSubtotal(
                              formatMoney(widget.subtotal, widget.currency),
                            ),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
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
                      _PreviewCard(
                        accent: accent,
                        soft: soft,
                        subtotalLabel:
                            formatMoney(widget.subtotal, widget.currency),
                        discountLabel:
                            '− ${formatMoney(_amount, widget.currency)}',
                        newBaseLabel:
                            formatMoney(newBase.toDouble(), widget.currency),
                        hasDiscount: _amount > 0,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.discountTypeLabel,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: PosTheme.ink.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _TypeToggle(
                        accent: accent,
                        type: _type,
                        onChanged: _setType,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _type == 'percent'
                            ? l10n.discountPercent
                            : l10n.discountAmount,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: PosTheme.ink.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _valueController,
                        focusNode: _valueFocus,
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
                          hintText: _type == 'percent' ? '0' : '0.00',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Align(
                              alignment: Alignment.centerRight,
                              widthFactor: 1,
                              child: Text(
                                _type == 'percent' ? '%' : widget.currency,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: soft.fg,
                                ),
                              ),
                            ),
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
                            borderSide: BorderSide(color: accent, width: 1.6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _apply(),
                      ),
                      if (_type == 'percent') ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [5, 10, 15, 20].map((p) {
                            final selected = _numeric == p.toDouble();
                            return _QuickPercentChip(
                              label: '$p%',
                              selected: selected,
                              accent: accent,
                              onTap: () {
                                _valueController.text = '$p';
                                setState(() {});
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        l10n.discountReason,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: PosTheme.ink.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonController,
                        maxLength: 255,
                        maxLines: 2,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: PosTheme.canvas,
                          hintText: l10n.discountReasonHint,
                          hintStyle: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: PosTheme.inkFaint,
                          ),
                          prefixIcon: Icon(
                            Icons.notes_rounded,
                            size: 20,
                            color: PosTheme.inkMuted,
                          ),
                          counterText: '',
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
                            borderSide: BorderSide(color: accent, width: 1.6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
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
                            onPressed: _canApply ? _apply : null,
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              hasCurrent
                                  ? l10n.discountUpdate
                                  : l10n.discountApply,
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  accent.withValues(alpha: 0.35),
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
                    if (hasCurrent) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            const DiscountDialogResult.clear(),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                            minimumSize: const Size(0, 40),
                          ),
                          child: Text(
                            l10n.discountRemove,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.accent,
    required this.soft,
    required this.subtotalLabel,
    required this.discountLabel,
    required this.newBaseLabel,
    required this.hasDiscount,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final String subtotalLabel;
  final String discountLabel;
  final String newBaseLabel;
  final bool hasDiscount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soft.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          _PreviewRow(label: l10n.commonSubtotal, value: subtotalLabel),
          const SizedBox(height: 8),
          _PreviewRow(
            label: l10n.discountLabel,
            value: discountLabel,
            emphasize: hasDiscount,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: accent.withValues(alpha: 0.14),
            ),
          ),
          _PreviewRow(
            label: l10n.discountNewTaxableBase,
            value: newBaseLabel,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.accent,
    required this.type,
    required this.onChanged,
  });

  final Color accent;
  final String type;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeOption(
              label: l10n.discountPercent,
              icon: Icons.percent_rounded,
              selected: type == 'percent',
              accent: accent,
              onTap: () => onChanged('percent'),
            ),
          ),
          Expanded(
            child: _TypeOption(
              label: l10n.discountAmount,
              icon: Icons.payments_outlined,
              selected: type == 'amount',
              accent: accent,
              onTap: () => onChanged('amount'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Material(
      color: selected ? soft.bg : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? soft.fg.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
            boxShadow: selected && !PosTheme.isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? soft.fg : PosTheme.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? soft.fg : PosTheme.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPercentChip extends StatelessWidget {
  const _QuickPercentChip({
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
    final soft = posAccentSoft(accent);

    return Material(
      color: selected ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.35)
                  : PosTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? soft.fg : PosTheme.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final color = emphasize
        ? const Color(0xFFB91C1C)
        : bold
            ? PosTheme.ink
            : PosTheme.inkMuted;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 13.5 : 13,
              color: color,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 15 : 13.5,
            color: emphasize
                ? const Color(0xFFB91C1C)
                : bold
                    ? PosTheme.ink
                    : PosTheme.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
