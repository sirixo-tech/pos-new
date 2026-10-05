import 'package:package_info_plus/package_info_plus.dart';

/// Human-readable branding and build metadata.
///
/// **Source of truth:** [`branding.yaml`](../../branding.yaml)
/// After editing that file, run: `dart run tool/sync_branding.dart`
class PosAppInfo {
  PosAppInfo._();

  static const displayName = 'SELFX POS';

  /// Square mark. Replace `assets/images/app_emblem.png` to rebrand.
  static const emblemAsset = 'assets/images/app_emblem.png';

  /// Horizontal wordmark. Replace `assets/images/app_logo.png` to rebrand.
  static const logoAsset = 'assets/images/app_logo.png';

  /// Hosted / release API host for this build (from branding.yaml).
  static const defaultServerUrl = 'https://app.selfx.in';

  /// Optional debug/profile server when set in branding.yaml.
  static const debugServerUrl = 'https://app.selfx.in';

  /// Brand accent hex from branding.yaml (e.g. `#DD3333`). Empty → default blue.
  static const primaryColor = '#FF6200';

  /// ARGB for [Color] — synced from [primaryColor] (or default blue).
  static const primaryColorArgb = 0xFFFF6200;

  /// Marketing / semver version from `pubspec.yaml` (`version:` before `+`).
  static String version = '3.4.0';

  /// Build number from `pubspec.yaml` (`version:` after `+`).
  static String buildNumber = '2025';

  /// e.g. `1.0.0 (1)`
  static String get versionLabel => '$version ($buildNumber)';

  /// e.g. `ServeAI POS · v1.0.0`
  static String get aboutLabel => '$displayName · v$version';

  static Future<void> ensureInitialized() async {
    final info = await PackageInfo.fromPlatform();
    version = info.version;
    buildNumber = info.buildNumber;
  }
}
