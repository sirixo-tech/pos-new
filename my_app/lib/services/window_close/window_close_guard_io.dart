import 'dart:async';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

class WindowCloseGuard with WindowListener {
  WindowCloseGuard({required this.onCloseRequest});

  final Future<bool> Function() onCloseRequest;
  bool _closing = false;
  bool _installed = false;

  Future<void> install() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    _installed = true;
  }

  @override
  void onWindowClose() {
    if (_closing) return;
    unawaited(_confirmAndClose());
  }

  Future<void> _confirmAndClose() async {
    bool shouldClose;
    try {
      shouldClose = await onCloseRequest();
    } on Object {
      return;
    }
    if (!shouldClose) return;
    _closing = true;
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    exit(0);
  }

  void dispose() {
    if (!_installed) return;
    windowManager.removeListener(this);
  }
}
