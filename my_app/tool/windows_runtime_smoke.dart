import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:my_app/services/printing/windows_printer_queue.dart';

/// Isolated entrypoint: loads real assets and queries native channels without
/// opening a POS session, syncing orders, saving settings, or printing.
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final report = <String, Object?>{};
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    report['assetCount'] = manifest.listAssets().length;
    report['logoBytes'] = (await rootBundle.load(
      'assets/images/mainlogo.png',
    )).lengthInBytes;
    for (final weight in [
      FontWeight.w400,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      GoogleFonts.inter(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 30));
    report['fontsLoaded'] = true;
    final status = await WindowsPrinterQueue.lookup('TVSE RP3200 Lite');
    report['printer'] = {
      'present': status.present,
      'offline': status.offline,
      'paperOut': status.paperOut,
    };
    final missing = await WindowsPrinterQueue.lookup(
      'SelfX nonexistent regression test queue',
    );
    report['missingQueueDetected'] = !missing.present;
    report['success'] = true;
  } catch (error, stack) {
    report['success'] = false;
    report['error'] = error.toString();
    report['stack'] = stack.toString();
  }
  await File(arguments.single).writeAsString(jsonEncode(report));
  await SystemNavigator.pop();
}
