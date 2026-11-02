import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/pos_theme.dart';

/// Tablet landscape or wide window → 3-pane register layout (matches web POS lg+).
bool usePosDesktopLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final shortest = size.shortestSide;
  return size.width >= 900 || (shortest >= 600 && size.width > size.height);
}

/// Below this width, KOT opens as a slide-over instead of a dock column.
const double kPosKotOverlayBreakpoint = 1150;

/// Vertical category rail width in desktop register layout.
const double kPosCategoryRailWidth = 128;

/// How much to shrink a 1024×768-class register so it matches larger screens.
///
/// Other resolutions return 1 and are laid out exactly as before.
const double kPosCompactRegisterScale = 0.82;

/// True for the physical 1024×768 monitor class, including Windows DPI scaling.
bool usePosCompactRegister(Size logicalSize, double devicePixelRatio) {
  final width = logicalSize.width * devicePixelRatio;
  final height = logicalSize.height * devicePixelRatio;
  return width >= height &&
      width >= 980 &&
      width <= 1100 &&
      height >= 680 &&
      height <= 820;
}

double posCompactRegisterScale(Size logicalSize, double devicePixelRatio) {
  return usePosCompactRegister(logicalSize, devicePixelRatio)
      ? kPosCompactRegisterScale
      : 1;
}

/// Narrow portrait terminals such as the iMin NM2 Pro.
bool usePosHandheldLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width < 600 || (size.width <= 800 && size.height > size.width);
}

/// Minimum share of the window reserved for the menu grid.
const double kPosMenuMinFraction = 0.40;

class PosDesktopPanelLayout {
  const PosDesktopPanelLayout({
    required this.kotColumnWidth,
    required this.cartWidth,
    required this.kotInline,
    required this.cartCompact,
    required this.kotSplitCompact,
  });

  final double kotColumnWidth;
  final double cartWidth;
  final bool kotInline;
  final bool cartCompact;
  final bool kotSplitCompact;
}

PosDesktopPanelLayout resolvePosDesktopPanelLayout({
  required double totalWidth,
  required bool kotOpen,
  required bool short,
  bool categoryRailVisible = true,
}) {
  final rail = categoryRailVisible ? kPosCategoryRailWidth : 0.0;
  final menuMin = totalWidth * kPosMenuMinFraction;
  final sideBudget = math.max(0.0, totalWidth - rail - menuMin);
  final kotInline = kotOpen && totalWidth >= kPosKotOverlayBreakpoint;

  if (!kotOpen) {
    final cart = sideBudget.clamp(
      short ? 280.0 : 320.0,
      totalWidth <= 1100 ? 320.0 : PosTheme.cartPanelWidth,
    );
    return PosDesktopPanelLayout(
      kotColumnWidth: 0,
      cartWidth: cart,
      kotInline: false,
      cartCompact: cart < 340 || short,
      kotSplitCompact: false,
    );
  }

  if (!kotInline) {
    final cart = sideBudget.clamp(short ? 280.0 : 320.0, 400.0);
    return PosDesktopPanelLayout(
      kotColumnWidth: 0,
      cartWidth: cart,
      kotInline: false,
      cartCompact: cart < 340,
      kotSplitCompact: true,
    );
  }

  final kot = (sideBudget * 0.38).clamp(250.0, 300.0);
  final cart = (sideBudget - kot).clamp(300.0, 420.0);
  return PosDesktopPanelLayout(
    kotColumnWidth: kot,
    cartWidth: cart,
    kotInline: true,
    cartCompact: true,
    kotSplitCompact: true,
  );
}

int posMenuGridCrossAxisCount(double width) {
  // Keep cards near 140–170 logical pixels on registers with a narrow
  // menu pane after the category rail and ticket have taken their space.
  if (width >= 1040) return 6;
  if (width >= 860) return 5;
  if (width >= 540) return 4;
  // A 1024px register leaves about 392px after its rail, cart and padding.
  if (width >= 380) return 3;
  return 2;
}

/// Grid cell aspect ratio for 4:3 image + footer.
///
/// [width] must be the **menu pane** width (not full window) — on desktop the
/// category rail + cart shrink the grid, and using screen width overflows cards.
double posMenuGridChildAspectRatio(
  double width, {
  bool compact = false,
  bool images = true,
}) {
  final crossAxisCount = posMenuGridCrossAxisCount(width);
  const horizontalPadding = 32.0;
  const spacing = 14.0;
  final cellWidth =
      (width - horizontalPadding - spacing * (crossAxisCount - 1)) /
      crossAxisCount;
  final fullImageHeight = cellWidth * 0.72;
  final imageHeight = images ? fullImageHeight * 0.9 : 0.0;
  final footerHeight = images
      ? (compact ? 70.0 : 92.0) + fullImageHeight * 0.1
      : cellWidth * 0.9;
  return cellWidth / (imageHeight + footerHeight);
}

/// Phone menu card height. Matches the photo/color header plus name, price, and ADD.
/// Lays a 1024×768 register out on a larger canvas, then fits it to the window.
/// Every other size returns [child] unchanged.
class PosCompactRegisterFrame extends StatelessWidget {
  const PosCompactRegisterFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = posCompactRegisterScale(media.size, media.devicePixelRatio);
    if (scale == 1) return child;

    final factor = 1 / scale;
    final logical = Size(media.size.width * factor, media.size.height * factor);
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: logical.width,
        height: logical.height,
        child: MediaQuery(
          data: media.copyWith(
            size: logical,
            padding: media.padding * factor,
            viewPadding: media.viewPadding * factor,
            viewInsets: media.viewInsets * factor,
          ),
          child: child,
        ),
      ),
    );
  }
}

double handheldMenuCardExtent(BuildContext context, double paneWidth) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  final cellWidth = (paneWidth - 34) / 2;
  final imageHeight = (cellWidth - 16) / 2.2;
  final nameHeight = 12 * 1.15 * 2 * scale;
  final priceHeight = 18 * scale;
  return imageHeight + 16 + 6 + nameHeight + 4 + priceHeight + 6 + 44 + 8;
}
