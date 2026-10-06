import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../services/pos_display_mode.dart';
import '../widgets/cart_quick_pay_layout_dialog.dart';
import '../widgets/pos_appearance_picker.dart';
import '../widgets/pos_auto_lock_picker.dart';
import '../widgets/pos_catalog_layout_picker.dart';
import '../widgets/pos_close_shift_dialog.dart';
import '../widgets/pos_language_switcher.dart';
import '../widgets/pos_open_shift_dialog.dart';
import '../widgets/pos_ops_bar.dart';
import '../widgets/pos_shortcuts_help.dart';
import '../widgets/pos_sound_settings_dialog.dart';
import '../widgets/pos_system_status_dialog.dart';
import '../widgets/pos_ui.dart';
import 'admin/admin_shell.dart';
import 'customer_display/customer_display_page.dart';
import 'customer_display/customer_display_setup_page.dart';
import 'customer_display/dqr222_advertisement_page.dart';
import 'help/pos_help_page.dart';
import 'pos_update_check_screen.dart';
import 'printer_setup_screen.dart';
import 'set_pos_pin_screen.dart';

/// Shared More-menu actions for the header menu and the phone Settings tab.
Future<void> handlePosRegisterMoreAction({
  required BuildContext context,
  required PosController pos,
  required AppLocalizations l10n,
  required String value,
  required bool hasPin,
  required ValueChanged<String> onOpenPartnerOrders,
  required VoidCallback onOpenDayEndReports,
  required VoidCallback onOpenNotifications,
  required VoidCallback onOpenDelivery,
  required Future<void> Function() onRefreshMenu,
  required Future<void> Function() onOpenCustomerDisplay,
}) async {
if (value == '_notifications') {
  onOpenNotifications();
} else if (value == '_delivery') {
  onOpenDelivery();
} else if (value == 'logout') {
  final ok = await showPosConfirmDialog(
    context,
    title: l10n.authSignOutTitle,
    message: hasPin
        ? l10n.authSignOutMessageWithPin
        : l10n.authSignOutMessageNoPin,
    confirmLabel: l10n.commonSignOut,
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  await pos.logout();
} else if (value.endsWith('_orders') &&
    value != 'held_orders' &&
    value.length > '_orders'.length) {
  final provider = value.substring(0, value.length - '_orders'.length);
  final enabled =
      context.read<PosController>().bootstrap?.marketplaceEnabled(
        provider,
      ) ??
      false;
  if (enabled) {
    onOpenPartnerOrders(provider);
  }
} else if (value == 'refresh') {
  await onRefreshMenu();
} else if (value == 'terminal') {
  await pos.changeTerminal();
} else if (value == 'location') {
  await pos.openLocationPicker();
} else if (value == 'lock') {
  pos.lockSession();
} else if (value == 'pin') {
  await SetPosPinScreen.open(context);
} else if (value == 'printer') {
  await PrinterSetupScreen.open(context);
} else if (value == 'quick_pay_layout') {
  if (context.mounted) {
    await showCartQuickPayLayoutDialog(context);
  }
} else if (value == 'sounds') {
  if (context.mounted) {
    await showPosSoundSettingsDialog(context);
  }
} else if (value == 'customer_display') {
  if (context.mounted) {
      await onOpenCustomerDisplay();
  }
} else if (value == 'token_display') {
  if (context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CustomerDisplayPage()),
    );
  }
} else if (value == 'cart_display') {
  if (context.mounted) {
    final posState = context.read<PosController>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerCartDisplayPage(
          branchId: posState.session?.branchId,
          terminalCode: posState.selectedTerminalCode,
        ),
      ),
    );
  }
} else if (value == 'qr_pairing') {
  if (context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CustomerDisplaySetupPage(),
      ),
    );
  }
} else if (value == 'sync') {
  final before = pos.pendingOrderCount;
  await pos.syncPendingOrders();
  if (!context.mounted) return;
  final remaining = pos.pendingOrderCount;
  if (before == 0 && remaining == 0) {
    showPosSnackBar(context, l10n.offlineSyncNothingPending);
  } else if (remaining > 0) {
    showPosSnackBar(
      context,
      l10n.offlineSyncPartial(remaining),
      error: true,
    );
  } else {
    showPosSnackBar(context, l10n.shellSyncCompleted);
  }
} else if (value == 'updates') {
  await openPosUpdateCheckScreen(context);
} else if (value == 'shortcuts') {
  await showPosShortcutsDialog(context);
} else if (value == 'language') {
  await showPosLanguagePicker(context);
} else if (value == 'unpair') {
  await pos.clearDeviceBinding();
  if (context.mounted) {
    showPosSnackBar(context, l10n.shellPairingCleared);
  }
} else if (value == 'reports') {
  onOpenDayEndReports();
} else if (value == 'appearance') {
  await showPosAppearancePicker(context);
} else if (value == 'item_images') {
  await showPosCatalogLayoutPicker(context);
} else if (value == 'help') {
  if (context.mounted) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PosHelpPage()));
  }
} else if (value == 'dqr_images') {
  if (context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Dqr222AdvertisementPage(),
      ),
    );
  }
} else if (value == 'auto_lock') {
  await showPosAutoLockPicker(context);
} else if (value == 'fullscreen') {
  if (PosDisplayMode.supportsToggle) {
    final enabled = await PosDisplayMode.toggle();
    if (context.mounted) {
      showPosSnackBar(
        context,
        enabled
            ? context.posText('shellFullscreenOn', 'Fullscreen on')
            : context.posText('shellFullscreenOff', 'Fullscreen off'),
      );
    }
  }
} else if (value == 'store_toggle') {
  await togglePosGuestStore(context);
} else if (value == 'open_shift') {
  await PosOpenShiftDialog.show(context);
} else if (value == 'close_shift') {
  await PosCloseShiftDialog.show(context);
} else if (value == 'waiter_mode') {
  final ok = await showPosConfirmDialog(
    context,
    title: l10n.waiterSwitchToWaiter,
    message: l10n.waiterSwitchToWaiterConfirm,
    confirmLabel: l10n.commonContinue,
  );
  if (!ok || !context.mounted) return;
  await pos.switchWorkMode(PosWorkMode.waiter);
} else if (value == 'change_mode') {
  await pos.clearWorkModeAndPick();
} else if (value == 'status') {
  await showPosSystemStatusDialog(context);
} else if (value == 'menu') {
  await openPosAdminMenuSheet(context);
} else if (value == 'manage') {
  await openPosAdminShell(context);
}
}
