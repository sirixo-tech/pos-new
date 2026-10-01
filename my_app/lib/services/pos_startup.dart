import 'package:flutter/widgets.dart';

/// Paint before changing native window bounds. In particular, Windows must
/// finish its first-frame/show callback before entering fullscreen.
class PosStartup extends StatefulWidget {
  const PosStartup({
    super.key,
    required this.child,
    required this.initializeDisplay,
  });

  final Widget child;
  final Future<void> Function() initializeDisplay;

  @override
  State<PosStartup> createState() => _PosStartupState();
}

class _PosStartupState extends State<PosStartup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await widget.initializeDisplay();
      } catch (error, stack) {
        // A window/preference failure must not prevent the POS from rendering.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            context: ErrorDescription('initializing the POS display'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
