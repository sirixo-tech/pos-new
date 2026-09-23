import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_idle_lock_controller.dart';
import '../theme/pos_theme.dart';

/// Auto-lock on/off picker for this register.
Future<void> showPosAutoLockPicker(BuildContext context) async {
  final controller = context.read<PosIdleLockController>();
  final l10n = context.l10n;
  final accent = Theme.of(context).colorScheme.primary;
  final current = controller.enabled;

  final options = <(bool, IconData, String, String)>[
    (
      true,
      Icons.timer_outlined,
      l10n.autoLockEnabled,
      l10n.autoLockEnabledHint,
    ),
    (
      false,
      Icons.lock_open_rounded,
      l10n.autoLockDisabled,
      l10n.autoLockDisabledHint,
    ),
  ];

  final selected = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.autoLockPickerTitle),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.autoLockPickerHint,
                style: TextStyle(
                  color: PosTheme.inkMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Builder(
                    builder: (context) {
                      final soft = posAccentSoft(accent);
                      final selected = option.$1 == current;
                      return Material(
                        color: selected ? soft.bg : PosTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              Navigator.of(dialogContext).pop(option.$1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color:
                                        selected ? soft.bg : PosTheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? soft.fg.withValues(alpha: 0.28)
                                          : PosTheme.border,
                                    ),
                                  ),
                                  child: Icon(
                                    option.$2,
                                    size: 18,
                                    color:
                                        selected ? soft.fg : PosTheme.inkMuted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.$3,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? soft.fg
                                              : PosTheme.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option.$4,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: PosTheme.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(Icons.check_rounded, color: soft.fg),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
        ],
      );
    },
  );

  if (selected == null) return;
  await controller.setEnabled(selected);
}
