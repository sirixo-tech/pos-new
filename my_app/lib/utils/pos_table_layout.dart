/// Responsive table-picker / floor-grid sizing.
///
/// Target cell width stays in a comfortable band as the window grows.
/// Wider screens add more columns — they do **not** shrink cards further.
double posTableMaxCrossAxisExtent(double width) {
  // Square cells with room for name + bill + chips + footer.
  if (width < 420) return 176;
  if (width < 600) return 168;
  if (width < 900) return 164;
  if (width < 1200) return 168;
  return 172;
}

double posTableGridChildAspectRatio(double width) {
  // Near-square; slight extra height avoids bottom overflow.
  if (width < 420) return 0.98;
  if (width < 600) return 0.96;
  if (width < 900) return 0.94;
  return 0.96;
}

double posTableGridSpacing(double width) {
  if (width >= 900) return 10;
  if (width >= 600) return 9;
  return 10;
}

/// Optional content max-width so ultra-wide windows keep a readable floor.
double? posTableFloorMaxWidth(double width) {
  if (width >= 1600) return 1320;
  if (width >= 1400) return 1200;
  if (width >= 1100) return 1080;
  return null;
}
