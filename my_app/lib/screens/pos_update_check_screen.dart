import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../widgets/pos_ui.dart';
import '../widgets/pos_update_install_flow.dart';

Future<void> openPosUpdateCheckScreen(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const PosUpdateCheckScreen(),
  );
}

/// Manual update check. Always has Back/Close, matching other POS dialogs.
class PosUpdateCheckScreen extends StatefulWidget {
  const PosUpdateCheckScreen({super.key});

  @override
  State<PosUpdateCheckScreen> createState() => _PosUpdateCheckScreenState();
}

class _PosUpdateCheckScreenState extends State<PosUpdateCheckScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PosController>().checkForUpdates();
    });
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final update = pos.appUpdate;
    final checking = pos.checkingForUpdates;
    final notes = update.releaseNotes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;

    late final String title;
    late final String body;
    late final IconData icon;
    var headerColor = accent;
    if (checking) {
      title = l10n.updateChecking;
      body = context.posText(
        'updateCheckingSecure',
        'Checking securely for updates…',
      );
      icon = Icons.system_update_alt_rounded;
    } else if (update.isRequired) {
      title = l10n.updateRequiredTitle;
      body = l10n.updateRequiredBody(
        PosAppInfo.versionLabel,
        update.minVersion ?? update.latestVersion ?? '',
      );
      icon = Icons.priority_high_rounded;
      headerColor = const Color(0xFFB45309);
    } else if (update.isOptional) {
      title = l10n.updateAvailableTitle(update.latestVersion ?? '');
      body = hasNotes
          ? l10n.updateAvailableBody(PosAppInfo.versionLabel)
          : l10n.updateAvailableBody(PosAppInfo.versionLabel);
      icon = Icons.system_update_alt_rounded;
    } else {
      title = l10n.updateUpToDate(PosAppInfo.versionLabel);
      body = context.posText(
        'updateUpToDateHint',
        'This register is running the latest published POS build.',
      );
      icon = Icons.verified_outlined;
      headerColor = const Color(0xFF059669);
    }

    final subtitle = update.latestVersion != null &&
            update.latestVersion!.isNotEmpty &&
            !update.isNone
        ? context.posText(
            'updateLatestLabel',
            'Latest {version}',
            {'version': update.latestVersion!},
          )
        : context.posText(
            'updateInstalledLabel',
            'Installed {version}',
            {'version': PosAppInfo.versionLabel},
          );

    return PosDialogShell(
      title: title,
      subtitle: subtitle,
      icon: icon,
      headerColor: headerColor,
      maxWidth: 480,
      onClose: _close,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            body,
            style: TextStyle(
              color: PosTheme.inkMuted,
              height: 1.4,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (checking) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                backgroundColor: accent.withValues(alpha: 0.12),
                color: accent,
              ),
            ),
          ],
          if (!checking && hasNotes && !update.isNone) ...[
            const SizedBox(height: 16),
            Text(
              context.posText('updateWhatsNew', 'What’s new'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PosTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PosTheme.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  notes,
                  style: TextStyle(
                    color: PosTheme.ink,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
          if (!checking &&
              update.installsNewerBuild &&
              !update.hasDownload) ...[
            const SizedBox(height: 12),
            Text(
              l10n.updateNoLink,
              style: TextStyle(color: PosTheme.inkMuted, fontSize: 13),
            ),
          ],
        ],
      ),
      footer: checking
          ? OutlinedButton(
              onPressed: _close,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: PosTheme.inkMuted,
                side: BorderSide(color: PosTheme.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.posText('commonBack', 'Back'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : _UpdateCheckFooter(
              showDownload: update.installsNewerBuild && update.hasDownload,
              onBack: _close,
              onDownload: () => startPosUpdateInstall(context, update),
              onCheckAgain: pos.checkingForUpdates
                  ? null
                  : () => pos.checkForUpdates(),
              onOpenBrowser: update.installsNewerBuild && update.hasDownload
                  ? () => openPosAppUpdateUrl(update)
                  : null,
            ),
    );
  }
}

class _UpdateCheckFooter extends StatelessWidget {
  const _UpdateCheckFooter({
    required this.showDownload,
    required this.onBack,
    required this.onDownload,
    required this.onCheckAgain,
    this.onOpenBrowser,
  });

  final bool showDownload;
  final VoidCallback onBack;
  final VoidCallback onDownload;
  final VoidCallback? onCheckAgain;
  final VoidCallback? onOpenBrowser;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: PosTheme.inkMuted,
                  side: BorderSide(color: PosTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  context.posText('commonBack', 'Back'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: showDownload
                  ? FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(l10n.updateDownload),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: onCheckAgain,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        context.posText('updateCheckAgain', 'Check again'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        if (showDownload) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (onOpenBrowser != null)
                Expanded(
                  child: TextButton.icon(
                    onPressed: onOpenBrowser,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: Text(l10n.updateOpenBrowser),
                  ),
                ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onCheckAgain,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    context.posText('updateCheckAgain', 'Check again'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
