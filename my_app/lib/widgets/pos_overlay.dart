import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/pos_theme.dart';
import 'pos_navigator.dart';

/// Prefer a right side panel on desktop / wide tablet widths.
const double kPosSidePanelBreakpoint = 960;

/// Near-fullscreen height for phone / compact bottom sheets.
///
/// Leaves a thin top band so the sheet still reads as an overlay, not a route.
const double kPosMobileSheetHeightFactor = 0.97;

/// Slightly shorter than cart/customize — Manage edit forms + hub panels.
const double kPosAdminSheetHeightFactor = 0.90;

/// [DraggableScrollableSheet] sizes for phone sheets.
const double kPosMobileSheetInitialSize = 0.96;
const double kPosMobileSheetMaxSize = 0.98;
const double kPosMobileSheetMinSize = 0.55;

bool preferPosSidePanel(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kPosSidePanelBreakpoint;

/// Keyboard height in logical pixels (MediaQuery + platform view fallback).
double posKeyboardInset(BuildContext context) {
  final fromMedia = MediaQuery.viewInsetsOf(context).bottom;
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return fromMedia;
  final view = View.maybeOf(context) ?? views.first;
  final fromView = view.viewInsets.bottom / view.devicePixelRatio;
  return math.max(fromMedia, fromView);
}

/// Keeps sheet / panel content above the keyboard.
///
/// Modal bottom sheets bottom-anchor their child (`bottom` stays on the
/// screen edge). Shrinking height alone still leaves the lower portion under
/// the keyboard — the spacer must be **bottom padding** equal to the inset
/// so content lays out in the area above it.
///
/// Applied automatically by [showPosBottomSheet] / side panels.
class PosKeyboardSheetHost extends StatefulWidget {
  const PosKeyboardSheetHost({super.key, required this.child});

  final Widget child;

  @override
  State<PosKeyboardSheetHost> createState() => _PosKeyboardSheetHostState();
}

class _PosKeyboardSheetHostState extends State<PosKeyboardSheetHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final inset = posKeyboardInset(context);
    final contentHeight = math.max(160.0, mq.size.height - inset);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: inset),
      child: MediaQuery(
        data: mq.copyWith(
          size: Size(mq.size.width, contentHeight),
          // Avoid nested widgets applying the keyboard inset again.
          viewInsets: EdgeInsets.zero,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Sheet height within the current [MediaQuery.size] (already keyboard-adjusted
/// when under [PosKeyboardSheetHost]).
double posMobileSheetHeight(
  BuildContext context, {
  double factor = kPosMobileSheetHeightFactor,
}) {
  final media = MediaQuery.of(context);
  final topClearance =
      media.padding.top > 0 ? media.padding.top + 8 : 8.0;
  // Prefer viewPadding when SafeArea already zeroed padding.top.
  final topGap = math.max(
    topClearance,
    media.padding.top == 0 ? 8.0 : topClearance,
  );
  final available = media.size.height - topGap;
  if (available <= 200) return available.clamp(160.0, 200.0);
  return (available * factor).clamp(200.0, available);
}

/// Fraction of a bounded parent height (e.g. scaffold body) for in-tree sheets.
double posMobileSheetHeightFor(
  double maxHeight, {
  double factor = kPosMobileSheetHeightFactor,
}) {
  if (!maxHeight.isFinite || maxHeight <= 0) return 240;
  return (maxHeight * factor).clamp(240.0, maxHeight);
}

/// Bottom-aligned near-fullscreen frame wrapping [PosBottomSheetShell].
class PosMobileSheetFrame extends StatelessWidget {
  const PosMobileSheetFrame({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.showGrabber = true,
    this.color,
    this.heightFactor = kPosMobileSheetHeightFactor,
  });

  final Widget child;
  final double maxWidth;
  final bool showGrabber;
  final Color? color;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final height = posMobileSheetHeight(context, factor: heightFactor);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: height,
          maxWidth: maxWidth,
        ),
        child: SizedBox(
          height: height,
          child: PosBottomSheetShell(
            color: color,
            showGrabber: showGrabber,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Right-edge panel for browse-heavy POS tools (orders, reports).
Future<T?> showPosSidePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 480,
  bool barrierDismissible = true,
}) {
  return posAfterNavigatorSettled<T>(context, (navContext) {
    final screenW = MediaQuery.sizeOf(navContext).width;
    final panelW = width.clamp(360.0, screenW * 0.92);

    return showGeneralDialog<T>(
      context: navContext,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(navContext).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: SizedBox(
                  width: panelW,
                  height: double.infinity,
                  child: PosKeyboardSheetHost(
                    child: builder(dialogContext),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  });
}

/// Bottom sheet used on compact / phone widths.
Future<T?> showPosBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useSafeArea = true,
}) {
  return posAfterNavigatorSettled<T>(context, (navContext) {
    return showModalBottomSheet<T>(
      context: navContext,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      builder: (ctx) => PosKeyboardSheetHost(child: builder(ctx)),
    );
  });
}

/// Side panel on wide layouts, bottom sheet otherwise.
Future<T?> showPosOverlay<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double sidePanelWidth = 480,
  bool useSafeArea = true,
}) {
  if (preferPosSidePanel(context)) {
    return showPosSidePanel<T>(
      context: context,
      width: sidePanelWidth,
      builder: builder,
    );
  }
  return showPosBottomSheet<T>(
    context: context,
    useSafeArea: useSafeArea,
    builder: builder,
  );
}

/// Drag handle + plate so mobile sheets read clearly as overlays.
class PosSheetGrabber extends StatelessWidget {
  const PosSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
      child: Center(
        child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: PosTheme.inkFaint.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// Shared chrome for modal bottom sheets on phone / portrait.
class PosBottomSheetShell extends StatelessWidget {
  const PosBottomSheetShell({
    super.key,
    required this.child,
    this.color,
    this.showGrabber = true,
  });

  final Widget child;
  final Color? color;
  final bool showGrabber;

  @override
  Widget build(BuildContext context) {
    final panelColor = color ?? PosTheme.canvas;
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(
            color: PosTheme.border.withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 40,
              offset: const Offset(0, -12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showGrabber) const PosSheetGrabber(),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared chrome for side-panel content (rounded left edge, soft shadow).
class PosSidePanelShell extends StatelessWidget {
  const PosSidePanelShell({
    super.key,
    required this.child,
    this.color,
  });

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final panelColor = color ?? PosTheme.canvas;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(20),
          right: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(-8, 0),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Material(
        color: panelColor,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(20),
          right: Radius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
