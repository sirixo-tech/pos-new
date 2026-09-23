/// Paper-end sensor only. Near-end and estimated roll length are not empty.
enum PrinterPaperSensor { present, empty, unknown }

/// Epson ESC/POS realtime status: `DLE EOT 4` (roll paper sensor).
///
/// Bits 5–6 are the paper-end sensor. Bits 2–3 are near-end and still mean
/// a roll is loaded, so they stay [PrinterPaperSensor.present].
PrinterPaperSensor decodeEscPosPaperSensor(int status) {
  if (status < 0 || status > 255 || (status & 0x93) != 0x12) {
    return PrinterPaperSensor.unknown;
  }
  final end = status & 0x60;
  final nearEnd = status & 0x0c;
  if ((end != 0 && end != 0x60) || (nearEnd != 0 && nearEnd != 0x0c)) {
    return PrinterPaperSensor.unknown;
  }
  if (end == 0x60) return PrinterPaperSensor.empty;
  return PrinterPaperSensor.present;
}

/// USB printer class GET_PORT_STATUS. Bit 5 is Paper Empty.
PrinterPaperSensor decodeUsbPortPaperSensor(int status) {
  if (status < 0 || status > 255 || (status & 0xc7) != 0) {
    return PrinterPaperSensor.unknown;
  }
  if ((status & 0x20) != 0) return PrinterPaperSensor.empty;
  return (status & 0x18) == 0x18
      ? PrinterPaperSensor.present
      : PrinterPaperSensor.unknown;
}
