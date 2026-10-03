import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/providers/pos_category_bar_settings.dart';
import 'package:my_app/providers/pos_catalog_layout_settings.dart';
import 'package:my_app/providers/pos_theme_controller.dart';
import 'package:my_app/widgets/pos_appearance_picker.dart';
import 'package:my_app/widgets/pos_register_workspace.dart';
import 'package:my_app/theme/pos_theme.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/l10n/pos_l10n.dart';
import 'package:my_app/providers/cart_quick_pay_settings.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/widgets/pos_cart_panel.dart';
import 'package:my_app/widgets/pos_category_rail.dart';
import 'package:my_app/widgets/pos_menu_item_card.dart';

class _FontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      'fonts/Inter-$weight.ttf',
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MenuItem item(int id) => MenuItem(
  id: id,
  name: ['Bhajji / Pakoda (4pc)', 'Bisibele Bhath', 'Chow Chow Bath'][id % 3],
  price: 25,
  variants: [],
  modifiers: [],
);

class _CatalogController extends PosController {
  final catalog = [
    MenuCategory(id: 1, name: 'Breakfast', items: [item(0), item(1), item(2)]),
  ];
  @override
  List<MenuCategory> get categories => catalog;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    fonts.assetManifest = _FontManifest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key.startsWith('fonts/Inter-')) {
            final path = Platform.environment['POS_PREVIEW_FONT'];
            return path == null
                ? ByteData(0)
                : (await File(path).readAsBytes()).buffer.asByteData();
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    fonts.assetManifest = null;
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(720, 1280),
  ]) {
    testWidgets(
      'Appearance applies left/top and dark mode at $size without stale contexts',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pos = _CatalogController();
        final bar = PosCategoryBarSettings();
        final catalog = PosCatalogLayoutSettings();
        final theme = PosThemeController();
        final search = TextEditingController();
        final sourceVisible = ValueNotifier(true);
        var added = 0;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PosController>.value(value: pos),
              ChangeNotifierProvider.value(value: bar),
              ChangeNotifierProvider.value(value: catalog),
              ChangeNotifierProvider.value(value: theme),
            ],
            child: AnimatedBuilder(
              animation: theme,
              builder: (_, _) => MaterialApp(
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeMode: theme.mode,
                localizationsDelegates: const [AppLocalizations.delegate],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Column(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: sourceVisible,
                        builder: (context, visible, _) => visible
                            ? Builder(
                                builder: (sourceContext) => TextButton(
                                  onPressed: () =>
                                      showPosAppearancePicker(sourceContext),
                                  child: const Text('Change appearance'),
                                ),
                              )
                            : const SizedBox(height: 48),
                      ),
                      Expanded(
                        child: PosRegisterWorkspace(
                          searchController: search,
                          onItemTap: (_) => added++,
                          onPay: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        var rail = tester.widget<PosCategoryRail>(find.byType(PosCategoryRail));
        expect(rail.horizontal, isFalse);
        expect(
          tester.getSize(find.byType(PosCategoryRail)).width,
          lessThanOrEqualTo(104),
        );
        expect(
          tester.getRect(find.byType(PosMenuItemCard).first).left,
          greaterThan(tester.getRect(find.byType(PosCategoryRail)).right),
        );
        await tester.tap(find.byTooltip('Add item').first);
        expect(added, 1);
        await tester.tap(find.text('Change appearance'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Top'));
        await tester.tap(find.text('Top'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PosCategoryRail>(find.byType(PosCategoryRail))
              .horizontal,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Left'));
        await tester.tap(find.text('Left'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PosCategoryRail>(find.byType(PosCategoryRail))
              .horizontal,
          isFalse,
        );
        final reloaded = PosCategoryBarSettings();
        await reloaded.load();
        expect(reloaded.isTop, isFalse);
        reloaded.dispose();
        await tester.ensureVisible(find.text('Dark'));
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        expect(theme.mode, ThemeMode.dark);
        expect(
          Theme.of(
            tester.element(find.byType(PosRegisterWorkspace)),
          ).brightness,
          Brightness.dark,
        );
        expect(
          tester
              .widget<Material>(
                find
                    .descendant(
                      of: find.byType(PosMenuItemCard).first,
                      matching: find.byType(Material),
                    )
                    .first,
              )
              .color,
          PosTheme.surfaceDark,
        );
        await tester.tap(find.text('Change appearance'));
        sourceVisible.value = false;
        await tester.pumpAndSettle();
        await theme.setMode(ThemeMode.light);
        await tester.pumpAndSettle();
        await bar.setPlacement(PosCategoryBarPlacement.top);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        pos.dispose();
        bar.dispose();
        catalog.dispose();
        theme.dispose();
        search.dispose();
        sourceVisible.dispose();
      },
    );
  }
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(720, 1280),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('compact menu and ticket at $size / $scale', (tester) async {
        final fontPath = Platform.environment['POS_PREVIEW_FONT'];
        if (fontPath != null) {
          await tester.runAsync(() async {
            final bytes = (await File(
              fontPath,
            ).readAsBytes()).buffer.asByteData();
            for (final family in [
              'Preview',
              'Roboto',
              'Inter_regular',
              'Inter_500',
              'Inter_600',
              'Inter_700',
              'Inter_800',
            ]) {
              await (FontLoader(family)..addFont(Future.value(bytes))).load();
            }
            final iconPath = Platform.environment['POS_PREVIEW_ICONS'];
            if (iconPath != null) {
              final icons = (await File(
                iconPath,
              ).readAsBytes()).buffer.asByteData();
              await (FontLoader(
                'MaterialIcons',
              )..addFont(Future.value(icons))).load();
            }
          });
        }
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previewKey = GlobalKey();
        Future<void> preview(String name) async {
          if (!Platform.environment.containsKey('POS_PREVIEW_FONT')) return;
          await tester.runAsync(() async {
            final boundary =
                previewKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'build/handheld-preview/$name-${size.width.toInt()}-$scale.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        Widget app(Widget child) => MaterialApp(
          theme: ThemeData(
            fontFamily: fontPath == null ? null : 'Preview',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFB84A00),
            ),
          ),
          localizationsDelegates: const [AppLocalizations.delegate],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: previewKey,
            child: Scaffold(body: child),
          ),
        );
        var added = 0;
        int? selected;
        await tester.pumpWidget(
          app(
            Column(
              children: [
                PosCategoryRail(
                  categories: [
                    MenuCategory(id: 1, name: 'Breakfast', items: []),
                  ],
                  activeCategoryId: null,
                  horizontal: true,
                  onSelect: (id) => selected = id,
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < 6; i++)
                        PosMenuItemCard(
                          item: item(i),
                          currency: 'INR',
                          handheld: true,
                          onTap: () => added++,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(PosCategoryRail)).height, 60);
        expect(
          tester.getSize(find.byType(PosMenuItemCard).first).height,
          lessThan(100),
        );
        await tester.tap(find.text('Breakfast'));
        expect(selected, 1);
        await tester.tap(find.byTooltip('Add item').first);
        expect(added, 1);
        await tester.pumpAndSettle();
        await preview('menu');

        final line = CartLine(menuItem: item(0), quantity: 2);
        var increased = false;
        var decreased = false;
        await tester.pumpWidget(
          app(
            Align(
              alignment: Alignment.topCenter,
              child: PosMenuItemCard(
                item: line.menuItem,
                currency: 'INR',
                handheld: true,
                inTicketQty: 2,
                simpleCartLine: line,
                onTap: () {},
                onIncrementSimple: (_) => increased = true,
                onDecrementSimple: (_) => decreased = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Increase quantity'));
        await tester.tap(find.byTooltip('Decrease quantity'));
        expect(increased && decreased, isTrue);

        final pos = PosController()..orderType = 'takeaway';
        pos.cart.addAll([
          for (var i = 0; i < 3; i++) CartLine(menuItem: item(i)),
        ]);
        final quickPay = CartQuickPaySettings();
        var paid = false;
        await tester.pumpWidget(
          app(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: pos),
                ChangeNotifierProvider.value(value: quickPay),
              ],
              child: Column(
                children: [
                  const SizedBox(
                    height: 56,
                    child: Center(child: Text('Current ticket')),
                  ),
                  Expanded(
                    child: PosCartPanel(
                      onPay: () => paid = true,
                      onPark: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Pay').hitTestable(), findsOneWidget);
        expect(
          find.text('Bhajji / Pakoda (4pc)').hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Bisibele Bhath').hitTestable(), findsOneWidget);
        await preview('ticket');
        await tester.tap(find.text('Totals'));
        await tester.pumpAndSettle();
        expect(find.text('Order totals'), findsOneWidget);
        expect(find.text('Subtotal'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pay'));
        expect(paid, isTrue);
        await tester.pumpWidget(const SizedBox());
        pos.dispose();
        quickPay.dispose();
      });
    }
  }
}
