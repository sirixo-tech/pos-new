import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/pos_layout.dart';

void main() {
  test('only a 1024 by 768 register is scaled down', () {
    expect(posCompactRegisterScale(const Size(1024, 768), 1), 0.82);
    expect(
      posCompactRegisterScale(const Size(819.2, 614.4), 1.25),
      0.82,
    );
    expect(posCompactRegisterScale(const Size(1366, 768), 1), 1);
    expect(posCompactRegisterScale(const Size(1280, 800), 1), 1);
    expect(posCompactRegisterScale(const Size(1920, 1080), 1), 1);
    expect(posCompactRegisterScale(const Size(390, 844), 1), 1);
  });

  test('1024 by 768 register shows four menu columns beside a narrow cart', () {
    final panels = resolvePosDesktopPanelLayout(
      totalWidth: 1024, kotOpen: false, short: true,
    );
    final menuWidth = 1024 - kPosCategoryRailWidth - panels.cartWidth - 32;
    expect(panels.cartWidth, 320);
    expect(posMenuGridCrossAxisCount(menuWidth), 4);
    expect(posMenuGridChildAspectRatio(menuWidth, compact: true), greaterThan(0));
  });
  for (final scale in [1.0, 1.25, 1.5]) {
    test('1080p register shows at least three columns at $scale scaling', () {
      final windowWidth = 1920 / scale;
      final panels = resolvePosDesktopPanelLayout(
        totalWidth: windowWidth,
        kotOpen: false,
        short: 1080 / scale < 800,
      );
      final menuWidth =
          windowWidth - kPosCategoryRailWidth - panels.cartWidth - 32;
      expect(posMenuGridCrossAxisCount(menuWidth), greaterThanOrEqualTo(3));
      expect(posMenuGridChildAspectRatio(menuWidth), greaterThan(0));
    });
  }
}
