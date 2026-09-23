import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Root navigator for POS overlays (sheets, dialogs) from any context —
/// including widgets above the route stack (e.g. lock overlay siblings).
final GlobalKey<NavigatorState> posRootNavigatorKey = GlobalKey<NavigatorState>();

/// Context under the root [Navigator], if mounted.
BuildContext? get posRootNavigatorContext =>
    posRootNavigatorKey.currentState?.mounted == true
        ? posRootNavigatorKey.currentContext
        : null;

/// Runs [action] after the current navigator transaction finishes.
///
/// Avoids `!_debugLocked` when opening a sheet/dialog from a tap that also
/// closes another route (popup menus) or rebuilds the navigator tree.
Future<T?> posAfterNavigatorSettled<T>(
  BuildContext context,
  Future<T?> Function(BuildContext navContext) action,
) async {
  await SchedulerBinding.instance.endOfFrame;
  await Future<void>.delayed(Duration.zero);
  final navContext = posRootNavigatorContext;
  if (navContext != null) {
    return action(navContext);
  }
  if (!context.mounted) return null;
  return action(context);
}
