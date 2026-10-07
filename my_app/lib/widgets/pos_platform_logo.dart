import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/pos_app_info.dart';
import '../models/pos_models.dart';
import '../utils/media_url.dart';

/// Super Admin platform logo for auth / lock chrome.
///
/// Falls back to the bundled white-label wordmark (`PosAppInfo.logoAsset`).
class PosPlatformLogo extends StatelessWidget {
  const PosPlatformLogo({
    super.key,
    this.platform,
    this.serverUrl,
    this.height = 36,
    this.maxWidth = 160,
    this.onDark = false,
    this.showNameFallback = true,
    this.trimBundledPadding = false,
  });

  final PosPlatformBranding? platform;
  final String? serverUrl;
  final double height;
  final double maxWidth;
  final bool onDark;
  final bool showNameFallback;
  final bool trimBundledPadding;

  @override
  Widget build(BuildContext context) {
    final branding = platform ?? const PosPlatformBranding();
    final url = resolveMediaUrl(branding.adminLogoUrl, serverUrl: serverUrl);
    // Caller's [maxWidth]/[height] win — CMS logo_width is often a tiny nav
    // hint (e.g. 40) and must not shrink auth / hero marks.
    final widthHint = maxWidth;

    if (url != null) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widthHint, maxHeight: height),
        child: CachedNetworkImage(
          imageUrl: url,
          height: height,
          memCacheHeight: (height * dpr).round(),
          fit: BoxFit.contain,
          alignment: Alignment.center,
          fadeInDuration: const Duration(milliseconds: 160),
          placeholder: (context, _) => _bundled(height, widthHint),
          errorWidget: (context, url, error) => _bundled(height, widthHint),
        ),
      );
    }

    if (!showNameFallback) {
      return Image.asset(
        PosAppInfo.emblemAsset,
        height: height,
        width: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    return _bundled(height, widthHint);
  }

  Widget _bundled(double h, double w) {
    final logo = Image.asset(
      PosAppInfo.logoAsset,
      height: h,
      width: w,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
    );
    if (!trimBundledPadding) return logo;
    return ClipRect(
      child: Align(heightFactor: 0.5, child: logo),
    );
  }
}
