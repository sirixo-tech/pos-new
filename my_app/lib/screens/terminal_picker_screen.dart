import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/media_url.dart';
import '../utils/pos_animations.dart';
import '../widgets/pos_ui.dart';

class TerminalPickerScreen extends StatelessWidget {
  const TerminalPickerScreen({super.key});

  Future<void> _select(
    BuildContext context,
    PosTerminalInfo terminal,
  ) async {
    final pos = context.read<PosController>();
    await pos.selectTerminal(terminal);
    if (!context.mounted) return;
    final error = pos.errorMessage;
    if (error != null) {
      showPosSnackBar(context, error, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final terminals = pos.bootstrap?.posTerminals ?? [];
    final branch = pos.bootstrap?.branch;
    final restaurant = pos.bootstrap?.restaurant;
    final platform = pos.bootstrap?.platform ?? const PosPlatformBranding();
    final serverUrl = pos.serverUrl ?? pos.session?.serverUrl;
    final platformName = platform.name.trim().isNotEmpty
        ? platform.name.trim()
        : PosAppInfo.displayName;
    final restaurantName = restaurant?.name.trim();
    final logoUrl = resolveMediaUrl(
      restaurant?.logoUrl,
      serverUrl: serverUrl,
    );
    final staffName = pos.session?.userName?.trim();
    final location = [
      if (branch?.name.trim().isNotEmpty == true) branch!.name.trim(),
      if (restaurantName?.isNotEmpty == true &&
          (branch?.name.trim().isNotEmpty != true))
        restaurantName!,
    ].join(' · ');

    final form = PosSlideFade(
      child: PosSurfaceCard(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.terminalSelectTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              branch != null
                  ? l10n.terminalSelectSubtitleNamed(branch.name)
                  : l10n.terminalSelectSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (terminals.isEmpty)
              PosEmptyState(
                icon: Icons.point_of_sale_outlined,
                title: l10n.terminalEmptyTitle,
                subtitle: l10n.terminalEmptySubtitle,
                accent: accent,
              )
            else
              ...terminals.map(
                (terminal) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PosSelectTile(
                    title: terminal.name,
                    subtitle: context.l10n.terminalCode(terminal.code),
                    trailing: PosSelectTileTrailing.chevron,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: soft.bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        terminal.code,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: soft.fg,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () => _select(context, terminal),
                  ),
                ),
              ),
            if (terminals.isEmpty) ...[
              const SizedBox(height: 16),
              PosPrimaryButton(
                label: l10n.terminalContinueWithout,
                icon: Icons.arrow_forward_rounded,
                color: accent,
                onPressed: () => pos.skipTerminalSelection(),
              ),
            ],
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
      platform: platform,
      serverUrl: serverUrl,
      statusIcon: Icons.tablet_mac_rounded,
      statusLabel: l10n.terminalSelectTitle,
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
      fallbackIcon: Icons.point_of_sale_rounded,
      footerNote: l10n.terminalFooterNote,
      showClock: false,
      form: form,
    );
  }
}
