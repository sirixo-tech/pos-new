/// Reconnect before sending bytes, but never replay a possibly partial ticket.
Future<void> sendBluetoothPrint({
  required Future<bool> Function() isConnected,
  required Future<bool> Function() connect,
  required Future<void> Function() write,
  required String connectionError,
}) async {
  bool live;
  try {
    live = await isConnected();
  } catch (_) {
    live = false;
  }
  if (!live && !await connect()) throw StateError(connectionError);
  try {
    await write();
  } catch (error) {
    throw StateError('printer write failed: $error');
  }
}
