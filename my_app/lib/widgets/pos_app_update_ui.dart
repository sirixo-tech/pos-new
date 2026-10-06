import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import 'pos_update_install_flow.dart';

/// Dismissible soft-update strip for the POS shell.
class PosOptionalUpdateBanner extends StatelessWidget {
  const PosOptionalUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    if (!pos.showOptionalUpdateBanner) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final update = pos.appUpdate;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final notes = update.releaseNotes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    final version = update.latestVersion ?? '';

    return Material(
      color: PosTheme.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: soft.bg,
          border: Border(
            bottom: BorderSide(color: soft.fg.withValues(alpha: 0.28)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: soft.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: soft.fg.withValues(alpha: 0.28)),
              ),
              child: Icon(
                Icons.system_update_alt_rounded,
                color: soft.fg,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.updateAvailableTitle(version),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: PosTheme.ink,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasNotes
                        ? notes
                        : l10n.updateAvailableBody(PosAppInfo.versionLabel),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: pos.dismissOptionalUpdate,
              style: TextButton.styleFrom(
                foregroundColor: PosTheme.inkMuted,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                minimumSize: const Size(0, 40),
              ),
              child: Text(l10n.updateLater),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: update.hasDownload
                  ? () => startPosUpdateInstall(context, update)
                  : null,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(l10n.updateAction),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accent.withValues(alpha: 0.35),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
