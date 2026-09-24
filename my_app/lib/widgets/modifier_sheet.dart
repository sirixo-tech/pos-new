import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/media_url.dart';
import 'pos_overlay.dart';
import 'pos_ui.dart';

class ModifierSheet extends StatefulWidget {
  const ModifierSheet({
    super.key,
    required this.item,
    this.asDialog = false,
  });

  final MenuItem item;

  /// Centered modal on large screens; bottom sheet on phones.
  final bool asDialog;

  static Future<void> show(BuildContext context, MenuItem item) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: PosTheme.ink.withValues(alpha: 0.45),
      builder: (ctx) {
        final inset = posKeyboardInset(ctx);
        final mq = MediaQuery.of(ctx);
        return AnimatedPadding(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: inset),
          child: MediaQuery(
            data: mq.copyWith(viewInsets: EdgeInsets.zero),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              child: ModifierSheet(item: item, asDialog: true),
            ),
          ),
        );
      },
    );
  }

  @override
  State<ModifierSheet> createState() => _ModifierSheetState();
}

class _ModifierSheetState extends State<ModifierSheet> {
  static const int _notesMaxLength = 120;

  MenuVariant? _variant;
  final Map<int, List<ModifierOption>> _selections = {};
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.item.variants.isNotEmpty) {
      _variant = widget.item.variants.first;
    }
    for (final modifier in widget.item.modifiers) {
      _selections[modifier.id] = [];
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _unitPrice {
    var total = widget.item.baseUnitPrice(_variant);
    for (final options in _selections.values) {
      for (final option in options) {
        total += option.priceAdjustment;
      }
    }
    return total;
  }

  List<ModifierOption> _selectedFor(int modifierId) =>
      _selections[modifierId] ?? const [];

  bool _isSingleSelect(MenuModifier modifier) => modifier.maxSelections == 1;

  void _toggleOption(MenuModifier modifier, ModifierOption option) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = List<ModifierOption>.from(_selectedFor(modifier.id));
      final index = current.indexWhere((o) => o.id == option.id);
      final isSelected = index >= 0;

      if (_isSingleSelect(modifier)) {
        _selections[modifier.id] = isSelected ? [] : [option];
        return;
      }

      if (isSelected) {
        current.removeAt(index);
      } else {
        final max = modifier.maxSelections;
        if (max != null && current.length >= max) {
          showPosSnackBar(
            context,
            context.l10n.modifierChooseUpTo(max, modifier.name),
            error: true,
          );
          return;
        }
        current.add(option);
      }
      _selections[modifier.id] = current;
    });
  }

  bool _validateModifiers() {
    for (final modifier in widget.item.modifiers) {
      final count = _selectedFor(modifier.id).length;
      final minRequired = modifier.isRequired
          ? (modifier.minSelections > 0 ? modifier.minSelections : 1)
          : modifier.minSelections;
      if (count < minRequired) {
        showPosSnackBar(
          context,
          context.l10n.modifierPleaseChoose(modifier.name),
          error: true,
        );
        return false;
      }
    }
    return true;
  }

  void _addToCart() {
    if (!_validateModifiers()) return;
    HapticFeedback.mediumImpact();

    final notes = _notesController.text.trim();
    final selectedModifiers =
        _selections.values.expand((options) => options).toList();

    context.read<PosController>().addToCart(
          CartLine(
            menuItem: widget.item,
            variant: _variant,
            selectedModifiers: selectedModifiers,
            quantity: _quantity,
            notes: notes.isEmpty ? null : notes,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final accent = Theme.of(context).colorScheme.primary;
    final size = MediaQuery.sizeOf(context);
    final asDialog = widget.asDialog;

    // Under [PosKeyboardSheetHost], size is already above the keyboard.
    final maxHeight = asDialog
        ? math.max(220.0, size.height * 0.92)
        : posMobileSheetHeight(context);
    final maxWidth = asDialog
        ? math.min(size.width - 32, 920.0)
        : math.min(size.width, 720.0);

    var sectionNumber = 1;

    final sections = <Widget>[
      if (widget.item.variants.isNotEmpty) ...[
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                number: sectionNumber++,
                title: context.l10n.modifierChooseVariant,
                required: true,
                accent: accent,
                selectedCount: _variant == null ? 0 : 1,
                maxCount: 1,
              ),
              const SizedBox(height: 12),
              _OptionGrid(
                children: widget.item.variants.map((variant) {
                  final selected = _variant?.id == variant.id;
                  return _SelectionCard(
                    label: variant.name,
                    priceLabel: formatMoney(variant.price, pos.currency),
                    selected: selected,
                    singleSelect: true,
                    accent: accent,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      HapticFeedback.selectionClick();
                      setState(() => _variant = variant);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      for (final modifier in widget.item.modifiers) ...[
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                number: sectionNumber++,
                title: modifier.name,
                required: modifier.isRequired,
                accent: accent,
                selectedCount: _selectedFor(modifier.id).length,
                maxCount: modifier.maxSelections,
              ),
              const SizedBox(height: 12),
              _OptionGrid(
                children: modifier.options.map((option) {
                  final selected =
                      _selectedFor(modifier.id).any((o) => o.id == option.id);
                  final single = _isSingleSelect(modifier);
                  final priceLabel = option.priceAdjustment == 0
                      ? null
                      : '${option.priceAdjustment > 0 ? '+' : ''}'
                          '${formatMoney(option.priceAdjustment, pos.currency)}';
                  return _SelectionCard(
                    label: option.name,
                    priceLabel: priceLabel,
                    selected: selected,
                    singleSelect: single,
                    accent: accent,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _toggleOption(modifier, option);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              number: sectionNumber++,
              title: context.l10n.modifierSpecialInstructions,
              required: false,
              accent: accent,
            ),
            const SizedBox(height: 12),
            _NotesField(
              controller: _notesController,
              maxLength: _notesMaxLength,
              accent: accent,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              number: sectionNumber,
              title: context.l10n.modifierQuantity,
              required: false,
              accent: accent,
            ),
            const SizedBox(height: 12),
            _QuantityStepper(
              quantity: _quantity,
              accent: accent,
              onChanged: (value) {
                FocusScope.of(context).unfocus();
                HapticFeedback.selectionClick();
                setState(() => _quantity = value);
              },
            ),
          ],
        ),
      ),
    ];

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!asDialog) ...[
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: PosTheme.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ] else
          const SizedBox(height: 4),
        _ProductHeader(
          item: widget.item,
          currency: pos.currency,
          unitPrice: _unitPrice,
          accent: accent,
          onClose: () => Navigator.of(context).pop(),
        ),
      ],
    );

    final footer = _StickyFooter(
      accent: accent,
      currency: pos.currency,
      unitPrice: _unitPrice,
      quantity: _quantity,
      onAdd: _addToCart,
      compact: asDialog,
    );

    final radius = asDialog
        ? BorderRadius.circular(PosTheme.radiusXl)
        : const BorderRadius.vertical(top: Radius.circular(PosTheme.radiusXl));

    if (asDialog) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: maxWidth,
          minWidth: math.min(maxWidth, 760),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusXl),
            boxShadow: [
              BoxShadow(
                color: PosTheme.ink.withValues(alpha: 0.22),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Material(
            color: PosTheme.canvas,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: sections,
                  ),
                ),
                footer,
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: maxHeight,
        width: maxWidth,
        child: Material(
          color: PosTheme.canvas,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          shadowColor: PosTheme.ink.withValues(alpha: 0.18),
          child: Column(
            children: [
              header,
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: sections,
                ),
              ),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        border: Border.all(color: PosTheme.border),
        boxShadow: [
          BoxShadow(
            color: PosTheme.ink.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    required this.item,
    required this.currency,
    required this.unitPrice,
    required this.accent,
    required this.onClose,
  });

  final MenuItem item;
  final String currency;
  final double unitPrice;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final pos = context.read<PosController>();
    final imageUrl = resolveMediaUrl(
      item.imageUrl,
      serverUrl: pos.serverUrl ?? pos.session?.serverUrl,
    );
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final lang = Localizations.localeOf(context).languageCode;
    final itemName = item.localizedName(lang);
    final description = item.localizedDescription(lang)?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _imagePlaceholder(accent),
                      errorWidget: (_, _, _) => _imagePlaceholder(accent),
                    )
                  else
                    _imagePlaceholder(accent),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.15,
                      ),
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final soft = posAccentSoft(accent);
                    return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: soft.bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: soft.fg.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    formatMoney(unitPrice, currency),
                    style: TextStyle(
                      color: soft.fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                );
                  },
                ),
              ],
            ),
          ),
          Material(
            color: PosTheme.surface,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onClose,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: PosTheme.border),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: PosTheme.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(Color accent) {
    return ColoredBox(
      color: accent.withValues(alpha: 0.08),
      child: Icon(
        Icons.restaurant_rounded,
        color: accent.withValues(alpha: 0.55),
        size: 30,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.number,
    required this.title,
    required this.required,
    required this.accent,
    this.selectedCount,
    this.maxCount,
  });

  final int number;
  final String title;
  final bool required;
  final Color accent;
  final int? selectedCount;
  final int? maxCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = selectedCount;
    final showCount = count != null && (required || (count > 0));

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, Color.lerp(accent, Colors.black, 0.12)!],
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PosTheme.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: -0.15,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (showCount && maxCount != null && maxCount! > 1)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '$count/$maxCount',
              style: TextStyle(
                color: count >= (required ? 1 : 0)
                    ? accent
                    : PosTheme.inkFaint,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        Builder(
          builder: (context) {
            final soft = posAccentSoft(accent);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: required ? soft.bg : PosTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: required
                      ? soft.fg.withValues(alpha: 0.28)
                      : PosTheme.border,
                ),
              ),
              child: Text(
                required ? l10n.modifierRequired : l10n.modifierOptional,
                style: TextStyle(
                  color: required ? soft.fg : PosTheme.inkMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 560
            ? 3
            : width >= 360
                ? 2
                : 1;
        const gap = 10.0;
        final itemWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.label,
    required this.selected,
    required this.singleSelect,
    required this.accent,
    required this.onTap,
    this.priceLabel,
  });

  final String label;
  final String? priceLabel;
  final bool selected;
  final bool singleSelect;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? soft.bg
                : PosTheme.surfaceMuted.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? soft.fg.withValues(alpha: 0.4)
                  : PosTheme.border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (singleSelect)
                _RadioIndicator(selected: selected, accent: accent)
              else
                _CheckIndicator(selected: selected, accent: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosTheme.ink,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
              if (priceLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? soft.bg : PosTheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? soft.fg.withValues(alpha: 0.28)
                          : PosTheme.border,
                    ),
                  ),
                  child: Text(
                    priceLabel!,
                    style: TextStyle(
                      color: selected ? soft.fg : PosTheme.inkMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
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

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : PosTheme.inkFaint,
          width: selected ? 6 : 2,
        ),
        color: PosTheme.surface,
      ),
    );
  }
}

class _CheckIndicator extends StatelessWidget {
  const _CheckIndicator({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? accent : PosTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? accent : PosTheme.inkFaint.withValues(alpha: 0.55),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        selected ? Icons.check_rounded : Icons.add_rounded,
        size: 16,
        color: selected ? Colors.white : accent,
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({
    required this.controller,
    required this.maxLength,
    required this.accent,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int maxLength;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: maxLength,
      maxLines: 2,
      minLines: 2,
      // Keep notes / quantity above the sticky footer + keyboard.
      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
      inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
      style: TextStyle(
        color: PosTheme.ink,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: context.l10n.modifierNotesHint,
        hintStyle: TextStyle(
          color: PosTheme.inkFaint,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: PosTheme.surfaceMuted.withValues(alpha: 0.65),
        counterText: '${controller.text.length}/$maxLength',
        counterStyle: TextStyle(
          color: PosTheme.inkFaint,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.accent,
    required this.onChanged,
  });

  final int quantity;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: PosTheme.surfaceMuted.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PosTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              enabled: quantity > 1,
              onTap: () => onChanged(quantity - 1),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: accent,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              enabled: true,
              onTap: () => onChanged(quantity + 1),
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? PosTheme.inkMuted;
    return Material(
      color: enabled
          ? (accent != null
              ? accent!.withValues(alpha: 0.14)
              : PosTheme.surface)
          : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? color : PosTheme.border,
          ),
        ),
      ),
    );
  }
}

class _StickyFooter extends StatelessWidget {
  const _StickyFooter({
    required this.accent,
    required this.currency,
    required this.unitPrice,
    required this.quantity,
    required this.onAdd,
    this.compact = false,
  });

  final Color accent;
  final String currency;
  final double unitPrice;
  final int quantity;
  final VoidCallback onAdd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = unitPrice * quantity;
    final pad = compact
        ? const EdgeInsets.fromLTRB(16, 10, 16, 12)
        : const EdgeInsets.fromLTRB(16, 12, 16, 10);

    final row = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.commonTotal,
                style: TextStyle(
                  color: PosTheme.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatMoney(total, currency),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 22 : 24,
                  letterSpacing: -0.4,
                  color: accent,
                ),
              ),
              if (quantity > 1)
                Text(
                  '${formatMoney(unitPrice, currency)} × $quantity',
                  style: TextStyle(
                    color: PosTheme.inkFaint,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: Text(
                l10n.modifierAddToTicket,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(top: BorderSide(color: PosTheme.border)),
        boxShadow: [
          BoxShadow(
            color: PosTheme.ink.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // Desktop dialog has no home-indicator inset — skip SafeArea gap.
      child: compact
          ? row
          : SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: row,
            ),
    );
  }
}
