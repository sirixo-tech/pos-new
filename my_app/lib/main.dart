import 'package:flutter/material.dart';

import 'app.dart';
import 'config/pos_app_info.dart';
import 'services/pos_display_mode.dart';
import 'services/pos_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
