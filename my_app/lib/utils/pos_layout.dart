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
    final cart = sideBudget.clamp(short ? 280.0 : 320.0, PosTheme.cartPanelWidth);
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
  if (width >= 1280) return 6;
  if (width >= 980) return 5;
  if (width >= 740) return 4;
  if (width >= 520) return 3;
  return 2;
}

/// Grid cell aspect ratio for 4:3 image + footer.
///
/// [width] must be the **menu pane** width (not full window) — on desktop the
/// category rail + cart shrink the grid, and using screen width overflows cards.
double posMenuGridChildAspectRatio(double width, {bool compact = false}) {
  final crossAxisCount = posMenuGridCrossAxisCount(width);
  const horizontalPadding = 32.0;
  const spacing = 10.0;
  final cellWidth =
      (width - horizontalPadding - spacing * (crossAxisCount - 1)) /
      crossAxisCount;
  final imageHeight = cellWidth * 0.72;
  final footerHeight = compact ? 70.0 : 92.0;
  return cellWidth / (imageHeight + footerHeight);
}
