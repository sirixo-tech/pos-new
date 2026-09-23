import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../providers/pos_controller.dart';
import '../../providers/pos_idle_lock_controller.dart';
import '../../providers/pos_theme_controller.dart';
import '../../screens/admin/admin_shell.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_appearance_picker.dart';
import '../../widgets/pos_auto_lock_picker.dart';
import '../../widgets/pos_language_switcher.dart';
import '../../widgets/pos_ui.dart';

class WaiterProfileScreen extends StatelessWidget {
  const WaiterProfileScreen({super.key, required this.onSwitchToRegister});

  final Future<void> Function() onSwitchToRegister;

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final name = pos.session?.userName?.trim() ?? l10n.waiterNavProfile;
    final branch = pos.bootstrap?.branch.name;
    final restaurant = pos.bootstrap?.restaurant.name;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            l10n.waiterNavProfile,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PosTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PosTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      if (restaurant != null || branch != null)
                        Text(
                          [restaurant, branch]
                              .whereType<String>()
                              .where((s) => s.trim().isNotEmpty)
                              .join(' · '),
                          style: TextStyle(color: PosTheme.inkMuted),
                        ),
                      Text(
                        l10n.modePickerWaiterTitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (pos.bootstrap?.adminCapabilities.canAccessAdmin == true)
            _ActionTile(
              icon: Icons.admin_panel_settings_rounded,
              title: context.posText('adminManage', 'Manage'),
              subtitle: context.posText(
                'adminManageSubtitle',
                'Menu, tables, and orders',
              ),
              onTap: () => openPosAdminShell(context),
            ),
          if (pos.canUseRegister)
            _ActionTile(
              icon: Icons.point_of_sale_rounded,
              title: l10n.waiterSwitchToRegister,
              subtitle: l10n.waiterSwitchToRegisterSubtitle,
              onTap: () async {
                final ok = await showPosConfirmDialog(
                  context,
                  title: l10n.waiterSwitchToRegister,
                  message: l10n.waiterSwitchToRegisterConfirm,
                  confirmLabel: l10n.commonContinue,
                );
                if (!ok || !context.mounted) return;
                await onSwitchToRegister();
              },
            ),
          if (pos.canChooseWorkMode)
            _ActionTile(
              icon: Icons.devices_other_rounded,
              title: l10n.waiterChangeMode,
              subtitle: l10n.waiterChangeModeSubtitle,
              onTap: () => pos.clearWorkModeAndPick(),
            ),
          if (pos.canChangeLocation)
            _ActionTile(
              icon: Icons.storefront_outlined,
              title: l10n.shellChangeLocation,
              subtitle: l10n.contextSubtitle,
              onTap: () => pos.openLocationPicker(),
            ),
          _ActionTile(
            icon: Icons.lock_outline_rounded,
            title: l10n.shellLockRegister,
            subtitle: l10n.shortcutsLockRegisterDesc,
            onTap: pos.session?.hasPosPin == true
                ? () => pos.lockSession()
                : null,
          ),
          if (pos.session?.hasPosPin == true)
            Builder(
              builder: (context) {
                final enabled =
                    context.select((PosIdleLockController c) => c.enabled);
                return _ActionTile(
                  icon: Icons.timer_outlined,
                  title: l10n.shellAutoLock,
                  subtitle:
                      enabled ? l10n.autoLockEnabled : l10n.autoLockDisabled,
                  onTap: () => showPosAutoLockPicker(context),
                );
              },
            ),
          Builder(
            builder: (context) {
              final mode = context.select((PosThemeController c) => c.mode);
              final modeLabel = switch (mode) {
                ThemeMode.light => l10n.themeModeLight,
                ThemeMode.dark => l10n.themeModeDark,
                ThemeMode.system => l10n.themeModeSystem,
              };
              return _ActionTile(
                icon: Icons.palette_outlined,
                title: l10n.shellAppearance,
                subtitle: modeLabel,
                onTap: () => showPosAppearancePicker(context),
              );
            },
          ),
          _ActionTile(
            icon: Icons.language_rounded,
            title: l10n.languagePickerTitle,
            onTap: () => showPosLanguagePicker(context),
          ),
          const SizedBox(height: 8),
          PosPrimaryButton(
            label: l10n.commonSignOut,
            icon: Icons.logout_rounded,
            color: const Color(0xFFDC2626),
            onPressed: () async {
              final ok = await showPosConfirmDialog(
                context,
                title: l10n.commonSignOut,
                message: l10n.authSignOutFromLock,
                confirmLabel: l10n.commonSignOut,
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              await pos.logout();
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          enabled: onTap != null,
          onTap: onTap,
          minVerticalPadding: 14,
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: const Icon(Icons.chevron_right_rounded),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: PosTheme.border),
          ),
        ),
      ),
    );
  }
}
