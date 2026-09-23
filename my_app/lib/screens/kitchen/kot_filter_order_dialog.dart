import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../providers/kitchen_kot_filter_order.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_ui.dart';
import 'kitchen_channel_filter.dart';

Future<void> showKotFilterOrderDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _KotFilterOrderDialog(),
  );
}

class _KotFilterOrderDialog extends StatelessWidget {
  const _KotFilterOrderDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final order = context.watch<KitchenKotFilterOrder>();
    final keys = order.keys;

    return PosDialogShell(
      title: context.posText('kotRearrangeFilters', 'Rearrange KOT filters'),
      subtitle: context.posText(
        'kotRearrangeFiltersHint',
        'Drag filters to change how they appear on kitchen screens.',
      ),
      icon: Icons.tune_rounded,
      maxWidth: 460,
      onClose: () => Navigator.pop(context),
      body: SizedBox(
        height: 420,
        child: Column(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: keys.length,
                onReorder: (oldIndex, newIndex) {
                  context.read<KitchenKotFilterOrder>().reorder(
                    oldIndex,
                    newIndex,
                  );
                },
                itemBuilder: (context, index) {
                  final key = keys[index];
                  final color = kitchenKotFilterColor(key);
                  return Padding(
                    key: ValueKey(key),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: PosTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: PosTheme.border,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: PosTheme.inkMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                kitchenKotFilterIcon(key),
                                color: color,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    kitchenKotFilterLabel(context, key),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    kitchenKotFilterDescription(context, key),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: PosTheme.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: PosTheme.inkMuted,
                              ),
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
        ),
      ),
      footer: posDialogActionFooter(
        context: context,
        onCancel: () {
          context.read<KitchenKotFilterOrder>().resetToDefault();
        },
        onConfirm: () => Navigator.pop(context),
        cancelLabel: context.posText('kotResetFilterOrder', 'Reset order'),
        confirmLabel: l10n.commonDone,
      ),
    );
  }
}

class KitchenKotFilterTuneButton extends StatelessWidget {
  const KitchenKotFilterTuneButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.posText('kotRearrangeFilters', 'Rearrange KOT filters'),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size(compact ? 28 : 32, compact ? 28 : 32),
        padding: EdgeInsets.zero,
      ),
      onPressed: () => showKotFilterOrderDialog(context),
      icon: Icon(Icons.tune_rounded, size: compact ? 16 : 18),
    );
  }
}
