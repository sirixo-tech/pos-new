import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/pos_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pos_main/touch_keyboard');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'a Windows text field asks the touch keyboard to open',
    (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });

      await tester.pumpWidget(
        const MaterialApp(
          home: PosKeyboardDismiss(child: Scaffold(body: TextField())),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(calls, ['show']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'leaving the field closes the Windows touch keyboard',
    (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });

      await tester.pumpWidget(
        MaterialApp(
          home: PosKeyboardDismiss(
            child: Scaffold(
              body: Column(
                children: [
                  const TextField(),
                  TextButton(onPressed: () {}, child: const Text('Done')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(calls, ['show', 'hide']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
