import 'package:flutter/material.dart';

import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../theme/pos_theme.dart';
import '../utils/media_url.dart';
import 'pos_network_logo.dart';
import 'pos_platform_logo.dart';

/// “Powered by” mark for auth / lock chrome.
///
/// Prefers Super Admin **Powered by logo** (`powered_by_logo_url`), then falls
/// back to the platform logo / bundled wordmark.
class PosPoweredBy extends StatelessWidget {
  const PosPoweredBy({
    super.key,
    this.platform,
    this.serverUrl,
    this.onDark = false,
    this.compact = false,
  });

  final PosPlatformBranding? platform;
  final String? serverUrl;
  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final branding = platform ?? const PosPlatformBranding();
    final name = branding.name.trim().isNotEmpty
        ? branding.name.trim()
        : PosAppInfo.displayName;
    final customText = branding.poweredByText?.trim();
    final label = (customText != null && customText.isNotEmpty)
        ? customText
        : context.l10n.poweredBy;
    final poweredLogoUrl = resolveMediaUrl(
      branding.poweredByLogoUrl,
      serverUrl: serverUrl,
    );
    final labelColor = onDark
        ? Colors.white.withValues(alpha: 0.62)
        : PosTheme.inkFaint;
    final logoH = compact ? 28.0 : 34.0;
    final logoMaxW = compact ? 160.0 : 200.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: labelColor,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: logoMaxW + 20),
            child: poweredLogoUrl != null
                ? PosNetworkLogo(
                    imageUrl: poweredLogoUrl,
                    maxWidth: logoMaxW,
                    maxHeight: logoH,
                    portraitSide: logoH + 4,
                    alignment: Alignment.centerLeft,
                    errorWidget: (context, url, error) => PosPlatformLogo(
                      platform: branding,
                      serverUrl: serverUrl,
                      height: logoH,
                      maxWidth: logoMaxW,
                      onDark: onDark,
                      showNameFallback: true,
                    ),
                  )
                : PosPlatformLogo(
                    platform: branding,
                    serverUrl: serverUrl,
                    height: logoH,
                    maxWidth: logoMaxW,
                    onDark: onDark,
                    showNameFallback: true,
                  ),
          ),
        ),
        Semantics(
          label: name,
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
