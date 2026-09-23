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

/// Full-screen block when the device is below min_version.
class PosRequiredUpdateOverlay extends StatelessWidget {
  const PosRequiredUpdateOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    if (!pos.updateRequired) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final update = pos.appUpdate;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final latest = update.minVersion ?? update.latestVersion ?? '';

    return Positioned.fill(
      child: Material(
        color: PosTheme.canvas,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: soft.bg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.system_update_alt_rounded,
                        size: 36,
                        color: soft.fg,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.updateRequiredTitle,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.updateRequiredBody(
                        PosAppInfo.versionLabel,
                        latest,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: PosTheme.inkMuted,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    if (update.releaseNotes?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      Text(
                        update.releaseNotes!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: update.hasDownload
                            ? () => startPosUpdateInstall(context, update)
                            : null,
                        icon: const Icon(Icons.download_rounded),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(PosTheme.radiusMd),
                          ),
                        ),
                        label: Text(
                          l10n.updateDownload,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (!update.hasDownload) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.updateNoLink,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PosTheme.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
