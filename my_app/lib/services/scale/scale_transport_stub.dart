import 'scale_port.dart';

export 'scale_port.dart';

ScaleTransport createScaleTransport() => _UnavailableScaleTransport();

class _UnavailableScaleTransport implements ScaleTransport {
  @override
  bool get isSupported => false;

  @override
  bool get promptsForPort => false;

  @override
  Future<ScalePortInfo> acquirePort() {
    throw UnsupportedError(
      'Scale connection is available in Chrome, Windows, and Android.',
    );
  }

  @override
  Future<List<ScalePortInfo>> listPorts() async => const [];

  @override
  Future<void> open({
    required String name,
    required int baud,
    required int dataBits,
    required String parity,
  }) {
    throw UnsupportedError(
      'Scale connection is available in Chrome, Windows, and Android.',
    );
  }

  @override
  Future<List<int>> read() async => const [];

  @override
  Future<void> write(List<int> bytes) async {}

  @override
  Future<void> close() async {}
}
