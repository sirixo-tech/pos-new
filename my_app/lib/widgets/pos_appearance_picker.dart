import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_category_bar_settings.dart';
import '../providers/pos_theme_controller.dart';
import '../theme/pos_theme.dart';

/// Appearance picker dialog (system / light / dark).
Future<void> showPosAppearancePicker(BuildContext context) async {
  final themeController = context.read<PosThemeController>();
  final l10n = context.l10n;
  final accent = Theme.of(context).colorScheme.primary;
  final current = themeController.mode;

  final options = <(ThemeMode, IconData, String, String)>[
    (
      ThemeMode.system,
      Icons.brightness_auto_rounded,
      l10n.themeModeSystem,
      l10n.themeModeSystemHint,
    ),
    (
      ThemeMode.light,
      Icons.light_mode_rounded,
      l10n.themeModeLight,
      l10n.themeModeLightHint,
    ),
    (
      ThemeMode.dark,
      Icons.dark_mode_rounded,
      l10n.themeModeDark,
      l10n.themeModeDarkHint,
    ),
  ];

  final selected = await showDialog<ThemeMode>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.appearancePickerTitle),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.appearancePickerHint,
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
                      onTap: () => Navigator.of(dialogContext).pop(option.$1),
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
                                color: selected ? soft.bg : PosTheme.surface,
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
                                color: selected ? soft.fg : PosTheme.inkMuted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.$3,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: selected ? soft.fg : PosTheme.ink,
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
              const SizedBox(height: 8),
              Text(
                context.posText(
                  'categoryBarTitle',
                  'Categories',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: PosTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.posText(
                  'categoryBarHint',
                  'Choose where category chips sit on the POS menu. Saved on this device.',
                ),
                style: TextStyle(
                  color: PosTheme.inkMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Consumer<PosCategoryBarSettings>(
                builder: (context, bar, _) {
                  final placements = <(
                    PosCategoryBarPlacement,
                    IconData,
                    String,
                    String
                  )>[
                    (
                      PosCategoryBarPlacement.left,
                      Icons.view_sidebar_rounded,
                      context.posText('categoryBarLeft', 'Left'),
                      context.posText(
                        'categoryBarLeftHint',
                        'Vertical rail beside the item cards',
                      ),
                    ),
                    (
                      PosCategoryBarPlacement.top,
                      Icons.view_agenda_rounded,
                      context.posText('categoryBarTop', 'Top'),
                      context.posText(
                        'categoryBarTopHint',
                        'Horizontal chips above the item cards',
                      ),
                    ),
                  ];
                  return Column(
                    children: [
                      for (final option in placements)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Builder(
                            builder: (context) {
                              final soft = posAccentSoft(accent);
                              final selected = option.$1 == bar.placement;
                              return Material(
                                color: selected
                                    ? soft.bg
                                    : PosTheme.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => bar.setPlacement(option.$1),
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
                                            color: selected
                                                ? soft.bg
                                                : PosTheme.surface,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: selected
                                                  ? soft.fg.withValues(
                                                      alpha: 0.28,
                                                    )
                                                  : PosTheme.border,
                                            ),
                                          ),
                                          child: Icon(
                                            option.$2,
                                            size: 18,
                                            color: selected
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
                                          Icon(
                                            Icons.check_rounded,
                                            color: soft.fg,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
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
  await themeController.setMode(selected);
}

/// Compact app-bar control that opens the appearance picker.
class PosAppBarThemeButton extends StatelessWidget {
  const PosAppBarThemeButton({
    super.key,
    required this.accent,
    this.embedded = false,
  });

  final Color accent;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final mode = context.select((PosThemeController c) => c.mode);
    final l10n = context.l10n;
    final icon = switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };
    final label = switch (mode) {
      ThemeMode.light => l10n.themeModeLight,
      ThemeMode.dark => l10n.themeModeDark,
      ThemeMode.system => l10n.themeModeSystem,
    };

    if (embedded) {
      return Tooltip(
        message: '${l10n.shellAppearance}: $label',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showPosAppearancePicker(context),
            hoverColor: accent.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                icon,
                size: 18,
                color: PosTheme.ink.withValues(alpha: 0.78),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: '${l10n.shellAppearance}: $label',
        child: Material(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => showPosAppearancePicker(context),
            borderRadius: BorderRadius.circular(10),
            hoverColor: accent.withValues(alpha: 0.08),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PosTheme.border),
              ),
              child: Icon(
                icon,
                size: 18,
                color: PosTheme.ink.withValues(alpha: 0.78),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
