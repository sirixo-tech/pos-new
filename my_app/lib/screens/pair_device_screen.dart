import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/pos_animations.dart';
import '../widgets/pos_ui.dart';

class PairDeviceScreen extends StatelessWidget {
  const PairDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final l10n = context.l10n;
    final code = pos.pairingCode ?? '------';
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);

    final form = PosSlideFade(
      child: PosSurfaceCard(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: soft.bg,
                borderRadius: BorderRadius.circular(PosTheme.radiusLg),
                border: Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: Icon(Icons.tablet_mac_rounded, color: soft.fg, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.pairThisTablet,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.pairAdminHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: PosTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(PosTheme.radiusLg),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.pairWaitingManager,
                  style: TextStyle(
                    color: soft.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (pos.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                pos.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => pos.refreshPairingCode(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.pairNewCode),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMd),
                ),
              ),
            ),
            TextButton(
              onPressed: () => pos.skipPairingToLogin(),
              child: Text(l10n.pairSkipToSignIn),
            ),
          ],
        ),
      ),
    );

    return PosAuthScaffold(
      accent: accent,
      statusIcon: Icons.link_rounded,
      statusLabel: l10n.pairDeviceTitle,
      headline: PosAppInfo.displayName,
      fallbackIcon: Icons.tablet_mac_rounded,
      personLabel: l10n.pairBindTerminal,
      personInitial: 'P',
      footerNote: l10n.pairFooterNote,
      showClock: false,
      form: form,
    );
  }
}
