import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

bool get usesPlayStoreUpdates =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

final selfxPlayStoreUrl = Uri.https(
  'play.google.com',
  '/store/apps/details',
  {'id': 'in.selfx.pos'},
);

Future<bool> openSelfxPlayStore() =>
    launchUrl(selfxPlayStoreUrl, mode: LaunchMode.externalApplication);
