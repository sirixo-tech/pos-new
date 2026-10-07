import '../config/pos_app_info.dart';
import '../utils/platform_info.dart';

class PosAppUpdate {
  const PosAppUpdate({
    required this.status,
    required this.currentVersion,
    this.latestVersion,
    this.minVersion,
    this.latestBuild,
    this.releaseNotes,
    this.downloadUrl,
    this.downloadLabel,
    this.sha256,
    this.signature,
    this.platform,
  });

  final String status;
  final String currentVersion;
  final String? latestVersion;
  final String? minVersion;
  final int? latestBuild;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? downloadLabel;
  final String? sha256;
  final String? signature;
  final String? platform;

  bool get isNone => status == 'none' || status.isEmpty;
  bool get isOptional => status == 'optional';
  bool get isRequired => status == 'required';
  bool get hasDownload => downloadUrl != null && downloadUrl!.isNotEmpty;

  /// True only when the published release is strictly newer than this binary.
  /// An older `latest_version` must not be offered, even if the feed still
  /// marks it optional or required.
  bool get installsNewerBuild {
    if (isNone) return false;
    final current = currentVersion.trim().isNotEmpty
        ? currentVersion.trim()
        : PosAppInfo.version;
    final latest = latestVersion?.trim() ?? '';
    if (latest.isEmpty) return false;
    return compareAppVersions(
          current,
          latest,
          currentBuild: int.tryParse(PosAppInfo.buildNumber) ?? 0,
          candidateBuild: latestBuild,
        ) <
        0;
  }
  bool get hasChecksum =>
      sha256 != null && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256!);

  factory PosAppUpdate.none() =>
      const PosAppUpdate(status: 'none', currentVersion: '');

  factory PosAppUpdate.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return PosAppUpdate.none();
    }
    // Release manifests can contain separate packages for each platform.
    final devicePlatform = posPlatformLabel();
    final packages = json['platforms'] ?? json['packages'];
    final package = json[devicePlatform] ??
        (packages is Map ? packages[devicePlatform] : null);
    if (package is Map) {
      json = {
        ...json,
        ...Map<String, dynamic>.from(package),
        'platform': devicePlatform,
      };
    }
    final manifest = json;

    String value(List<String> keys) {
      for (final key in keys) {
        final text = manifest[key]?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    int? integer(List<String> keys) {
      final text = value(keys);
      return text.isEmpty ? null : int.tryParse(text);
    }

    final parsed = PosAppUpdate(
      status: value(const ['status', 'update_status']).toLowerCase().isEmpty
          ? 'none'
          : value(const ['status', 'update_status']).toLowerCase(),
      currentVersion: value(const ['current_version']),
      latestVersion: _nullable(value(const ['latest_version', 'version'])),
      minVersion: _nullable(
        value(const ['min_version', 'minimum_version', 'required_version']),
      ),
      latestBuild: integer(const ['latest_build', 'build_number', 'build']),
      releaseNotes: _nullable(
        value(const ['release_notes', 'notes', 'changelog']),
      ),
      downloadUrl: _nullable(
        value(const ['download_url', 'installer_url', 'apk_url', 'url']),
      ),
      downloadLabel: _nullable(value(const ['download_label'])),
      sha256: _checksum(manifest),
      signature: _nullable(
        value(const ['signature', 'signature_base64', 'rsa_signature']),
      ),
      platform: normalizeUpdatePlatform(
        value(const ['platform', 'target_platform']),
      ),
    );
    return parsed.resolvedAgainstInstalled();
  }

  /// Compare this manifest to the running binary. Stale `required` flags for
  /// the already-installed version become `none`.
  PosAppUpdate resolvedAgainstInstalled({
    String? installedVersion,
    int? installedBuild,
  }) {
    final current = (installedVersion ?? PosAppInfo.version).trim();
    final build = installedBuild ?? int.tryParse(PosAppInfo.buildNumber) ?? 0;
    final latest = latestVersion?.trim() ?? '';
    final minimum = minVersion?.trim() ?? '';
    final newer =
        latest.isNotEmpty &&
        compareAppVersions(
              current,
              latest,
              currentBuild: build,
              candidateBuild: latestBuild,
            ) <
            0;
    final belowMinimum =
        minimum.isNotEmpty &&
        compareAppVersions(current, minimum, currentBuild: build) < 0;
    final available = newer || belowMinimum;
    final nextStatus = !available
        ? 'none'
        : (status == 'required' || belowMinimum)
        ? 'required'
        : (status == 'optional' || newer)
        ? 'optional'
        : 'none';
    return PosAppUpdate(
      status: nextStatus,
      currentVersion: current,
      latestVersion: latestVersion,
      minVersion: minVersion,
      latestBuild: latestBuild,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      downloadLabel: downloadLabel,
      sha256: sha256,
      signature: signature,
      platform: platform,
    );
  }

  static String? _nullable(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static String? _checksum(Map<String, dynamic> json) {
    const keys = {
      'sha256',
      'sha_256',
      'checksum_sha256',
      'sha256_checksum',
      'checksumsha256',
      'filesha256',
      'file_hash',
      'filehash',
      'checksum',
    };
    String from(Object? raw) {
      if (raw is Map) {
        for (final value in raw.values) {
          final found = from(value);
          if (found.isNotEmpty) return found;
        }
        return '';
      }
      final candidate = raw?.toString() ?? '';
      final match = RegExp(
        r'[a-fA-F0-9]{64}',
      ).firstMatch(candidate.replaceAll(RegExp(r'\s+'), ''));
      return match?.group(0)?.toLowerCase() ?? '';
    }

    for (final entry in json.entries) {
      final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (keys.contains(key) || keys.contains(entry.key.toLowerCase())) {
        final found = from(entry.value);
        if (found.isNotEmpty) return found;
      }
    }
    return null;
  }
}

/// Release feeds may use OS aliases or a generic label for universal packages.
/// Architecture labels remain specific: OS matching does not prove ABI support.
String? normalizeUpdatePlatform(String? raw) {
  final value = raw?.trim().toLowerCase() ?? '';
  return switch (value) {
    '' || 'all' || 'any' || 'universal' || 'multi-platform' => null,
    'apk' || 'android-apk' || 'android_apk' => 'android',
    'win' || 'win32' || 'win64' || 'windows-x64' => 'windows',
    'mac' || 'osx' || 'darwin' => 'macos',
    _ => value,
  };
}

int compareAppVersions(
  String current,
  String candidate, {
  int? currentBuild,
  int? candidateBuild,
}) {
  if (candidate.trim().isEmpty) return 0;
  List<int> parts(String source) {
    final normalized = source.trim().split('+').first.split('-').first;
    return normalized
        .split('.')
        .map(
          (part) => int.tryParse(RegExp(r'\d+').stringMatch(part) ?? '') ?? 0,
        )
        .toList(growable: false);
  }

  final left = parts(current);
  final right = parts(candidate);
  // Windows manifests may include the build as a fourth component, while
  // Android reports the same release as three components plus versionCode.
  const count = 3;
  for (var index = 0; index < count; index++) {
    final a = index < left.length ? left[index] : 0;
    final b = index < right.length ? right[index] : 0;
    if (a != b) return a.compareTo(b);
  }
  int? embeddedBuild(String version, List<int> numbers) {
    final suffix = version.trim().split('+');
    if (suffix.length > 1) return int.tryParse(suffix.last);
    return numbers.length > 3 ? numbers[3] : null;
  }

  final leftBuild = currentBuild ?? embeddedBuild(current, left);
  final rightBuild = candidateBuild ?? embeddedBuild(candidate, right);
  if (leftBuild != null && rightBuild != null) {
    return leftBuild.compareTo(rightBuild);
  }
  return 0;
}

Map<String, dynamic>? mergedPosAppUpdateJson(Map<String, dynamic> json) {
  final raw = json['app_update'];
  if (raw is! Map) {
    return raw is Map<String, dynamic> ? raw : null;
  }
  // Envelope fields such as `platform` describe the API response, not the
  // installer. Only inherit release metadata that older APIs put outside
  // app_update; package fields must come from app_update itself.
  const releaseKeys = {
    'latest_version',
    'min_version',
    'minimum_version',
    'required_version',
    'latest_build',
    'release_notes',
  };
  return <String, dynamic>{
    for (final key in releaseKeys)
      if (json.containsKey(key)) key: json[key],
    ...Map<String, dynamic>.from(raw),
  };
}
