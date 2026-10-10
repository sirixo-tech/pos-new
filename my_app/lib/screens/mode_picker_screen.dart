import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:provider/provider.dart';

import '../config/pos_app_info.dart';
import 'admin/admin_shell.dart';
import '../widgets/day_end_reports_sheet.dart';
import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../services/printing/pos_receipt_printer.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/media_url.dart';
import '../utils/pos_animations.dart';
import '../widgets/pos_ui.dart';

/// Choose Register POS, Waiter / Captain, or Kitchen KOT view.
///
/// Only modes the staff role allows are shown. If only one is allowed, that
/// mode is selected automatically (picker is normally skipped upstream).
class ModePickerScreen extends StatefulWidget {
  const ModePickerScreen({super.key});

  @override
  State<ModePickerScreen> createState() => _ModePickerScreenState();
}

class _ModePickerScreenState extends State<ModePickerScreen> {
  bool _autoSelecting = false;
  Timer? _permissionRefreshTimer;

  Future<void> _select(PosWorkMode mode) async {
    final pos = context.read<PosController>();
    await pos.selectWorkMode(mode);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final pos = context.read<PosController>();
      if (pos.choosingWorkspaceBeforeLocation) {
        await pos.refreshWorkspacePermissions();
      }
      if (mounted) await _maybeAutoSelect();
    });
    _permissionRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final pos = context.read<PosController>();
      if (pos.choosingWorkspaceBeforeLocation) {
        unawaited(pos.refreshWorkspacePermissions());
      }
    });
  }

  @override
  void dispose() {
    _permissionRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _maybeAutoSelect() async {
    if (!mounted || _autoSelecting) return;
    final pos = context.read<PosController>();
    if (pos.choosingWorkspaceBeforeLocation || pos.errorMessage != null) return;
    final allowed = <PosWorkMode>[
      if (pos.canUseRegister) PosWorkMode.register,
      if (pos.canUseCaptain) PosWorkMode.waiter,
      if (pos.canUseKitchen) PosWorkMode.kitchen,
    ];
    if (allowed.length != 1) return;
    _autoSelecting = true;
    await _select(allowed.first);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final branch = pos.bootstrap?.branch;
    final restaurant = pos.bootstrap?.restaurant;
    final platform = pos.bootstrap?.platform ?? const PosPlatformBranding();
    final serverUrl = pos.serverUrl ?? pos.session?.serverUrl;
    final platformName = platform.name.trim().isNotEmpty
        ? platform.name.trim()
        : PosAppInfo.displayName;
    final restaurantName = restaurant?.name.trim();
    final logoUrl = resolveMediaUrl(restaurant?.logoUrl, serverUrl: serverUrl);
    final staffName = pos.session?.userName?.trim();
    final location = [
      if (branch?.name.trim().isNotEmpty == true) branch!.name.trim(),
      if (restaurantName?.isNotEmpty == true &&
          (branch?.name.trim().isNotEmpty != true))
        restaurantName!,
    ].join(' · ');

    final showRegister = pos.canUseRegister;
    final showCaptain = pos.canUseCaptain;
    final showKitchen = pos.canUseKitchen;

    Widget modeTile({
      required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return PosSelectTile(
        title: title,
        subtitle: subtitle,
        trailing: PosSelectTileTrailing.chevron,
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: soft.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: soft.fg),
        ),
        onTap: onTap,
      );
    }

    final form = PosSlideFade(
      child: PosSurfaceCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose your workspace',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            Text(
              "Select how you'll use this device.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (pos.choosingWorkspaceBeforeLocation) ...[
              TextButton.icon(
                onPressed: pos.refreshingWorkspacePermissions
                    ? null
                    : pos.refreshWorkspacePermissions,
                icon: const Icon(Icons.refresh),
                label: Text(
                  pos.refreshingWorkspacePermissions
                      ? 'Refreshing access…'
                      : 'Refresh access',
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (pos.errorMessage != null) ...[
              Text(
                pos.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            if (showRegister)
              modeTile(
                title: 'Register POS',
                subtitle: 'Billing, payments and shifts',
                icon: CupertinoIcons.creditcard,
                onTap: () => _select(PosWorkMode.register),
              ),
            if (showRegister && (showCaptain || showKitchen))
              const SizedBox(height: 8),
            if (showKitchen)
              modeTile(
                title: context.posText(
                  'modePickerKitchenTitle',
                  'Kitchen Display',
                ),
                subtitle: 'View, cook, and complete orders',
                icon: CupertinoIcons.flame,
                onTap: () => _select(PosWorkMode.kitchen),
              ),
            if (showKitchen && showCaptain) const SizedBox(height: 8),
            if (showCaptain)
              modeTile(
                title: 'Waiter / Captain',
                subtitle: 'Manage tables and send orders',
                icon: CupertinoIcons.person_2,
                onTap: () => _select(PosWorkMode.waiter),
              ),
            if (pos.staffAdminCapabilities.canAccessAdmin) ...[
              const SizedBox(height: 8),
              modeTile(
                title: 'Manage',
                subtitle: 'Your permitted management tools',
                icon: Icons.settings_rounded,
                onTap: () => openPosAdminShell(context),
              ),
            ],
            if (pos.canViewStaffReports) ...[
              const SizedBox(height: 8),
              modeTile(
                title: 'Reports',
                subtitle: 'View reports',
                icon: Icons.bar_chart_rounded,
                onTap: () => DayEndReportsSheet.open(
                  context,
                  onPrint: (type) async {
                    final session = pos.session;
                    if (session == null) return;
                    final now = DateTime.now();
                    final today =
                        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                    await PosReceiptPrinter.printThermalReport(
                      session: session,
                      serverUrl: session.serverUrl,
                      type: type,
                      dateFrom: today,
                      dateTo: today,
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => pos.logout(),
              child: Text(l10n.commonSignOut),
            ),
          ],
        ),
      ),
    );

    return PosAuthScaffold(
      accent: accent,
      platformLogoHeight: 150,
      restaurantLogoHeight: 72,
      footerAtBottom: true,
      maxFormWidth: 420,
      platform: platform,
      serverUrl: serverUrl,
      statusIcon: Icons.devices_rounded,
      statusLabel: 'Choose your workspace',
      logoUrl: logoUrl,
      headline: restaurantName?.isNotEmpty == true
          ? restaurantName!
          : platformName,
      locationLine: location.isNotEmpty ? location : null,
      personLabel: staffName != null && staffName.isNotEmpty
          ? l10n.lockSignedInAs(staffName)
          : null,
      personInitial: staffName != null && staffName.isNotEmpty
          ? staffName.substring(0, 1)
          : null,
      fallbackIcon: Icons.devices_rounded,
      footerNote: l10n.modePickerFooter,
      showClock: false,
      form: form,
    );
  }
}
