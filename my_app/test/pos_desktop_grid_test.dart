import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/pos_layout.dart';

void main() {
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
