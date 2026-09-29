import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pos_catalog_layout_settings.dart';
import '../theme/pos_theme.dart';

Future<void> showPosCatalogLayoutPicker(BuildContext context) {
  final settings = context.read<PosCatalogLayoutSettings>();
  final accent = Theme.of(context).colorScheme.primary;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Item images'),
        content: SizedBox(
          width: 420,
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              const options = <(PosCatalogLayout, IconData, String, String)>[
                (
                  PosCatalogLayout.images,
                  Icons.image_outlined,
                  'Images',
                  'Item photos on the cards. Items without a photo use color tiles',
                ),
                (
                  PosCatalogLayout.colorCards,
                  Icons.palette_outlined,
                  'Color cards · no images',
                  'Names and prices only. No item or category photos',
                ),
                (
                  PosCatalogLayout.categoryImages,
                  Icons.dashboard_customize_outlined,
                  'Category images · color cards',
                  'Category photos stay. Item cards have no photo',
                ),
              ];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'This register only. Menu data is unchanged.',
                    style: TextStyle(color: PosTheme.inkMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  for (final option in options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: settings.layout == option.$1
                            ? posAccentSoft(accent).bg
                            : PosTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => settings.setLayout(option.$1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  option.$2,
                                  size: 20,
                                  color: settings.layout == option.$1
                                      ? accent
                                      : PosTheme.inkMuted,
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
                                          color: PosTheme.ink,
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
                                if (settings.layout == option.$1)
                                  Icon(Icons.check_rounded, color: accent),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}
