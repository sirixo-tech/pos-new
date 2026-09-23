import 'package:flutter/material.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../theme/pos_theme.dart';

/// Web-style selectable cards for assigning modifiers / time slots.
class AdminMenuOptionPicker extends StatelessWidget {
  const AdminMenuOptionPicker({
    super.key,
    required this.title,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    this.helpText,
    this.emptyText,
  });

  final String title;
  final List<AdminMenuPickerOption> options;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;
  final String? helpText;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final selectedCount = selectedIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            if (options.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PosTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: PosTheme.border),
                ),
                child: Text(
                  '$selectedCount',
                  style: TextStyle(
                    color: PosTheme.inkMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        if (helpText != null) ...[
          const SizedBox(height: 6),
          Text(
            helpText!,
            style: TextStyle(
              color: PosTheme.inkMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (options.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PosTheme.border,
                style: BorderStyle.solid,
              ),
              color: PosTheme.surfaceMuted.withValues(alpha: 0.5),
            ),
            child: Text(
              emptyText ??
                  context.posText('adminNothingToSelect', 'Nothing to select yet.'),
              style: TextStyle(
                color: PosTheme.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          for (final option in options) ...[
            _OptionCard(
              option: option,
              selected: selectedIds.contains(option.id),
              accent: accent,
              onTap: () {
                final next = [...selectedIds];
                if (next.contains(option.id)) {
                  next.remove(option.id);
                } else {
                  next.add(option.id);
                }
                onChanged(next);
              },
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class AdminMenuPickerOption {
  const AdminMenuPickerOption({
    required this.id,
    required this.label,
    this.description,
    this.live = false,
  });

  final int id;
  final String label;
  final String? description;
  final bool live;

  factory AdminMenuPickerOption.fromModifier(AdminMenuModifier mod) {
    final optionNames = mod.options
        .where((o) => o.name.trim().isNotEmpty)
        .map((o) => o.name.trim())
        .toList();
    final description = [
      mod.summaryLabel,
      if (optionNames.isNotEmpty) 'Options: ${optionNames.join(', ')}',
    ].join('\n');
    return AdminMenuPickerOption(
      id: mod.id,
      label: mod.name,
      description: description,
    );
  }

  factory AdminMenuPickerOption.fromTimeSlot(
    AdminMenuTimeSlot slot, {
    List<String> dayLabels = const [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ],
  }) {
    final days = slot.daysOfWeek.isEmpty
        ? 'Every day'
        : slot.daysOfWeek
            .where((d) => d >= 0 && d < dayLabels.length)
            .map((d) => dayLabels[d])
            .join(', ');
    return AdminMenuPickerOption(
      id: slot.id,
      label: slot.name,
      description: '${slot.windowLabel} · $days',
      live: slot.isLive,
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final AdminMenuPickerOption option;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    final liveTone = posStatusColors('ready');
    return Material(
      color: selected
          ? soft.bg
          : PosTheme.surfaceMuted.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? soft.fg.withValues(alpha: 0.4)
                  : PosTheme.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: selected ? soft.fg : PosTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? soft.fg : PosTheme.border,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: PosTheme.ink,
                            ),
                          ),
                        ),
                        if (option.live)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: liveTone.bg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: liveTone.fg.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Text(
                              context.posText('adminLive', 'Live'),
                              style: TextStyle(
                                color: liveTone.fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (option.description != null &&
                        option.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        option.description!,
                        style: TextStyle(
                          color: PosTheme.inkMuted,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
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
