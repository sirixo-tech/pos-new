import 'package:flutter/material.dart';

import 'app.dart';
import 'config/pos_app_info.dart';
import 'services/pos_display_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PosAppInfo.ensureInitialized();
  await PosDisplayMode.initialize();
  runApp(const ServeAiPosApp());
}
