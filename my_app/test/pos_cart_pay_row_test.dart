import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:my_app/l10n/pos_l10n.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/cart_quick_pay_settings.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/theme/pos_theme.dart';
import 'package:my_app/widgets/pos_cart_panel.dart';
import 'package:provider/provider.dart';

class _FontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      'fonts/Inter-$weight.ttf',
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    fonts.assetManifest = _FontManifest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key.startsWith('fonts/Inter-')) return ByteData(0);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    fonts.assetManifest = null;
  });

  testWidgets('phone cart Hold, UPI, and Print share one height', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pos = PosController()..orderType = 'takeaway';
    pos.cart.add(
      CartLine(
        menuItem: MenuItem(
          id: 1,
          name: 'Idli',
          price: 40,
          variants: [],
          modifiers: [],
        ),
      ),
    );
    String? method;
    var parked = false;

    final quickPay = CartQuickPaySettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PosController>.value(value: pos),
          ChangeNotifierProvider.value(value: quickPay),
        ],
        child: MaterialApp(
          theme: PosTheme.build(),
          localizationsDelegates: const [AppLocalizations.delegate],
          home: Scaffold(
            body: PosCartPanel(
              compact: true,
              onPay: () {},
              onPayMethod: (value) => method = value,
              onPark: () => parked = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('PRINT'), findsOneWidget);

    final hold = tester.getSize(find.widgetWithText(FilledButton, 'Hold'));
    final upi = tester.getSize(find.widgetWithText(FilledButton, 'UPI'));
    final printButton = tester.getSize(find.widgetWithText(FilledButton, 'PRINT'));
    expect(hold.height, printButton.height);
    expect(upi.height, printButton.height);

    await tester.tap(find.text('PRINT'));
    expect(method, 'cash');
    await tester.tap(find.text('UPI'));
    expect(method, 'upi');
    await tester.tap(find.text('Hold'));
    expect(parked, isTrue);

    pos.dispose();
    quickPay.dispose();
  });
}
