import 'package:flutter/foundation.dart';

import '../config/pos_app_info.dart';

/// Platform label for API headers.
String posPlatformLabel() {
  if (kIsWeb) return 'web';

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

/// Suggested server URL on the setup screen for the current platform.
///
/// Order:
/// 1. `debug_server_url` from branding.yaml (debug/profile only)
/// 2. Platform localhost hints (debug/profile only, when no debug URL)
/// 3. `default_server_url` from branding.yaml (all modes)
String defaultServerUrlHint() {
  final configured = PosAppInfo.defaultServerUrl.trim();
  if (configured.isNotEmpty) {
    return configured;
  }
  return 'https://app.selfx.in';
}

/// Placeholder / helper example shown under the URL field.
String serverUrlFieldHint() {
  return 'https://app.selfx.in';
}
