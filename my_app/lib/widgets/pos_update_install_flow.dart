import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_app_update.dart';
import '../services/pos_update_installer.dart';
import '../theme/pos_theme.dart';
import 'pos_ui.dart';

Future<void> openPosAppUpdateUrl(PosAppUpdate update) async {
  final raw = update.downloadUrl;
  if (raw == null || raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Starts in-app download + OS installer for Android/desktop; browser for web/iOS.
Future<void> startPosUpdateInstall(
  BuildContext context,
  PosAppUpdate update,
) async {
  if (!update.installsNewerBuild || !update.hasDownload) return;

  if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
    await openPosAppUpdateUrl(update);
    return;
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PosUpdateDownloadDialog(update: update),
  );
}

class PosUpdateDownloadDialog extends StatefulWidget {
  const PosUpdateDownloadDialog({super.key, required this.update});

  final PosAppUpdate update;

  @override
  State<PosUpdateDownloadDialog> createState() =>
      _PosUpdateDownloadDialogState();
}

class _PosUpdateDownloadDialogState extends State<PosUpdateDownloadDialog> {
  late final PosUpdateInstaller _installer;
  PosUpdateInstallProgress _progress = const PosUpdateInstallProgress(
    phase: PosUpdateInstallPhase.preparing,
  );

  @override
  void initState() {
    super.initState();
    _installer = PosUpdateInstaller();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final result = await _installer.install(
      widget.update,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() => _progress = progress);
      },
    );
    if (!mounted) return;
    setState(() => _progress = result);
  }

  @override
  void dispose() {
    _installer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final terminal = _progress.isTerminal;
    final failed = _progress.phase == PosUpdateInstallPhase.failed;
    final done = _progress.phase == PosUpdateInstallPhase.done;
    final cancelled = _progress.phase == PosUpdateInstallPhase.cancelled;
    final downloading =
        _progress.phase == PosUpdateInstallPhase.downloading ||
            _progress.phase == PosUpdateInstallPhase.preparing ||
            _progress.phase == PosUpdateInstallPhase.opening;

    final title = done
        ? l10n.updateInstallerOpened
        : failed
            ? l10n.updateFailed
            : cancelled
                ? l10n.updateCancelled
                : l10n.updateDownloading;

    final headerColor = failed
        ? const Color(0xFFB91C1C)
        : done
            ? const Color(0xFF059669)
            : accent;

    final icon = failed
        ? Icons.error_outline_rounded
        : done
            ? Icons.check_circle_outline_rounded
            : Icons.system_update_alt_rounded;

    return PosDialogShell(
      title: title,
      subtitle: widget.update.latestVersion != null
          ? l10n.updateVersion(widget.update.latestVersion!)
          : l10n.updateInstalling,
      icon: icon,
      headerColor: headerColor,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _progress.message ?? l10n.updatePreparing,
            style: TextStyle(
              color: PosTheme.inkMuted,
              height: 1.4,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (downloading) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _progress.progress,
                minHeight: 10,
                backgroundColor: accent.withValues(alpha: 0.12),
                color: accent,
              ),
            ),
            if (_progress.totalBytes != null &&
                _progress.totalBytes! > 0) ...[
              const SizedBox(height: 10),
              Text(
                '${_formatBytes(_progress.receivedBytes)} / ${_formatBytes(_progress.totalBytes!)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: PosTheme.inkMuted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ],
      ),
      footer: Row(
        children: [
          if (downloading)
            Expanded(
              child: OutlinedButton(
                onPressed: _installer.cancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: PosTheme.inkMuted,
                  side: BorderSide(color: PosTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.commonCancel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (terminal && failed) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await openPosAppUpdateUrl(widget.update);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.updateOpenBrowser,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (terminal)
            Expanded(
              flex: failed ? 1 : 1,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: headerColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.commonClose,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
