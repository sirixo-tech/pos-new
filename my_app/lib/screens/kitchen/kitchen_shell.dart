import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../providers/kitchen_controller.dart';
import '../../providers/pos_controller.dart';
import '../../providers/pos_locale_controller.dart';
import '../../services/kot_reset_time.dart';
import '../../services/pos_display_mode.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_app_update_ui.dart';
import '../../widgets/pos_appearance_picker.dart';
import '../../widgets/pos_language_switcher.dart';
import '../../widgets/pos_sound_settings_dialog.dart';
import '../../widgets/pos_ui.dart';
import '../pos_update_check_screen.dart';
import 'kitchen_board_screen.dart';
import 'kitchen_channel_filter.dart';
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

  @override
  void dispose() {
    // The register dock uses this same controller. Stopping here makes the
    // minimized board reload from scratch.
    super.dispose();
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
                      if (!narrow) const KitchenKotFilterTuneButton(),
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
                          'kitchenSwitchMode',
                          'Switch mode',
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
                            case 'kot_reset':
                              if (mounted) await _pickKotResetTime();
                            case 'updates':
                              if (mounted) {
                                await openPosUpdateCheckScreen(context);
                              }
                            case 'logout':
                              await pos.logout();
                          }
                        },
                        itemBuilder: (context) => [
                          if (narrow) ...[
                            PopupMenuItem(
                              value: 'appearance',
                              child: Text(context.l10n.appearancePickerTitle),
                            ),
                            if (showLanguage)
                              PopupMenuItem(
                                value: 'language',
                                child: Text(context.l10n.shellLanguage),
                              ),
                            PopupMenuItem(
                              value: 'filters',
                              child: Text(
                                context.posText('kitchenFilters', 'Filters'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'fullscreen',
                              child: Text(
                                context.posText(
                                  'kitchenFullscreen',
                                  'Fullscreen',
                                ),
                              ),
                            ),
                          ],
                          if (pos.canUseRegister)
                            PopupMenuItem(
                              value: 'register',
                              child: Text(
                                context.posText(
                                  'kitchenSwitchRegister',
                                  'Register POS',
                                ),
                              ),
                            ),
                          if (pos.canUseCaptain)
                            PopupMenuItem(
                              value: 'waiter',
                              child: Text(
                                context.posText(
                                  'kitchenSwitchWaiter',
                                  'Waiter / Captain',
                                ),
                              ),
                            ),
                          PopupMenuItem(
                            value: 'sounds',
                            child: Text(
                              context.posText(
                                'kitchenSoundSettings',
                                'Sound settings',
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'kot_reset',
                            child: Text(
                              '${context.posText('kitchenKotFlush', 'KOT flush')} · ${KotResetTimeSettings.label(kitchen.kotResetTime)}',
                            ),
                          ),
                          PopupMenuItem(
                            value: 'updates',
                            child: Text(context.l10n.shellCheckForUpdates),
                          ),
                          PopupMenuItem(
                            value: 'logout',
                            child: Text(context.l10n.commonSignOut),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert_rounded),
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
}
