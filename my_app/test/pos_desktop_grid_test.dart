import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/pos_layout.dart';

void main() {
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
