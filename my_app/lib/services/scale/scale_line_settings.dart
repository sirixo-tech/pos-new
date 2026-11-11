import 'dart:convert';

/// Line settings for one scale. Stored on this register, applied on the next connect.
class ScaleLineSettings {
  const ScaleLineSettings({
    this.baud = 9600,
    this.parity = 'none',
    this.dataBits = 8,
    this.unit = 'auto',
    this.command = '',
  });

  static const baudRates = <int>[2400, 4800, 9600, 19200, 38400, 57600, 115200];
  static const parities = <String>['none', 'even', 'odd'];
  static const dataBitChoices = <int>[7, 8];
  static const units = <String>['auto', 'kg', 'g'];

  final int baud;
  final String parity;
  final int dataBits;

  /// `auto` uses the unit in the scale frame. `kg` and `g` apply when the frame has none.
  final String unit;

  /// Optional poll, typed with `\r` and `\n`. Empty means the scale streams on its own.
  final String command;

  bool get assumeGrams => unit == 'g';

  List<int> get commandBytes {
    final text = command
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '\t');
    if (text.isEmpty) return const [];
    return utf8.encode(text);
  }

  ScaleLineSettings copyWith({
    int? baud,
    String? parity,
    int? dataBits,
    String? unit,
    String? command,
  }) {
    return ScaleLineSettings(
      baud: baud ?? this.baud,
      parity: parity ?? this.parity,
      dataBits: dataBits ?? this.dataBits,
      unit: unit ?? this.unit,
      command: command ?? this.command,
    );
  }
}
