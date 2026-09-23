import 'package:flutter/foundation.dart';

import '../utils/platform_info.dart';
import 'pos_app_info.dart';

/// Hosted SaaS platform URL resolution.
///
/// Order:
/// 1. `--dart-define=SERVEAI_PLATFORM_URL=...` (CI / one-off overrides)
/// 2. `debug_server_url` from branding.yaml (debug/profile only)
/// 3. `default_server_url` from branding.yaml
/// 4. Platform localhost hints (debug/profile only)
class PlatformConfig {
  static const String _envPlatformUrl = String.fromEnvironment(
    'SERVEAI_PLATFORM_URL',
    defaultValue: '',
  );

  /// Self-hosted installs can customize server URL.
  static const bool allowCustomServerUrl = bool.fromEnvironment(
    'SERVEAI_ALLOW_CUSTOM_SERVER',
    defaultValue: true,
  );

  /// Normalizes server URL string (ensures https/http scheme and trims slashes).
  static String normalizeServerUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) return value;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      final hostLower = value.toLowerCase();
      if (hostLower.startsWith('localhost') ||
          hostLower.startsWith('127.0.0.1') ||
          hostLower.startsWith('10.') ||
          hostLower.startsWith('192.168.')) {
        value = 'http://$value';
      } else {
        value = 'https://$value';
      }
    }
    return value;
  }

  static String get platformUrl {
    final env = _envPlatformUrl.trim();
    if (env.isNotEmpty) return normalizeServerUrl(env);

    final configured = PosAppInfo.defaultServerUrl.trim();
    if (configured.isNotEmpty) return normalizeServerUrl(configured);

    if (!kReleaseMode) {
      final debug = PosAppInfo.debugServerUrl.trim();
      if (debug.isNotEmpty) return normalizeServerUrl(debug);
    }

    return 'https://app.selfx.in';
  }

  static String get serverUrlHint => defaultServerUrlHint();
}
