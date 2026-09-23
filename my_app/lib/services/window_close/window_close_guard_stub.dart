class WindowCloseGuard {
  WindowCloseGuard({required this.onCloseRequest});

  final Future<bool> Function() onCloseRequest;

  Future<void> install() async {}

  void dispose() {}
}
