import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/printing/printer_paper_sensor.dart';

void main() {
  test('ESC/POS paper-end sensor ignores near-end and bad replies', () {
    expect(decodeEscPosPaperSensor(0x12), PrinterPaperSensor.present);
    expect(decodeEscPosPaperSensor(0x1e), PrinterPaperSensor.present);
    expect(decodeEscPosPaperSensor(0x72), PrinterPaperSensor.empty);
    expect(decodeEscPosPaperSensor(0x7e), PrinterPaperSensor.empty);
    for (final invalid in [-1, 0, 0xff, 0x16, 0x32, 256]) {
      expect(decodeEscPosPaperSensor(invalid), PrinterPaperSensor.unknown);
    }
  });

  test('USB port status is paper-empty bit only', () {
    expect(decodeUsbPortPaperSensor(0x18), PrinterPaperSensor.present);
    expect(decodeUsbPortPaperSensor(0x38), PrinterPaperSensor.empty);
    expect(decodeUsbPortPaperSensor(0x20), PrinterPaperSensor.empty);
    for (final status in [0, 8, 16, 255, -1, 256]) {
      expect(decodeUsbPortPaperSensor(status), PrinterPaperSensor.unknown);
    }
  });
}
