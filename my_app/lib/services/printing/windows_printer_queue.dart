import 'dart:io';

/// Windows spooler reachability for a USB printer queue.
///
/// Paper-end bits are not read here. Roll messages stay on the first connect.
class WindowsPrinterQueue {
  static const _statusOffline = 7;
  static const _stateOffline = 0x80;
  static const _stateNotAvailable = 0x1000;

  static Future<({bool present, bool offline})> lookup(String name) async {
    if (!Platform.isWindows) {
      return (present: true, offline: false);
    }
    final safe = name.replaceAll("'", "''");
    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "\$p = Get-CimInstance -ClassName Win32_Printer -Filter \"Name='$safe'\"; "
              "if (\$null -eq \$p) { 'missing' } else { "
              "('{0}|{1}|{2}' -f [int]\$p.PrinterStatus, [int]\$p.WorkOffline, [int]\$p.PrinterState) }",
        ],
      ).timeout(const Duration(seconds: 4));
      final text = '${result.stdout}'.trim().toLowerCase();
      if (text.isEmpty || text.contains('missing')) {
        return (present: false, offline: true);
      }
      final parts = text.split('|');
      if (parts.length < 3) {
        return (present: true, offline: false);
      }
      final status = int.tryParse(parts[0]) ?? 0;
      final workOffline = parts[1] == '1' || parts[1] == 'true';
      final state = int.tryParse(parts[2]) ?? 0;
      final offline = workOffline ||
          status == _statusOffline ||
          (state & _stateOffline) != 0 ||
          (state & _stateNotAvailable) != 0;
      return (present: true, offline: offline);
    } catch (_) {
      return (present: false, offline: true);
    }
  }
}
