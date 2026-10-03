import 'dart:io';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_app_update.dart';
import '../utils/platform_info.dart';
import 'window_close/window_close_guard.dart';

enum PosUpdateInstallPhase {
  preparing,
  downloading,
  opening,
  done,
  failed,
  cancelled,
}

class PosUpdateInstallProgress {
  const PosUpdateInstallProgress({
    required this.phase,
    this.progress,
    this.receivedBytes = 0,
    this.totalBytes,
    this.filePath,
    this.message,
  });

  final PosUpdateInstallPhase phase;

  /// 0–1 when known; null while indeterminate.
  final double? progress;
  final int receivedBytes;
  final int? totalBytes;
  final String? filePath;
  final String? message;

  bool get isTerminal =>
      phase == PosUpdateInstallPhase.done ||
      phase == PosUpdateInstallPhase.failed ||
      phase == PosUpdateInstallPhase.cancelled;
}

/// Downloads the published installer in-app, then opens the OS installer UI.
class PosUpdateInstaller {
  PosUpdateInstaller({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  bool _cancelled = false;

  static String _t(
    String key,
    String fallback, [
    Map<String, Object> replacements = const {},
  ]) {
    return PosTranslationStore.instance.text(
      key,
      fallback,
      replacements: replacements,
    );
  }

  void cancel() {
    _cancelled = true;
  }

  Future<PosUpdateInstallProgress> install(
    PosAppUpdate update, {
    void Function(PosUpdateInstallProgress progress)? onProgress,
  }) async {
    _cancelled = false;

    void emit(PosUpdateInstallProgress progress) {
      onProgress?.call(progress);
    }

    final url = update.downloadUrl?.trim() ?? '';
    if (url.isEmpty) {
      final failed = PosUpdateInstallProgress(
        phase: PosUpdateInstallPhase.failed,
        message: _t(
          'updateNoLinkDevice',
          'No download link is available for this device.',
        ),
      );
      emit(failed);
      return failed;
    }

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      final failed = PosUpdateInstallProgress(
        phase: PosUpdateInstallPhase.failed,
        message: _t(
          'updateInAppUnavailable',
          'In-app install is not available on this platform.',
        ),
      );
      emit(failed);
      return failed;
    }

    final uri = Uri.tryParse(url);
    final validation = _validateManifest(update, uri);
    if (validation != null) {
      final failed = PosUpdateInstallProgress(
        phase: PosUpdateInstallPhase.failed,
        message: validation,
      );
      emit(failed);
      return failed;
    }

    emit(
      PosUpdateInstallProgress(
        phase: PosUpdateInstallPhase.preparing,
        message: _t('updatePreparing', 'Preparing download…'),
      ),
    );

    try {
      final parsedUri = Uri.parse(url);
      final fileName = _fileNameFor(parsedUri, update);
      final dir = await _updateDirectory();
      final target = File('${dir.path}/$fileName');
      if (await target.exists()) {
        await target.delete();
      }

      final request = http.Request('GET', parsedUri);
      final response = await _client.send(request);

      if (_cancelled) {
        final cancelled = PosUpdateInstallProgress(
          phase: PosUpdateInstallPhase.cancelled,
          message: _t('updateDownloadCancelled', 'Download cancelled.'),
        );
        emit(cancelled);
        return cancelled;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final failed = PosUpdateInstallProgress(
          phase: PosUpdateInstallPhase.failed,
          message: _t('updateDownloadFailed', 'Download failed ({code}).', {
            'code': response.statusCode,
          }),
        );
        emit(failed);
        return failed;
      }

      final total = response.contentLength;
      var received = 0;
      final sink = target.openWrite();

      try {
        await for (final chunk in response.stream) {
          if (_cancelled) {
            await sink.close();
            if (await target.exists()) {
              await target.delete();
            }
            final cancelled = PosUpdateInstallProgress(
              phase: PosUpdateInstallPhase.cancelled,
              message: _t('updateDownloadCancelled', 'Download cancelled.'),
            );
            emit(cancelled);
            return cancelled;
          }

          sink.add(chunk);
          received += chunk.length;
          final progress = total != null && total > 0
              ? (received / total).clamp(0.0, 1.0)
              : null;
          emit(
            PosUpdateInstallProgress(
              phase: PosUpdateInstallPhase.downloading,
              progress: progress,
              receivedBytes: received,
              totalBytes: total,
              message: total != null && total > 0
                  ? _t('updateDownloadingPct', 'Downloading… {pct}%', {
                      'pct': ((received / total) * 100).floor(),
                    })
                  : _t('updateDownloading', 'Downloading update'),
            ),
          );
        }
      } finally {
        await sink.close();
      }

      if (_cancelled) {
        if (await target.exists()) {
          await target.delete();
        }
        final cancelled = PosUpdateInstallProgress(
          phase: PosUpdateInstallPhase.cancelled,
          message: _t('updateDownloadCancelled', 'Download cancelled.'),
        );
        emit(cancelled);
        return cancelled;
      }

      final checksumError = await _verifyChecksum(target, update);
      if (checksumError != null) {
        if (await target.exists()) {
          await target.delete();
        }
        final failed = PosUpdateInstallProgress(
          phase: PosUpdateInstallPhase.failed,
          message: checksumError,
        );
        emit(failed);
        return failed;
      }

      emit(
        PosUpdateInstallProgress(
          phase: PosUpdateInstallPhase.opening,
          progress: 1,
          receivedBytes: received,
          totalBytes: total ?? received,
          filePath: target.path,
          message: _openingMessage(),
        ),
      );

      if (Platform.isWindows && target.path.toLowerCase().endsWith('.exe')) {
        await allowWindowCloseForUpdate(true);
        try {
          final installer = await Process.start(target.path, const [
            '/CLOSEAPPLICATIONS',
            '/RESTARTAPPLICATIONS',
            '/SUPPRESSMSGBOXES',
          ], mode: ProcessStartMode.normal);
          unawaited(installer.stdout.drain<void>());
          unawaited(installer.stderr.drain<void>());
          // If the wizard is cancelled and POS remains open, restore its
          // ordinary exit confirmation after the installer exits.
          unawaited(
            installer.exitCode.then((_) async {
              await allowWindowCloseForUpdate(false);
            }),
          );
        } on Object {
          await allowWindowCloseForUpdate(false);
          rethrow;
        }
        final done = PosUpdateInstallProgress(
          phase: PosUpdateInstallPhase.done,
          progress: 1,
          receivedBytes: received,
          totalBytes: total ?? received,
          filePath: target.path,
          message: _doneMessage(),
        );
        emit(done);
        return done;
      }

      final result = await OpenFilex.open(target.path);
      if (result.type != ResultType.done) {
        final failed = PosUpdateInstallProgress(
          phase: PosUpdateInstallPhase.failed,
          filePath: target.path,
          message: result.message.isNotEmpty
              ? result.message
              : '${_t('updateFailed', 'Update failed')}: ${target.path}',
        );
        emit(failed);
        return failed;
      }

      final done = PosUpdateInstallProgress(
        phase: PosUpdateInstallPhase.done,
        progress: 1,
        receivedBytes: received,
        totalBytes: total ?? received,
        filePath: target.path,
        message: _doneMessage(),
      );
      emit(done);
      return done;
    } catch (error) {
      final failed = PosUpdateInstallProgress(
        phase: PosUpdateInstallPhase.failed,
        message: '${_t('updateFailed', 'Update failed')}: $error',
      );
      emit(failed);
      return failed;
    }
  }

  Future<Directory> _updateDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/updates');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String? _validateManifest(PosAppUpdate update, Uri? uri) {
    if (uri == null || !_isTrustedDownloadUri(uri)) {
      return _t(
        'updateUntrustedUrl',
        'The update download URL is not a trusted HTTPS URL.',
      );
    }
    final platform = posPlatformLabel();
    final advertised = (update.platform ?? platform).toLowerCase();
    if (advertised.isNotEmpty && advertised != platform) {
      return _t(
        'updateWrongPlatform',
        'This update package is not intended for this device.',
      );
    }
    final path = uri.path.toLowerCase();
    if (Platform.isAndroid && !path.endsWith('.apk')) {
      return _t(
        'updateWrongPackage',
        'This device requires an .apk update package.',
      );
    }
    if (Platform.isWindows &&
        !path.endsWith('.exe') &&
        !path.endsWith('.zip')) {
      return _t(
        'updateWrongPackageWin',
        'This device requires an .exe or .zip update package.',
      );
    }
    final checksum = update.sha256?.trim() ?? '';
    final official = _isOfficialPosDownloadUri(
      uri,
      advertised.isEmpty ? platform : advertised,
    );
    if (checksum.isEmpty) {
      if (official) return null;
      return _t(
        'updateBadChecksum',
        'The update manifest does not contain a valid SHA-256 checksum.',
      );
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(checksum)) {
      return _t(
        'updateBadChecksum',
        'The update manifest does not contain a valid SHA-256 checksum.',
      );
    }
    return null;
  }

  Future<String?> _verifyChecksum(File file, PosAppUpdate update) async {
    final expected = update.sha256?.trim().toLowerCase() ?? '';
    if (expected.isEmpty) {
      return null;
    }
    final actual = (await sha256.bind(file.openRead()).first).toString();
    if (actual != expected) {
      return _t(
        'updateChecksumMismatch',
        'Downloaded update failed the SHA-256 checksum check.',
      );
    }
    return null;
  }

  static bool _isOfficialPosDownloadUri(Uri uri, String platform) {
    final normalized = platform.trim().toLowerCase();
    return uri.scheme == 'https' &&
        uri.host.toLowerCase() == 'app.selfx.in' &&
        uri.path.toLowerCase().startsWith(
          '/media/app-downloads/pos/$normalized/',
        );
  }

  static bool _isTrustedDownloadUri(Uri uri) {
    final local =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    return uri.host.isNotEmpty &&
        (uri.scheme == 'https' || (uri.scheme == 'http' && local));
  }

  String _fileNameFor(Uri uri, PosAppUpdate update) {
    final fromPath = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final cleaned = fromPath.split('?').first.trim();
    if (cleaned.contains('.') && cleaned.length > 3) {
      return cleaned.contains('_')
          ? cleaned.split('_').skip(1).join('_')
          : cleaned;
    }

    final version = update.latestVersion ?? 'update';
    final ext = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'apk',
      TargetPlatform.macOS => 'dmg',
      TargetPlatform.windows => 'exe',
      TargetPlatform.linux => 'AppImage',
      _ => 'bin',
    };
    return 'pos-$version.$ext';
  }

  static String _openingMessage() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _t(
        'updateOpeningAndroid',
        'Opening the Android installer…',
      ),
      TargetPlatform.macOS => _t(
        'updateOpeningMac',
        'Opening the macOS installer…',
      ),
      TargetPlatform.windows => _t(
        'updateOpeningWin',
        'Opening the Windows installer…',
      ),
      _ => _t('updateOpeningGeneric', 'Opening the installer…'),
    };
  }

  static String _doneMessage() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _t(
        'updateDoneAndroid',
        'Complete the system install prompt, then reopen this POS app.',
      ),
      TargetPlatform.macOS => _t(
        'updateDoneMac',
        'Install from the opened package (DMG/app), then reopen this POS app.',
      ),
      TargetPlatform.windows => _t(
        'updateDoneWin',
        'Finish the installer wizard, then reopen this POS app.',
      ),
      _ => _t(
        'updateDoneGeneric',
        'Finish installing, then reopen this POS app.',
      ),
    };
  }
}
