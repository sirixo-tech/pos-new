import 'package:flutter/foundation.dart';

/// The website must retain return_to through registration and redirect on success.
Uri posRegistrationUrl(
  String server, {
  Uri? webLocation,
  TargetPlatform? platform,
}) {
  final target = platform ?? defaultTargetPlatform;
  final Uri? returnTo = kIsWeb || webLocation != null
      ? (webLocation ?? Uri.base).removeFragment()
      : target == TargetPlatform.android || target == TargetPlatform.iOS
      ? Uri.parse('selfxpos://registration-complete')
      : null;
  return Uri.parse('$server/register').replace(
    queryParameters: {
      if (returnTo != null) 'return_to': returnTo.toString(),
      'source': 'pos',
    },
  );
}

bool isPosRegistrationReturn(Uri uri) =>
    uri.scheme == 'selfxpos' &&
    uri.host == 'registration-complete' &&
    (uri.path.isEmpty || uri.path == '/') &&
    uri.userInfo.isEmpty &&
    !uri.hasPort;
