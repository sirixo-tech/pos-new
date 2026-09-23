import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/cart_quick_pay_settings.dart';
import '../theme/pos_theme.dart';
import 'pos_ui.dart';

Future<void> showCartQuickPayLayoutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _CartQuickPayLayoutDialog(),
  );
}

class _CartQuickPayLayoutDialog extends StatelessWidget {
  const _CartQuickPayLayoutDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.watch<CartQuickPaySettings>();
    final keys = settings.orderedKeys;

    return PosDialogShell(
      title: context.posText('cartQuickPayLayout', 'Arrange quick pay'),
      subtitle: context.posText(
        'cartQuickPayLayoutHint',
        'Drag to reorder. Hide methods you do not use. At least one of Cash, UPI, or Card stays visible.',
      ),
      icon: Icons.tune_rounded,
      maxWidth: 460,
      onClose: () => Navigator.pop(context),
      body: SizedBox(
        height: 380,
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: keys.length,
          onReorder: (oldIndex, newIndex) {
            context.read<CartQuickPaySettings>().reorder(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final key = keys[index];
            final visible = settings.isVisible(key);
            final canHide = settings.canHide(key);
            return Padding(
              key: ValueKey(key),
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: PosTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                      Icon(
                        CartQuickPaySettings.iconFor(key),
                        size: 18,
                        color: visible ? PosTheme.ink : PosTheme.inkFaint,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CartQuickPaySettings.labelFor(context, key),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: visible ? PosTheme.ink : PosTheme.inkFaint,
                              ),
                            ),
                            Text(
                              CartQuickPaySettings.hintFor(key),
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
                      Switch.adaptive(
                        value: visible,
                        onChanged: !visible || canHide
                            ? (value) => context
                                .read<CartQuickPaySettings>()
                                .setVisible(key, value)
                            : null,
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
      footer: posDialogActionFooter(
        context: context,
        onCancel: () {
          context.read<CartQuickPaySettings>().resetToDefault();
        },
        onConfirm: () => Navigator.pop(context),
        cancelLabel: context.posText('commonReset', 'Reset'),
        confirmLabel: l10n.commonDone,
      ),
    );
  }
}
