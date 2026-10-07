import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'config/pos_app_info.dart';
import 'services/pos_display_mode.dart';
import 'services/pos_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Decode the original brand asset before showing the Flutter startup UI.
  // Keep it pinned until the first frame so the boot screen uses this image.
  final logoStream = const AssetImage(PosAppInfo.logoAsset)
      .resolve(ImageConfiguration.empty);
  final logoReady = Completer<void>();
  final logoListener = ImageStreamListener(
    (_, __) {
      if (!logoReady.isCompleted) logoReady.complete();
    },
    onError: (Object error, StackTrace? stack) {
      if (!logoReady.isCompleted) logoReady.complete();
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    },
  );
  logoStream.addListener(logoListener);
  await logoReady.future;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    logoStream.removeListener(logoListener);
  });
  try {
    await PosAppInfo.ensureInitialized().timeout(const Duration(seconds: 5));
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        context: ErrorDescription('loading application version information'),
      ),
    );
  }
  runApp(
    PosStartup(
      initializeDisplay: PosDisplayMode.initialize,
      child: const ServeAiPosApp(),
    ),
  );
}
