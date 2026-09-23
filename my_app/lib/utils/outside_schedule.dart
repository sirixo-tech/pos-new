import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../widgets/pos_ui.dart';

/// Confirms before adding an item that is sold out or outside its menu time slot.
/// Returns true when the item is fully available or the cashier confirms.
Future<bool> confirmOutsideScheduleIfNeeded(
  BuildContext context,
  MenuItem item,
) async {
  if (item.isManuallyUnavailable) {
    return showPosConfirmDialog(
      context,
      title: context.posText('menuNotAvailableTitle', 'Not available?'),
      message: context.posText(
        'menuNotAvailableMessage',
        '{name} is marked not available. Add it to this ticket anyway?',
        {'name': item.name},
      ),
      confirmLabel: context.posText('menuNotAvailableConfirm', 'Add anyway'),
      icon: Icons.block_rounded,
    );
  }

  if (!item.isOutsideSchedule) {
    return true;
  }

  return showPosConfirmDialog(
    context,
    title: context.posText('menuOutsideScheduleTitle', 'Outside schedule?'),
    message: context.posText(
      'menuOutsideScheduleMessage',
      '{name} is outside its menu time slot. Add it to this ticket anyway?',
      {'name': item.name},
    ),
    confirmLabel: context.posText('menuOutsideScheduleConfirm', 'Add anyway'),
    icon: Icons.schedule_rounded,
  );
}
