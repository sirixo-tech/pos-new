import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/pos_app_info.dart';
import '../../l10n/pos_l10n.dart';
import '../../providers/kitchen_controller.dart';
import '../../providers/pos_controller.dart';
import '../../providers/pos_locale_controller.dart';
import '../../services/kot_reset_time.dart';
import '../../services/pos_auto_start.dart';
import '../../services/pos_display_mode.dart';
import '../../services/printing/scan_to_print_settings.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_app_update_ui.dart';
import '../../widgets/pos_appearance_picker.dart';
import '../../widgets/pos_auto_start_picker.dart';
import '../../widgets/pos_language_switcher.dart';
import '../../widgets/pos_sound_settings_dialog.dart';
import '../../widgets/pos_ui.dart';
import '../pos_update_check_screen.dart';
import 'kitchen_board_screen.dart';
import 'kitchen_channel_filter.dart';
import 'kitchen_printer_settings_dialog.dart';
import 'kot_filter_order_dialog.dart';

/// Kitchen / KOT display shell for wall-mounted tablets.
class KitchenShell extends StatefulWidget {
  const KitchenShell({super.key});

  @override
  State<KitchenShell> createState() => _KitchenShellState();
}

class _KitchenShellState extends State<KitchenShell> {
  KitchenController? _kitchenController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _kitchenController ??= context.read<KitchenController>();
    _kitchenController!.setKotScreenVisible(true);
  }

  @override
  void dispose() {
    _kitchenController?.setKotScreenVisible(false);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootKitchen());
  }

  Future<void> _bootKitchen() async {
    final pos = context.read<PosController>();
    final kitchen = _kitchenController ?? context.read<KitchenController>();
    final session = pos.session;
    if (session == null || !pos.canUseKitchen) return;
    await kitchen.ensureRunning(
      session: session,
      ensureKitchenToken: pos.ensureKitchenApiToken,
    );
  }

  Future<void> _switchMode(PosWorkMode mode) async {
    final pos = context.read<PosController>();
    await pos.switchWorkMode(mode);
  }

  Future<void> _pickKotResetTime() async {
    final kitchen = context.read<KitchenController>();
    final picked = await showTimePicker(
      context: context,
      initialTime: kitchen.kotResetTime,
    );
    if (picked == null || !mounted) return;
    await kitchen.setKotResetTime(picked);
    if (!mounted) return;
    showPosSnackBar(
      context,
      context.posText(
        'kitchenKotFlushSet',
        'KOT auto-flush set to {time}. Older tickets drop off the board.',
        {'time': KotResetTimeSettings.label(picked)},
      ),
    );
  }

  Future<void> _backFromKitchen() async {
    final pos = context.read<PosController>();
    if (pos.canUseRegister) {
      await _switchMode(PosWorkMode.register);
      return;
    }
    if (pos.canUseCaptain) {
      await _switchMode(PosWorkMode.waiter);
    }
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final pos = context.watch<PosController>();
    final kitchen = context.watch<KitchenController>();
    final locale = context.watch<PosLocaleController>();
    final branch = kitchen.bootstrap?.branchName?.trim();
    final canGoBack = pos.canUseRegister || pos.canUseCaptain;
    final narrow = MediaQuery.sizeOf(context).width < 900;
    final live = posStatusColors('ready');
    final showLanguage =
        locale.showSwitcher || locale.availableLocales.length > 1;

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PosOptionalUpdateBanner(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                context.posText(
                                  'kitchenTitle',
                                  'Kitchen Display',
                                ),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!narrow && branch != null && branch.isNotEmpty)
                              Flexible(
                                child: Text(
                                  branch,
                                  style: TextStyle(color: PosTheme.inkMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (!narrow)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: live.bg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: live.fg.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 8, color: live.fg),
                                    const SizedBox(width: 6),
                                    Text(
                                      context.posText('kitchenLive', 'Live'),
                                      style: TextStyle(
                                        color: live.fg,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (!narrow)
                              Text(
                                '${kitchen.totalActive} ${context.posText('kitchenActiveOrders', 'active')}',
                                style: TextStyle(
                                  color: PosTheme.inkMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (showLanguage && !narrow)
                        IconButton(
                          tooltip: context.l10n.shellLanguage,
                          onPressed: () =>
                              showPosLanguagePicker(context, force: true),
                          icon: const Icon(Icons.language_rounded),
                        ),
                      if (!narrow)
                        PosAppBarThemeButton(
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                      IconButton(
                        tooltip: context.posText(
                          'kitchenTokenDisplay',
                          'Token display',
                        ),
                        onPressed: () => _switchMode(PosWorkMode.tokenDisplay),
                        icon: const Icon(Icons.tv_rounded),
                      ),
                      IconButton(
                        tooltip: context.posText(
                          'kitchenSoundSettings',
                          'Sound settings',
                        ),
                        onPressed: () =>
                            showKitchenSoundSettingsDialog(context),
                        icon: const Icon(Icons.volume_up_rounded),
                      ),
                      IconButton(
                        tooltip: context.posText('kitchenRefresh', 'Refresh'),
                        onPressed: kitchen.refreshing
                            ? null
                            : () => kitchen.refresh(userInitiated: true),
                        icon: kitchen.refreshing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                      if (!narrow)
                        IconButton(
                          tooltip: PosDisplayMode.enabled
                              ? context.posText(
                                  'kitchenExitFullscreen',
                                  'Exit fullscreen',
                                )
                              : context.posText(
                                  'kitchenFullscreen',
                                  'Fullscreen',
                                ),
                          onPressed: () => PosDisplayMode.toggle(),
                          icon: Icon(
                            PosDisplayMode.enabled
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                          ),
                        ),
                      PopupMenuButton<String>(
                        tooltip: context.posText(
                          'kitchenMenuTooltip',
                          'Kitchen options',
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: PosTheme.border),
                        ),
                        elevation: 14,
                        shadowColor: Colors.black.withValues(alpha: 0.16),
                        color: PosTheme.surface,
                        constraints: const BoxConstraints(
                          minWidth: 280,
                          maxWidth: 320,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: PosTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: PosTheme.border),
                          ),
                          child: const Icon(Icons.more_vert_rounded, size: 20),
                        ),
                        onSelected: (value) async {
                          if (!mounted) return;
                          switch (value) {
                            case 'appearance':
                              await showPosAppearancePicker(context);
                            case 'language':
                              await showPosLanguagePicker(context, force: true);
                            case 'filters':
                              await showKotFilterOrderDialog(context);
                            case 'fullscreen':
                              await PosDisplayMode.toggle();
                            case 'token_display':
                              await _switchMode(PosWorkMode.tokenDisplay);
                            case 'register':
                              if (pos.canUseRegister) {
                                await _switchMode(PosWorkMode.register);
                              }
                            case 'waiter':
                              if (pos.canUseCaptain) {
                                await _switchMode(PosWorkMode.waiter);
                              }
                            case 'sounds':
                              if (mounted) {
                                await showKitchenSoundSettingsDialog(context);
                              }
                            case 'printer_settings':
                              if (mounted) {
                                await showKitchenPrinterSettingsDialog(context);
                                if (mounted) setState(() {});
                              }
                            case 'kot_reset':
                              if (mounted) await _pickKotResetTime();
                            case 'updates':
                              if (mounted) {
                                await openPosUpdateCheckScreen(context);
                              }
                            case 'auto_start':
                              if (mounted) {
                                await showPosAutoStartPicker(context);
                                if (mounted) setState(() {});
                              }
                            case 'logout':
                              await pos.logout();
                          }
                        },
                        itemBuilder: (context) {
                          final printingOn = PosPrintingSettings.isEnabled;
                          final autoStartOn = PosAutoStart.isEnabled;
                          return [
                            if (narrow) ...[
                              _buildMenuSectionHeader('DISPLAY'),
                              _buildMenuItem(
                                value: 'appearance',
                                icon: Icons.palette_outlined,
                                title: context.l10n.appearancePickerTitle,
                              ),
                              if (showLanguage)
                                _buildMenuItem(
                                  value: 'language',
                                  icon: Icons.language_rounded,
                                  title: context.l10n.shellLanguage,
                                ),
                              _buildMenuItem(
                                value: 'fullscreen',
                                icon: Icons.fullscreen_rounded,
                                title: context.posText(
                                  'kitchenFullscreen',
                                  'Fullscreen',
                                ),
                              ),
                              const PopupMenuDivider(height: 1),
                            ],
                            _buildMenuSectionHeader('WORKSPACES'),
                            if (pos.canUseRegister)
                              _buildMenuItem(
                                value: 'register',
                                icon: Icons.point_of_sale_rounded,
                                iconColor: const Color(0xFF2563EB),
                                title: context.posText(
                                  'kitchenSwitchRegister',
                                  'Register POS',
                                ),
                                subtitle: 'Billing, orders & register',
                              ),
                            if (pos.canUseCaptain)
                              _buildMenuItem(
                                value: 'waiter',
                                icon: Icons.room_service_rounded,
                                iconColor: const Color(0xFFEA580C),
                                title: context.posText(
                                  'kitchenSwitchWaiter',
                                  'Waiter / Captain',
                                ),
                                subtitle: 'Table orders & captain',
                              ),
                            _buildMenuItem(
                              value: 'token_display',
                              icon: Icons.tv_rounded,
                              iconColor: const Color(0xFF7C3AED),
                              title: context.posText(
                                'kitchenTokenDisplay',
                                'Token display',
                              ),
                              subtitle: 'Customer token board',
                            ),
                            const PopupMenuDivider(height: 1),
                            _buildMenuSectionHeader('KITCHEN SETTINGS'),
                            _buildMenuItem(
                              value: 'filters',
                              icon: Icons.tune_rounded,
                              iconColor: const Color(0xFF6366F1),
                              title: context.posText(
                                'kotRearrangeFilters',
                                'Rearrange KOT filters',
                              ),
                              subtitle: context.posText(
                                'kotRearrangeFiltersSubtitle',
                                'Order channels & quick filters',
                              ),
                            ),
                            _buildMenuItem(
                              value: 'sounds',
                              icon: Icons.notifications_active_outlined,
                              iconColor: const Color(0xFF0D9488),
                              title: context.posText(
                                'kitchenSoundSettings',
                                'Sound settings',
                              ),
                              subtitle: 'New ticket chimes & volume',
                            ),
                            _buildMenuItem(
                              value: 'printer_settings',
                              icon: printingOn
                                  ? Icons.print_outlined
                                  : Icons.eco_rounded,
                              iconColor: printingOn
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF059669),
                              title: context.posText(
                                'kitchenPrinterSettings',
                                'Printer & tickets',
                              ),
                              subtitle: printingOn
                                  ? 'Printing active'
                                  : 'Paperless Mode',
                              trailing: _menuPill(
                                text: printingOn ? 'ACTIVE' : 'PAPERLESS',
                                color: printingOn
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF059669),
                                bg: printingOn
                                    ? const Color(0xFFE0F2FE)
                                    : const Color(0xFFD1FAE5),
                              ),
                            ),
                            _buildMenuItem(
                              value: 'kot_reset',
                              icon: Icons.cleaning_services_outlined,
                              iconColor: const Color(0xFFD97706),
                              title: context.posText(
                                'kitchenKotFlush',
                                'KOT flush',
                              ),
                              subtitle: KotResetTimeSettings.label(
                                kitchen.kotResetTime,
                              ),
                              trailing: _menuPill(
                                text: KotResetTimeSettings.label(
                                  kitchen.kotResetTime,
                                ),
                                color: const Color(0xFFD97706),
                                bg: const Color(0xFFFEF3C7),
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            _buildMenuSectionHeader('DEVICE & SYSTEM'),
                            _buildMenuItem(
                              value: 'auto_start',
                              icon: Icons.power_settings_new_rounded,
                              iconColor: autoStartOn
                                  ? const Color(0xFF16A34A)
                                  : PosTheme.inkMuted,
                              title: context.posText(
                                'posAutoStartLabel',
                                'Auto-start on boot',
                              ),
                              subtitle: autoStartOn
                                  ? 'Enabled - check device boot access'
                                  : 'Disabled',
                              trailing: _menuPill(
                                text: autoStartOn ? 'ON' : 'OFF',
                                color: autoStartOn
                                    ? const Color(0xFF16A34A)
                                    : PosTheme.inkMuted,
                                bg: autoStartOn
                                    ? const Color(0xFFDCFCE7)
                                    : PosTheme.surfaceMuted,
                              ),
                            ),
                            _buildMenuItem(
                              value: 'updates',
                              icon: Icons.system_update_alt_rounded,
                              iconColor: const Color(0xFF4F46E5),
                              title: context.l10n.shellCheckForUpdates,
                              subtitle: 'Version ${PosAppInfo.versionLabel}',
                            ),
                            _buildMenuItem(
                              value: 'logout',
                              icon: Icons.logout_rounded,
                              title: context.l10n.commonSignOut,
                              destructive: true,
                            ),
                          ];
                        },
                      ),
                      if (canGoBack)
                        IconButton(
                          tooltip: context.posText(
                            'kitchenMinimizeKot',
                            'Minimize KOT',
                          ),
                          onPressed: _backFromKitchen,
                          icon: const Icon(Icons.close_fullscreen_rounded),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: KitchenKotFilterChips(
                            orders: kitchen.allActiveOrders,
                            selectedChannel: kitchen.selectedChannel,
                            onChanged: kitchen.setChannelFilter,
                            wrap: !narrow,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      KitchenSortMenu(
                        selected: kitchen.selectedSort,
                        onChanged: kitchen.setTicketSort,
                      ),
                      if (kitchen.bootstrap?.kitchens.isNotEmpty == true) ...[
                        const SizedBox(width: 6),
                        KitchenStationMenu(
                          stations: kitchen.bootstrap!.kitchens,
                          selectedId: kitchen.selectedKitchenId,
                          onChanged: kitchen.setKitchenFilter,
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PosTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PosTheme.border),
                      ),
                      child: const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        child: KitchenBoardScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool destructive = false,
    Color? iconColor,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    final errorColor = Theme.of(context).colorScheme.error;
    final fg = destructive ? errorColor : (iconColor ?? accent);
    final bg = destructive
        ? errorColor.withValues(alpha: 0.1)
        : (iconColor != null
              ? iconColor.withValues(alpha: 0.12)
              : posAccentSoft(accent).bg);

    return PopupMenuItem<String>(
      value: value,
      height: subtitle != null ? 52 : 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: destructive ? errorColor : PosTheme.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  PopupMenuEntry<String> _buildMenuSectionHeader(String title) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 28,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: PosTheme.inkFaint,
        ),
      ),
    );
  }

  Widget _menuPill({
    required String text,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
