import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../services/pos_auto_start.dart';
import '../theme/pos_theme.dart';
import 'pos_ui.dart';

/// Auto-start on boot enable/disable picker dialog.
Future<void> showPosAutoStartPicker(BuildContext context) async {
  final l10n = context.l10n;
  final accent = Theme.of(context).colorScheme.primary;
  final current = PosAutoStart.isEnabled;

  final options = <(bool, IconData, String, String)>[
    (
      true,
      Icons.power_settings_new_rounded,
      context.posText('posAutoStartEnabled', 'Auto-start enabled (Recommended)'),
      context.posText(
        'posAutoStartEnabledHint',
        'App opens automatically whenever the device powers on or restarts.',
      ),
    ),
    (
      false,
      Icons.power_off_rounded,
      context.posText('posAutoStartDisabled', 'Auto-start disabled'),
      context.posText(
        'posAutoStartDisabledHint',
        'App will not open on boot; you must launch it manually.',
      ),
    ),
  ];

  final selected = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          context.posText('posAutoStartTitle', 'Auto-start on boot'),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.posText(
                  'posAutoStartPickerHint',
                  'Automatically launch the app when the TV or POS device is powered on or restarted.',
                ),
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
                      final isSelected = option.$1 == current;
                      return Material(
                        color: isSelected ? soft.bg : PosTheme.surfaceMuted,
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
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? soft.bg
                                        : PosTheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? soft.fg.withValues(alpha: 0.28)
                                          : PosTheme.border,
                                    ),
                                  ),
                                  child: Icon(
                                    option.$2,
                                    size: 20,
                                    color: isSelected
                                        ? soft.fg
                                        : PosTheme.inkMuted,
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
                                          fontSize: 13.5,
                                          color: isSelected
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
                                if (isSelected)
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
  await PosAutoStart.setEnabled(selected);
  if (context.mounted) {
    showPosSnackBar(
      context,
      selected
          ? context.posText('posAutoStartTurnedOn', 'Auto-start on boot enabled')
          : context.posText('posAutoStartTurnedOff', 'Auto-start on boot disabled'),
    );
  }
}
