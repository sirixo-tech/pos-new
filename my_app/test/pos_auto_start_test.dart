import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/pos_auto_start.dart';
import 'package:my_app/services/pos_work_mode_storage.dart';
import 'package:my_app/widgets/pos_auto_start_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pos_main/auto_start');
  var access = false;
  var saveOk = true;
  final calls = <String>[];

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    access = false;
    saveOk = true;
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'setEnabled' => saveOk,
            'getStatus' => {'permissionGranted': access},
            'openPermissionSettings' || 'openAppSettings' => true,
            _ => null,
          };
        });
    await PosAutoStart.initialize();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('ON preference does not imply Android boot launch permission', () async {
    expect(PosAutoStart.isEnabled, isTrue);
    expect(await PosAutoStart.hasBootLaunchAccess(), isFalse);
    access = true;
    expect(await PosAutoStart.hasBootLaunchAccess(), isTrue);
  });

  test('native save failure does not change the selected state', () async {
    saveOk = false;
    await expectLater(PosAutoStart.setEnabled(false), throwsStateError);
    expect(PosAutoStart.isEnabled, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PosAutoStart.prefsKey), isTrue);
  });

  test('auto-start settings preserve saved KDS and token workspaces', () async {
    await PosWorkModeStorage.write(1, PosWorkMode.kitchen);
    await PosWorkModeStorage.write(2, PosWorkMode.tokenDisplay);
    await PosAutoStart.setEnabled(false);
    await PosAutoStart.setEnabled(true);
    expect(await PosWorkModeStorage.read(1), PosWorkMode.kitchen);
    expect(await PosWorkModeStorage.read(2), PosWorkMode.tokenDisplay);
  });

  testWidgets(
    'permission setup refreshes when returning from Android settings',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PosAutoStartDialog())),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Setup needed: allow Display over other apps.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Allow boot launch access'));
      await tester.pumpAndSettle();
      expect(calls, contains('openPermissionSettings'));
      access = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Boot launch access granted.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
