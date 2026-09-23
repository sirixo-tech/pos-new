import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../providers/pos_admin_controller.dart';
import '../../providers/pos_controller.dart';
import '../../theme/pos_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pos_ui.dart';
import 'admin_chrome.dart';
import 'admin_modifier_edit_dialog.dart';

class AdminModifiersScreen extends StatefulWidget {
  const AdminModifiersScreen({super.key});

  @override
  State<AdminModifiersScreen> createState() => _AdminModifiersScreenState();
}

class _AdminModifiersScreenState extends State<AdminModifiersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<PosAdminController>();
      if (admin.modifiers.isEmpty) {
        admin.loadMenu();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminMenuModifier> _filtered(List<AdminMenuModifier> modifiers) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return modifiers;
    return modifiers.where((m) {
      if (m.name.toLowerCase().contains(q)) return true;
      return m.options.any((o) => o.name.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<PosAdminController>();
    final currency = context.watch<PosController>().currency;
    final canManage =
        admin.canManageMenuModifiers || admin.canManageMenu;
    final modifiers = _filtered(admin.modifiers);
    final requiredCount =
        admin.modifiers.where((m) => m.isRequired).length;
    final optionCount =
        admin.modifiers.fold<int>(0, (n, m) => n + m.options.length);

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        title: Text(context.posText('adminModifiers', 'Modifiers')),
      ),
      body: admin.menuLoading && admin.modifiers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : admin.error != null && admin.modifiers.isEmpty
              ? AdminErrorPane(
                  message: admin.error!,
                  onRetry: admin.loadMenu,
                )
              : Column(
                  children: [
                    AdminToolbar(
                      leading: SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: context.posText(
                              'adminModifiersSearch',
                              'Search modifiers & options',
                            ),
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: context.l10n.commonClear,
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                            isDense: true,
                            filled: true,
                            fillColor: PosTheme.surfaceMuted,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusSm),
                              borderSide: BorderSide(color: PosTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusSm),
                              borderSide: BorderSide(color: PosTheme.border),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      children: [
                        IconButton.filledTonal(
                          tooltip: context.l10n.commonRefresh,
                          onPressed:
                              admin.menuLoading ? null : admin.loadMenu,
                          icon: admin.menuLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 20),
                        ),
                        if (canManage)
                          FilledButton.icon(
                            onPressed: admin.mutating
                                ? null
                                : () => _edit(context, admin),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              context.posText(
                                'adminNewModifier',
                                'New modifier',
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (admin.modifiers.isNotEmpty)
                      _ModifiersSummaryBar(
                        total: admin.modifiers.length,
                        requiredCount: requiredCount,
                        optionCount: optionCount,
                        filtered: _query.trim().isNotEmpty,
                        filteredCount: modifiers.length,
                      ),
                    if (admin.error != null)
                      AdminInlineError(
                        message: admin.error!,
                        onDismiss: admin.clearError,
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: admin.loadMenu,
                        child: admin.modifiers.isEmpty
                            ? AdminEmptyPane(
                                icon: Icons.tune_rounded,
                                title: context.posText(
                                  'adminModifiersEmpty',
                                  'No modifiers yet.',
                                ),
                                subtitle: context.posText(
                                  'adminModifiersEmptyHint',
                                  'Add size, toppings, or add-ons for menu items.',
                                ),
                                action: canManage
                                    ? FilledButton.icon(
                                        onPressed: admin.mutating
                                            ? null
                                            : () => _edit(context, admin),
                                        icon: const Icon(Icons.add_rounded),
                                        label: Text(
                                          context.posText(
                                            'adminNewModifier',
                                            'New modifier',
                                          ),
                                        ),
                                      )
                                    : null,
                              )
                            : modifiers.isEmpty
                                ? AdminEmptyPane(
                                    icon: Icons.search_off_rounded,
                                    title: context.posText(
                                      'adminModifiersNoMatch',
                                      'No matches',
                                    ),
                                    subtitle: context.posText(
                                      'adminModifiersNoMatchHint',
                                      'Try a different search term.',
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final columns =
                                          constraints.maxWidth >= 1100
                                              ? 3
                                              : constraints.maxWidth >= 720
                                                  ? 2
                                                  : 1;
                                      const gap = 12.0;
                                      const pad = 14.0;
                                      final usable = constraints.maxWidth -
                                          (pad * 2) -
                                          (gap * (columns - 1));
                                      final cardWidth = usable / columns;
                                      return ListView(
                                        padding: const EdgeInsets.fromLTRB(
                                          pad,
                                          12,
                                          pad,
                                          28,
                                        ),
                                        children: [
                                          Wrap(
                                            spacing: gap,
                                            runSpacing: gap,
                                            children: [
                                              for (final mod in modifiers)
                                                SizedBox(
                                                  width: cardWidth,
                                                  child: _ModifierCard(
                                                    modifier: mod,
                                                    currency: currency,
                                                    canManage: canManage,
                                                    busy: admin.mutating,
                                                    onEdit: () => _edit(
                                                      context,
                                                      admin,
                                                      modifier: mod,
                                                    ),
                                                    onDelete: () => _delete(
                                                      context,
                                                      admin,
                                                      mod,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    PosAdminController admin, {
    AdminMenuModifier? modifier,
  }) async {
    final result = await showAdminModifierEditDialog(
      context,
      modifier: modifier,
    );
    if (result == null) return;

    final body = result.toBody();
    if (modifier == null) {
      await admin.createModifier(body);
    } else {
      await admin.updateModifier(modifier.id, body);
    }
  }

  Future<void> _delete(
    BuildContext context,
    PosAdminController admin,
    AdminMenuModifier modifier,
  ) async {
    final ok = await showPosConfirmDialog(
      context,
      title: context.posText('adminDeleteModifier', 'Delete modifier?'),
      message: modifier.name,
      destructive: true,
    );
    if (!ok) return;
    await admin.deleteModifier(modifier.id);
  }
}

class _ModifiersSummaryBar extends StatelessWidget {
  const _ModifiersSummaryBar({
    required this.total,
    required this.requiredCount,
    required this.optionCount,
    required this.filtered,
    required this.filteredCount,
  });

  final int total;
  final int requiredCount;
  final int optionCount;
  final bool filtered;
  final int filteredCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (filtered) {
      parts.add(
        context.posText(
          'adminModifiersShowing',
          'Showing {n} of {total}',
          {'n': '$filteredCount', 'total': '$total'},
        ),
      );
    } else {
      parts.add(
        context.posText(
          'adminModifiersCount',
          '{n} modifiers',
          {'n': '$total'},
        ),
      );
      if (requiredCount > 0) {
        parts.add(
          context.posText(
            'adminModifiersRequiredCount',
            '{n} required',
            {'n': '$requiredCount'},
          ),
        );
      }
      parts.add(
        context.posText(
          'adminModifiersOptionsCount',
          '{n} options',
          {'n': '$optionCount'},
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          parts.join('  ·  '),
          style: TextStyle(
            color: PosTheme.inkMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _ModifierCard extends StatelessWidget {
  const _ModifierCard({
    required this.modifier,
    required this.currency,
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminMenuModifier modifier;
  final String currency;
  final bool canManage;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _previewCount = 6;

  String _rulesLabel(BuildContext context) {
    final parts = <String>[];
    if (modifier.isRequired) {
      parts.add(context.posText('adminRequired', 'Required'));
    }
    final max = modifier.maxSelections;
    final min = modifier.minSelections;
    if (max == 1) {
      parts.add(context.posText('adminModifiersPickOne', 'Pick one'));
    } else if (max != null && max > 0) {
      if (min > 0 && min == max) {
        parts.add(
          context.posText(
            'adminModifiersPickExactly',
            'Pick exactly {n}',
            {'n': '$max'},
          ),
        );
      } else {
        parts.add(
          context.posText(
            'adminModifiersPickUpTo',
            'Pick up to {n}',
            {'n': '$max'},
          ),
        );
      }
    } else if (min > 0) {
      parts.add(
        context.posText(
          'adminModifiersPickAtLeast',
          'Pick at least {n}',
          {'n': '$min'},
        ),
      );
    } else {
      parts.add(context.posText('adminModifiersPickAny', 'Pick any'));
    }
    return parts.join(' · ');
  }

  String? _priceLabel(double amount) {
    if (amount == 0) return null;
    final formatted = formatMoney(amount.abs(), currency);
    return amount > 0 ? '+$formatted' : '-$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final required = modifier.isRequired;
    final options = modifier.options;
    final availableCount = options.where((o) => o.isAvailable).length;
    final preview = options.take(_previewCount).toList();
    final remaining = options.length - preview.length;
    final soft = posAccentSoft(accent);
    final stripColor = required ? accent : PosTheme.inkFaint;
    final iconBg = required ? accent : soft.bg;
    final iconColor = required ? Colors.white : soft.fg;

    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
      child: InkWell(
        onTap: canManage && !busy ? onEdit : null,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusMd),
            border: Border.all(
              color: required
                  ? accent.withValues(alpha: 0.28)
                  : PosTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: stripColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(PosTheme.radiusMd - 1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      modifier.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: PosTheme.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _StatusPill(
                                    label: required
                                        ? context.posText(
                                            'adminRequired',
                                            'Required',
                                          )
                                        : context.posText(
                                            'adminOptional',
                                            'Optional',
                                          ),
                                    color: required
                                        ? accent
                                        : PosTheme.inkMuted,
                                    filled: required,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _rulesLabel(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: PosTheme.inkMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canManage) ...[
                          const SizedBox(width: 4),
                          _IconAction(
                            tooltip: context.posText('commonEdit', 'Edit'),
                            icon: Icons.edit_outlined,
                            color: accent,
                            onPressed: busy ? null : onEdit,
                          ),
                          _IconAction(
                            tooltip:
                                context.posText('commonDelete', 'Delete'),
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFDC2626),
                            onPressed: busy ? null : onDelete,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          label: context.posText(
                            'adminModifiersOptionsCount',
                            '{n} options',
                            {'n': '${options.length}'},
                          ),
                          icon: Icons.layers_outlined,
                        ),
                        if (options.isNotEmpty)
                          _MetaChip(
                            label: context.posText(
                              'adminModifiersAvailableCount',
                              '{available}/{total} available',
                              {
                                'available': '$availableCount',
                                'total': '${options.length}',
                              },
                            ),
                            icon: Icons.check_circle_outline_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (options.isEmpty)
                      Text(
                        context.posText(
                          'adminModifiersNoOptions',
                          'No options yet',
                        ),
                        style: TextStyle(
                          color: PosTheme.inkFaint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final opt in preview)
                            _OptionChip(
                              name: opt.name,
                              priceLabel: _priceLabel(opt.priceAdjustment),
                              available: opt.isAvailable,
                            ),
                          if (remaining > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: soft.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: soft.fg.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Text(
                                context.posText(
                                  'adminModifiersMoreOptions',
                                  '+{n} more',
                                  {'n': '$remaining'},
                                ),
                                style: TextStyle(
                                  color: soft.fg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.filled,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? soft.bg : PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled
              ? soft.fg.withValues(alpha: PosTheme.isDark ? 0.28 : 0.28)
              : PosTheme.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? soft.fg : PosTheme.inkMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: PosTheme.inkMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: PosTheme.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.name,
    required this.priceLabel,
    required this.available,
  });

  final String name;
  final String? priceLabel;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final ink = available ? PosTheme.ink : PosTheme.inkFaint;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: available ? PosTheme.surface : PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration:
                    available ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          if (priceLabel != null) ...[
            const SizedBox(width: 4),
            Text(
              priceLabel!,
              style: TextStyle(
                color: available
                    ? const Color(0xFF059669)
                    : PosTheme.inkFaint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(color);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: soft.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: soft.fg.withValues(alpha: 0.28)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 15, color: soft.fg),
          ),
        ),
      ),
    );
  }
}
