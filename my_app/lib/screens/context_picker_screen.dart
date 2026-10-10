import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:provider/provider.dart';

import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../services/pos_location_storage.dart';
import '../theme/pos_theme.dart';
import '../utils/media_url.dart';
import '../utils/pos_animations.dart';
import '../utils/pos_user_facing_error.dart';
import '../widgets/pos_ui.dart';

class ContextPickerScreen extends StatefulWidget {
  const ContextPickerScreen({super.key});

  @override
  State<ContextPickerScreen> createState() => _ContextPickerScreenState();
}

class _ContextPickerScreenState extends State<ContextPickerScreen> {
  int? _selectedRestaurantId;
  int? _selectedBranchId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final pos = context.read<PosController>();
    final profile = pos.profile;
    _selectedRestaurantId =
        profile?.currentRestaurantId ??
        (profile?.restaurants.isNotEmpty == true
            ? profile!.restaurants.first.id
            : null);
    _syncBranchForRestaurant();
    unawaited(_restoreSavedSelection());
  }

  Future<void> _restoreSavedSelection() async {
    final pos = context.read<PosController>();
    final profile = pos.profile;
    final session = pos.session;
    final userId = profile?.user.id;
    if (profile == null || session == null || userId == null) return;

    final stored = await PosLocationStorage.read(
      serverUrl: session.serverUrl,
      userId: userId,
    );
    if (!mounted || stored == null) return;
    if (!profile.canAccessLocation(stored.restaurantId, stored.branchId)) {
      return;
    }

    setState(() {
      _selectedRestaurantId = stored.restaurantId;
      _selectedBranchId = stored.branchId;
    });
  }

  void _syncBranchForRestaurant() {
    final pos = context.read<PosController>();
    final restaurants = pos.profile?.restaurants ?? [];
    final restaurant = restaurants.cast<StaffRestaurantOption?>().firstWhere(
      (r) => r!.id == _selectedRestaurantId,
      orElse: () => restaurants.isNotEmpty ? restaurants.first : null,
    );
    if (restaurant == null) return;

    final branches = restaurant.branches;
    _selectedBranchId =
        branches
            .where((b) => b.id == pos.profile?.currentBranchId)
            .map((b) => b.id)
            .firstOrNull ??
        branches.where((b) => b.isDefault).map((b) => b.id).firstOrNull ??
        (branches.isNotEmpty ? branches.first.id : null);
  }

  Future<void> _continue() async {
    final pos = context.read<PosController>();
    final restaurantId = _selectedRestaurantId;
    final branchId = _selectedBranchId;
    if (restaurantId == null || branchId == null) return;

    setState(() => _loading = true);
    try {
      if (pos.profile?.currentRestaurantId != restaurantId) {
        await pos.selectRestaurant(restaurantId);
      }
      if (!mounted) return;
      if (pos.phase == PosAppPhase.contextPicker && pos.errorMessage != null) {
        showPosSnackBar(context, pos.errorMessage!, error: true);
        return;
      }
      if (pos.phase != PosAppPhase.contextPicker) {
        final error = pos.errorMessage;
        if (error != null) {
          showPosSnackBar(context, error, error: true);
        }
        return;
      }
      await pos.selectBranch(branchId);
      if (!mounted) return;
      final error = pos.errorMessage;
      if (error != null) {
        showPosSnackBar(context, error, error: true);
      }
    } catch (e) {
      if (mounted) {
        showPosSnackBar(context, posUserFacingError(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final accent = Theme.of(context).colorScheme.primary;
    final restaurants = pos.profile?.restaurants ?? [];
    final selectedRestaurant = restaurants
        .cast<StaffRestaurantOption?>()
        .firstWhere(
          (r) => r!.id == _selectedRestaurantId,
          orElse: () => restaurants.isNotEmpty ? restaurants.first : null,
        );
    final branches = selectedRestaurant?.branches ?? [];
    final platform = pos.bootstrap?.platform ?? const PosPlatformBranding();
    final serverUrl = pos.serverUrl ?? pos.session?.serverUrl;
    final platformName = platform.name.trim().isNotEmpty
        ? platform.name.trim()
        : PosAppInfo.displayName;
    final restaurantName = selectedRestaurant?.name.trim();
    final logoUrl = resolveMediaUrl(
      pos.bootstrap?.restaurant.logoUrl,
      serverUrl: serverUrl,
    );
    final staffName = pos.session?.userName?.trim();
    final workspaceName = switch (pos.workMode) {
      PosWorkMode.waiter => 'Waiter / Captain',
      PosWorkMode.kitchen => 'Kitchen Display',
      PosWorkMode.register => 'Register POS',
      null => null,
    };
    final selectedBranchName = branches
        .where((b) => b.id == _selectedBranchId)
        .map((b) => b.name)
        .firstOrNull;

    final form = PosSlideFade(
      child: PosSurfaceCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.contextChooseLocation,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            Text(
              workspaceName == null
                  ? 'Select the restaurant and branch for this device.'
                  : 'Select the restaurant and branch for $workspaceName.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (restaurants.length > 1) ...[
              const SizedBox(height: 20),
              Text(
                l10n.contextRestaurant,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PosTheme.inkMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              ...restaurants.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PosSelectTile(
                    leading: Icon(
                      CupertinoIcons.building_2_fill,
                      color: accent,
                    ),
                    title: r.name,
                    selected: r.id == _selectedRestaurantId,
                    enabled: !_loading,
                    onTap: () {
                      setState(() {
                        _selectedRestaurantId = r.id;
                        _syncBranchForRestaurant();
                      });
                    },
                  ),
                ),
              ),
            ] else if (restaurantName != null && restaurantName.isNotEmpty) ...[
              const SizedBox(height: 16),
              PosSelectTile(
                leading: Icon(CupertinoIcons.building_2_fill, color: accent),
                title: restaurantName,
                subtitle: l10n.contextCurrentRestaurant,
                selected: true,
                onTap: () {},
              ),
            ],
            if (branches.length > 1) ...[
              const SizedBox(height: 12),
              Text(
                l10n.contextBranch,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PosTheme.inkMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              ...branches.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PosSelectTile(
                    leading: Icon(CupertinoIcons.location_solid, color: accent),
                    title: b.name,
                    subtitle: b.isDefault ? l10n.contextDefaultBranch : null,
                    selected: b.id == _selectedBranchId,
                    enabled: !_loading,
                    onTap: () => setState(() => _selectedBranchId = b.id),
                  ),
                ),
              ),
            ] else if (branches.length == 1) ...[
              const SizedBox(height: 12),
              PosSelectTile(
                leading: Icon(CupertinoIcons.location_solid, color: accent),
                title: branches.first.name,
                subtitle: l10n.contextBranch,
                selected: true,
                onTap: () {},
              ),
            ],
            const SizedBox(height: 22),
            PosPrimaryButton(
              label: l10n.commonContinue,
              icon: Icons.arrow_forward_rounded,
              loading: _loading,
              color: accent,
              onPressed: _selectedBranchId != null ? _continue : null,
            ),
            TextButton(
              onPressed: _loading ? null : () => pos.logout(),
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
      maxFormWidth: 420,
      platform: platform,
      serverUrl: serverUrl,
      statusIcon: Icons.storefront_rounded,
      statusLabel: workspaceName == null
          ? l10n.contextChooseLocation
          : '$workspaceName · ${l10n.contextChooseLocation}',
      logoUrl: logoUrl,
      headline: restaurantName?.isNotEmpty == true
          ? restaurantName!
          : platformName,
      locationLine: selectedBranchName,
      personLabel: staffName != null && staffName.isNotEmpty
          ? l10n.lockSignedInAs(staffName)
          : null,
      personInitial: staffName != null && staffName.isNotEmpty
          ? staffName.substring(0, 1)
          : null,
      fallbackIcon: Icons.storefront_rounded,
      footerNote: workspaceName == null
          ? 'Choose where this device will work today.'
          : 'Choose where you will use $workspaceName today.',
      showClock: false,
      form: form,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
