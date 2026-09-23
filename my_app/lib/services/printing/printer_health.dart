import 'usb_printer_config.dart';

enum PrinterHealthState {
  unsupported,
  none,
  missing,
  notPrintable,
  attention,
  ready,
  error,
}

/// Soft + CUPS-derived printer health for staff UI.
class PrinterHealth {
  const PrinterHealth({
    required this.state,
    this.config,
    this.device,
    this.message,
    this.issues = const [],
    this.cupsState,
    this.lastCheckedAt,
    this.jobSubmitted = false,
  });

  final PrinterHealthState state;
  final UsbPrinterConfig? config;
  final UsbPrinterDevice? device;
  final String? message;
  final List<String> issues;
  final String? cupsState;
  final DateTime? lastCheckedAt;

  /// True when a test/receipt job was accepted by the OS queue (not proof of print).
  final bool jobSubmitted;

  PrinterHealth copyWith({
    PrinterHealthState? state,
    UsbPrinterConfig? config,
    UsbPrinterDevice? device,
    String? message,
    List<String>? issues,
    String? cupsState,
    DateTime? lastCheckedAt,
    bool? jobSubmitted,
  }) {
    return PrinterHealth(
      state: state ?? this.state,
      config: config ?? this.config,
      device: device ?? this.device,
      message: message ?? this.message,
      issues: issues ?? this.issues,
      cupsState: cupsState ?? this.cupsState,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      jobSubmitted: jobSubmitted ?? this.jobSubmitted,
    );
  }

  String get displayName =>
      device?.name ?? config?.name ?? 'Receipt printer';

  bool get hasIssue =>
      state == PrinterHealthState.attention ||
      state == PrinterHealthState.error ||
      state == PrinterHealthState.missing ||
      state == PrinterHealthState.notPrintable ||
      state == PrinterHealthState.none ||
      state == PrinterHealthState.unsupported;

  bool get canTestPrint =>
      state == PrinterHealthState.ready || state == PrinterHealthState.attention;

  /// Cached status that must not start a USB/BLE/LAN connect on checkout.
  bool get blocksPrinting {
    if (issues.contains('paper_out') ||
        issues.contains('offline') ||
        issues.contains('missing')) {
      return true;
    }
    switch (state) {
      case PrinterHealthState.none:
      case PrinterHealthState.missing:
      case PrinterHealthState.error:
      case PrinterHealthState.notPrintable:
        return true;
      case PrinterHealthState.unsupported:
      case PrinterHealthState.attention:
      case PrinterHealthState.ready:
        return false;
    }
  }

  String get statusLabel {
    switch (state) {
      case PrinterHealthState.unsupported:
        return 'Unsupported';
      case PrinterHealthState.none:
        return 'Not selected';
      case PrinterHealthState.missing:
        return 'Disconnected';
      case PrinterHealthState.notPrintable:
        return 'Needs setup';
      case PrinterHealthState.attention:
        return issueLabel(issues.isEmpty ? 'attention' : issues.first);
      case PrinterHealthState.ready:
        return 'Ready';
      case PrinterHealthState.error:
        return 'Error';
    }
  }

  static String issueLabel(String issue) {
    switch (issue) {
      case 'paper_out':
        return 'Paper out';
      case 'paper_low':
        return 'Paper low';
      case 'cover_open':
        return 'Cover open';
      case 'jam':
        return 'Paper jam';
      case 'offline':
        return 'Offline';
      case 'paused':
      case 'stopped':
        return 'Paused';
      case 'supply':
        return 'Supply low';
      case 'missing':
        return 'Not found';
      default:
        return 'Needs attention';
    }
  }

  /// Map CUPS / transport failure text into staff-friendly issues.
  static List<String> issuesFromErrorMessage(String raw) {
    final text = raw.toLowerCase();
    final issues = <String>[];
    if (text.contains('media-empty') ||
        text.contains('media-needed') ||
        text.contains('out of paper') ||
        text.contains('paper out') ||
        text.contains('no paper')) {
      issues.add('paper_out');
    }
    if (text.contains('media-low') || text.contains('paper low')) {
      issues.add('paper_low');
    }
    if (text.contains('cover') || text.contains('door open')) {
      issues.add('cover_open');
    }
    if (text.contains('jam')) {
      issues.add('jam');
    }
    if (text.contains('offline') || text.contains('not responding')) {
      issues.add('offline');
    }
    if (text.contains('paused') || text.contains('stopped')) {
      issues.add('paused');
    }
    if (issues.isEmpty) {
      issues.add('attention');
    }
    return issues;
  }

  static String messageForIssues(List<String> issues, {String? fallback}) {
    if (issues.contains('paper_out')) {
      return 'Paper out — load paper and clear the printer error.';
    }
    if (issues.contains('paper_low')) {
      return 'Paper is low — refill soon.';
    }
    if (issues.contains('cover_open')) {
      return 'Printer cover is open.';
    }
    if (issues.contains('jam')) {
      return 'Paper jam — clear the path and try again.';
    }
    if (issues.contains('offline')) {
      return 'Printer is offline — check power and cable.';
    }
    if (issues.contains('paused') || issues.contains('stopped')) {
      return 'Printer queue is paused — resume it in system printer settings.';
    }
    if (issues.contains('supply')) {
      return 'Printer supply is low or empty.';
    }
    return fallback ?? 'Printer needs attention.';
  }
}
