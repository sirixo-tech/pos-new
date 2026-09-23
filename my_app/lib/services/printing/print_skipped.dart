import '../pos_api.dart';
import 'printer_health.dart';

/// Receipt or KOT was intentionally not printed (backend flags / empty job).
class PrintSkipped implements Exception {
  const PrintSkipped(this.message);

  final String message;

  @override
  String toString() => message;
}

bool isPrintingDisabled(Object error) {
  if (error is PrintSkipped) return true;
  final status = error is PosApiException ? error.statusCode : null;
  if (status == 401 || status == 403) return false;
  if (status != null && (status < 400 || status >= 500) && status != 404) {
    return false;
  }
  final text = error.toString().toLowerCase();
  if (text.contains('no print object') ||
      text.contains('no printable content')) {
    return true;
  }
  if (text.contains('customer and counter receipts are disabled')) {
    return true;
  }
  return text.contains('nothing to print') &&
      text.contains('disabled') &&
      (text.contains('receipt') ||
          text.contains('kot') ||
          text.contains('kitchen'));
}

bool isPrinterPaperOut(Object error) {
  return PrinterHealth.issuesFromErrorMessage(error.toString())
      .contains('paper_out');
}

bool isPrinterDisconnected(Object error) {
  if (isKotNotReady(error) || isPrinterMissing(error)) return false;
  final issues = PrinterHealth.issuesFromErrorMessage(error.toString());
  if (issues.contains('offline') || issues.contains('missing')) return true;
  final text = error.toString().toLowerCase();
  return text.contains('not found') ||
      text.contains('disconnected') ||
      text.contains('not connected') ||
      text.contains('unable to connect') ||
      (text.contains('connect') && text.contains('printer')) ||
      text.contains('no printer');
}

bool isPrinterMissing(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('no printer selected') ||
      text.contains('select a printer') ||
      (text.contains('configure') && text.contains('printer')) ||
      text.contains('printer is not set') ||
      text.contains('no receipt printer') ||
      (text.contains('missing') && text.contains('printer'));
}

/// Kitchen ticket payload is not on the device yet (order saved, slips lag).
bool isKotNotReady(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('no kot slips') ||
      text.contains('kot is not available') ||
      (text.contains('no printable') && text.contains('kot')) ||
      text.contains('not available yet');
}
