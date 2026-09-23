import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../providers/pos_locale_controller.dart';
import '../theme/pos_theme.dart';

/// Keeps [PosLocaleController] in sync with restaurant bootstrap languages.
class PosLocaleBootstrapSync extends StatefulWidget {
  const PosLocaleBootstrapSync({super.key});

  @override
  State<PosLocaleBootstrapSync> createState() => _PosLocaleBootstrapSyncState();
}

class _PosLocaleBootstrapSyncState extends State<PosLocaleBootstrapSync> {
  String? _syncedKey;

  @override
  Widget build(BuildContext context) {
    final bootstrap = context.watch<PosController>().bootstrap;
    // Include string counts + bootstrap revision so catalog copy updates
    // (e.g. new adminHours keys) re-sync even when locale list is unchanged.
    final catalogWeight = bootstrap == null
        ? 0
        : bootstrap.languageCatalogs.values
            .fold<int>(0, (sum, catalog) => sum + catalog.length);
    final key = bootstrap == null
        ? 'none'
        : '${bootstrap.restaurant.id}|'
            '${bootstrap.supportedLanguages.map((l) => l.code).join(',')}|'
            '${bootstrap.showLanguageSwitcher}|'
            '${bootstrap.languageCatalogs.length}|'
            '$catalogWeight|'
            '${bootstrap.sync?.bootstrapRevision ?? ''}';

    if (key != _syncedKey) {
      _syncedKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PosLocaleController>().syncFromBootstrap(bootstrap);
      });
    }

    return const SizedBox.shrink();
  }
}

/// Language picker dialog for staff POS.
Future<void> showPosLanguagePicker(
  BuildContext context, {
  bool force = false,
}) async {
  final localeController = context.read<PosLocaleController>();
  if (!force && !localeController.showSwitcher) return;
  if (localeController.availableLocales.length < 2) return;

  final l10n = context.l10n;
  final accent = Theme.of(context).colorScheme.primary;
  final options = localeController.availableLocales;
  final current = localeController.locale.languageCode;

  final soft = posAccentSoft(accent);
  final selected = await showDialog<Locale>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.languagePickerTitle),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.languagePickerHint,
                style: TextStyle(
                  color: PosTheme.inkMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              for (final locale in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: locale.languageCode == current
                        ? soft.bg
                        : PosTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(dialogContext).pop(locale),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                localeController.displayNameFor(locale),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: locale.languageCode == current
                                      ? soft.fg
                                      : PosTheme.ink,
                                ),
                              ),
                            ),
                            if (locale.languageCode == current)
                              Icon(Icons.check_rounded, color: soft.fg),
                          ],
                        ),
                      ),
                    ),
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

  if (selected != null && context.mounted) {
    await localeController.setLocale(selected);
  }
}
