/// A serial port the weighing station can open.
class ScalePortInfo {
  const ScalePortInfo({required this.name, this.label});

  final String name;
  final String? label;

  String get title {
    final text = label?.trim();
    if (text == null || text.isEmpty || text == name) return name;
    return '$text ($name)';
  }
}

/// Bytes to and from a scale. Windows COM and Android USB serial share this.
abstract class ScaleTransport {
  bool get isSupported;

  /// Chrome asks the user to pick a serial port. Windows and Android list ports.
  bool get promptsForPort;

  Future<ScalePortInfo> acquirePort();

  Future<List<ScalePortInfo>> listPorts();

  Future<void> open({
    required String name,
    required int baud,
    required int dataBits,
    required String parity,
  });

  Future<void> write(List<int> bytes);

  Future<List<int>> read();

  Future<void> close();
}
