import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../providers/pos_register_preferences.dart';
import '../theme/pos_theme.dart';
import 'pos_offline_receipt_studio.dart';
import 'pos_ui.dart';

Future<void> showPosOrderTypeSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _OrderTypeSettingsDialog(),
  );
}

Future<void> showOfflineKotFormatDialog(BuildContext context) {
  return showOfflineReceiptFormatDialog(context, kitchen: true);
}

Future<void> showOfflineReceiptFormatDialog(
  BuildContext context, {
  bool kitchen = false,
}) {
  final height = MediaQuery.sizeOf(context).height;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => Dialog(
      backgroundColor: PosTheme.canvas,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 980, maxHeight: height * 0.9),
        child: PosOfflineReceiptStudio(initialKitchen: kitchen),
      ),
    ),
  );
}

class _OrderTypeSettingsDialog extends StatelessWidget {
  const _OrderTypeSettingsDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefs = context.watch<PosRegisterPreferences>();
    final server =
        context.select(
          (PosController p) =>
              p.bootstrap?.restaurant.ordering.activePosOrderTypes,
        ) ??
        posOrderTypes;
    final options = [
      ('dine_in', l10n.orderTypeDineIn, Icons.restaurant_rounded),
      ('takeaway', l10n.orderTypeTakeaway, Icons.shopping_bag_outlined),
      ('delivery', l10n.orderTypeDelivery, Icons.delivery_dining_rounded),
    ];

    return PosDialogShell(
      title: 'Order types',
      subtitle:
          'Show or hide Dine in, Takeaway, and Delivery on this register. A type turned off in the web admin stays hidden.',
      icon: Icons.restaurant_rounded,
      maxWidth: 460,
      onClose: () => Navigator.pop(context),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _OrderTypeSwitch(
              label: option.$2,
              icon: option.$3,
              serverAllows: server.contains(option.$1),
              enabled: prefs.isOrderTypeEnabled(option.$1),
              canTurnOff: prefs.visibleOrderTypes(server).length > 1,
              onChanged: (value) =>
                  prefs.setOrderTypeEnabled(option.$1, value),
            ),
        ],
      ),
    );
  }
}

class _OrderTypeSwitch extends StatelessWidget {
  const _OrderTypeSwitch({
    required this.label,
    required this.icon,
    required this.serverAllows,
    required this.enabled,
    required this.canTurnOff,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool serverAllows;
  final bool enabled;
  final bool canTurnOff;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final lockedOff = !serverAllows;
    final value = serverAllows && enabled;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: PosTheme.inkMuted),
      title: Text(label),
      subtitle: Text(
        lockedOff
            ? 'Turned off in the web admin'
            : value
            ? 'Shown on this register'
            : 'Hidden on this register',
      ),
      value: value,
      onChanged: lockedOff
          ? null
          : (next) {
              if (!next && !canTurnOff) return;
              onChanged(next);
            },
    );
  }
}
