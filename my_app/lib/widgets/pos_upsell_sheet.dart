import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/media_url.dart';
import 'pos_overlay.dart';

/// Pre-payment upsell bottom sheet for POS.
class PosUpsellSheet {
  static Future<bool> show(
    BuildContext context, {
    required List<MenuItem> items,
    required String currency,
    required void Function(MenuItem item) onAdd,
    required void Function(MenuItem item) onOpenOptions,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PosKeyboardSheetHost(
        child: _PosUpsellSheetBody(
          items: items,
          currency: currency,
          onAdd: onAdd,
          onOpenOptions: onOpenOptions,
        ),
      ),
    );
    return result ?? false;
  }
}

class _PosUpsellSheetBody extends StatelessWidget {
  const _PosUpsellSheetBody({
    required this.items,
    required this.currency,
    required this.onAdd,
    required this.onOpenOptions,
  });

  final List<MenuItem> items;
  final String currency;
  final void Function(MenuItem item) onAdd;
  final void Function(MenuItem item) onOpenOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = PosTheme.defaultAccent;

    return DraggableScrollableSheet(
      initialChildSize: kPosMobileSheetInitialSize,
      minChildSize: kPosMobileSheetMinSize,
      maxChildSize: kPosMobileSheetMaxSize,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: PosTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.upsellTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.upsellSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final pos = context.read<PosController>();
                    final imageUrl = resolveMediaUrl(
                      item.imageUrl,
                      serverUrl: pos.serverUrl ?? pos.session?.serverUrl,
                    );
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                )
                              : ColoredBox(color: Colors.grey.shade200),
                        ),
                      ),
                      title: Text(
                        item.localizedName(
                          Localizations.localeOf(context).languageCode,
                        ),
                      ),
                      subtitle: Text(formatMoney(item.price, currency)),
                      trailing: FilledButton(
                        onPressed: () {
                          if (item.hasOptions) {
                            onOpenOptions(item);
                          } else {
                            onAdd(item);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size(64, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text(l10n.upsellAdd),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(backgroundColor: accent),
                      child: Text(l10n.commonContinue),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
