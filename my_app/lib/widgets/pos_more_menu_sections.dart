import 'package:flutter/material.dart';

import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../services/pos_display_mode.dart';
import '../utils/marketplace_platform_ui.dart';
import 'pos_more_menu.dart';

/// Same More actions, grouped so store, register, display, security,
/// hardware, and account are separate.
List<PosMoreMenuSection> buildPosMoreMenuSections({
  required BuildContext context,
  required AppLocalizations l10n,
  required bool storeAccepting,
  required String storeStatusLabel,
  required bool canManageStore,
  required bool canAccessAdmin,
  required bool canViewMenu,
  required List<MarketplacePlatformInfo> marketplacePlatforms,
  required bool showLanguageSwitcher,
  required int terminalCount,
  required bool canChangeLocation,
  required bool hasPin,
  required bool canUseCaptain,
  required bool canChooseWorkMode,
  required bool checkingForUpdates,
  required int pendingOrderCount,
  required bool hasDeviceBinding,
  required bool includeShortcuts,
}) {
  List<PosMoreMenuSection> sections = [
    PosMoreMenuSection(
      title: 'Store',
      items: [
        PosMoreMenuItem(
          id: 'store_toggle',
          icon: storeAccepting
              ? Icons.pause_circle_filled_rounded
              : Icons.storefront_rounded,
          label: storeAccepting ? l10n.storeCloseConfirm : l10n.storeOpenConfirm,
          subtitle: storeStatusLabel,
          badge: storeStatusLabel,
          enabled: canManageStore,
        ),
        for (final platform in marketplacePlatforms)
          PosMoreMenuItem(
            id: '${platform.provider}_orders',
            icon: Icons.delivery_dining_rounded,
            label: marketplacePlatformDisplayLabel(l10n, platform),
          ),
      ],
    ),
    PosMoreMenuSection(
      title: 'Register',
      items: [
        PosMoreMenuItem(
          id: 'status',
          icon: Icons.monitor_heart_outlined,
          label: 'Status',
        ),
        PosMoreMenuItem(
          id: 'reports',
          icon: Icons.summarize_rounded,
          label: l10n.shellReports,
        ),
        if (canAccessAdmin && canViewMenu)
          PosMoreMenuItem(
            id: 'menu',
            icon: Icons.menu_book_outlined,
            label: l10n.adminMenu,
          ),
        if (canAccessAdmin)
          PosMoreMenuItem(
            id: 'manage',
            icon: Icons.admin_panel_settings_rounded,
            label: 'Administration',
          ),
        PosMoreMenuItem(
          id: 'refresh',
          icon: Icons.refresh_rounded,
          label: l10n.shellRefreshMenu,
        ),
        if (includeShortcuts)
          PosMoreMenuItem(
            id: 'shortcuts',
            icon: Icons.keyboard_alt_outlined,
            label: l10n.shellKeyboardShortcuts,
          ),
      ],
    ),
    PosMoreMenuSection(
      title: 'Display',
      items: [
        PosMoreMenuItem(
          id: 'appearance',
          icon: Icons.palette_outlined,
          label: l10n.shellAppearance,
        ),
        PosMoreMenuItem(
          id: 'item_images',
          icon: Icons.image_outlined,
          label: 'Item images',
          subtitle: 'Show or hide photos on item cards',
        ),
        if (showLanguageSwitcher)
          PosMoreMenuItem(
            id: 'language',
            icon: Icons.language_rounded,
            label: l10n.shellLanguage,
          ),
      ],
    ),
    PosMoreMenuSection(
      title: 'Security',
      items: [
        if (hasPin)
          PosMoreMenuItem(
            id: 'lock',
            icon: Icons.lock_rounded,
            label: l10n.shellLockRegister,
          ),
        if (hasPin)
          PosMoreMenuItem(
            id: 'auto_lock',
            icon: Icons.timer_outlined,
            label: l10n.shellAutoLock,
          ),
        PosMoreMenuItem(
          id: 'pin',
          icon: Icons.pin_rounded,
          label: hasPin ? l10n.pinChangeTitle : l10n.pinSetTitle,
        ),
        if (terminalCount > 1)
          PosMoreMenuItem(
            id: 'terminal',
            icon: Icons.monitor_rounded,
            label: l10n.shellChangeRegister,
          ),
        if (canChangeLocation)
          PosMoreMenuItem(
            id: 'location',
            icon: Icons.storefront_outlined,
            label: l10n.shellChangeLocation,
          ),
        if (canUseCaptain)
          PosMoreMenuItem(
            id: 'waiter_mode',
            icon: Icons.room_service_rounded,
            label: l10n.waiterSwitchToWaiter,
          ),
        if (canChooseWorkMode)
          PosMoreMenuItem(
            id: 'change_mode',
            icon: Icons.devices_other_rounded,
            label: l10n.waiterChangeMode,
          ),
      ],
    ),
    PosMoreMenuSection(
      title: l10n.shellMenuDevice,
      items: [
        if (PosDisplayMode.supportsToggle)
          PosMoreMenuItem(
            id: 'fullscreen',
            icon: PosDisplayMode.enabled
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            label: PosDisplayMode.enabled
                ? context.posText('shellExitFullscreen', 'Exit fullscreen')
                : context.posText('shellEnterFullscreen', 'Enter fullscreen'),
          ),
        PosMoreMenuItem(
          id: 'printer',
          icon: Icons.print_outlined,
          label: l10n.printerSetupTitle,
        ),
        PosMoreMenuItem(
          id: 'quick_pay_layout',
          icon: Icons.tune_rounded,
          label: context.posText('cartQuickPayLayout', 'Arrange quick pay'),
          subtitle: context.posText(
            'cartQuickPayLayoutHint',
            'Reorder or hide Cash, UPI, Card, More',
          ),
        ),
        PosMoreMenuItem(
          id: 'sounds',
          icon: Icons.volume_up_outlined,
          label: 'Sound settings',
        ),
        PosMoreMenuItem(
          id: 'customer_display',
          icon: Icons.tv_rounded,
          label: context.posText('shellCustomerDisplay', 'Customer display'),
        ),
        PosMoreMenuItem(
          id: 'dqr_images',
          icon: Icons.slideshow_outlined,
          label: 'DQR images',
          subtitle: 'Change the images on the customer display',
        ),
        PosMoreMenuItem(
          id: 'token_display',
          icon: Icons.confirmation_number_outlined,
          label: context.posText('shellTokenDisplay', 'Token display'),
        ),
        PosMoreMenuItem(
          id: 'cart_display',
          icon: Icons.point_of_sale_rounded,
          label: context.posText('shellCartDisplay', 'Cart display'),
        ),
        PosMoreMenuItem(
          id: 'qr_pairing',
          icon: Icons.qr_code_2_rounded,
          label: context.posText('shellQrDisplayPairing', 'QR display pairing'),
        ),
      ],
    ),
    PosMoreMenuSection(
      title: 'Support',
      items: [
        PosMoreMenuItem(
          id: 'help',
          icon: Icons.menu_book_outlined,
          label: 'Help & guide',
          subtitle: 'Features, how to use them, and what to do if one fails',
        ),
      ],
    ),
    PosMoreMenuSection(
      title: 'Account',
      items: [
        PosMoreMenuItem(
          id: 'updates',
          icon: Icons.system_update_alt_rounded,
          label: checkingForUpdates ? l10n.updateChecking : l10n.shellCheckForUpdates,
          enabled: !checkingForUpdates,
        ),
        if (pendingOrderCount > 0)
          PosMoreMenuItem(
            id: 'sync',
            icon: Icons.sync_rounded,
            label: l10n.shellSyncOrders,
            badge: '$pendingOrderCount',
          ),
        if (hasDeviceBinding)
          PosMoreMenuItem(
            id: 'unpair',
            icon: Icons.link_off_rounded,
            label: l10n.shellClearPairing,
          ),
        PosMoreMenuItem(
          id: 'about',
          icon: Icons.info_outline_rounded,
          label: 'About',
          subtitle: 'Version ${PosAppInfo.versionLabel}',
        ),
        PosMoreMenuItem(
          id: 'logout',
          icon: Icons.logout_rounded,
          label: l10n.commonSignOut,
          destructive: true,
        ),
      ],
    ),
  ];
  return [
    for (final section in sections)
      if (section.items.isNotEmpty) section,
  ];
}
