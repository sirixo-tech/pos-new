import 'dart:async';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

bool _installerShutdownAllowed = false;

/// The user has already chosen to install an update. Allow Restart Manager
/// to close the app without displaying the normal cashier exit confirmation.
Future<void> allowWindowCloseForUpdate(bool allowed) async {
  if (!Platform.isWindows) return;
  _installerShutdownAllowed = allowed;
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(!allowed);
}

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
    if (_installerShutdownAllowed) return;
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
