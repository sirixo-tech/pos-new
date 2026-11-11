import '../../utils/weighed_barcode.dart';

/// Splits a serial stream into one frame per CR, LF, or ETX.
class ScaleFrameBuffer {
  final StringBuffer _pending = StringBuffer();

  List<String> push(String chunk) {
    if (chunk.isEmpty) return const [];
    _pending.write(chunk);
    final text = _pending.toString();
    final parts = text.split(RegExp(r'[\r\n\x03]+'));
    _pending.clear();
    final complete = text.endsWith('\n') ||
        text.endsWith('\r') ||
        text.endsWith('\x03');
    if (!complete && parts.isNotEmpty) {
      _pending.write(parts.removeLast());
    }
    return [
      for (final part in parts)
        if (part.trim().isNotEmpty) part,
    ];
  }

  void clear() => _pending.clear();
}

/// Live scale reading with tare and the spec's stability rule.
///
/// `ST` / `US` decide stability when the frame has them. Otherwise the same
/// kilograms must hold for [stableHold] (600 ms).
class ScaleReadingSession {
  ScaleReadingSession({
    this.stableHold = const Duration(milliseconds: 600),
  });

  final Duration stableHold;
  double? rawKg;
  double tareKg = 0;
  bool? _frameStable;
  double? _heldKg;
  DateTime? _heldSince;

  double? get netKg {
    final raw = rawKg;
    if (raw == null) return null;
    final net = WeighedBarcode.roundKg(raw - tareKg);
    return net < 0 ? 0 : net;
  }

  bool isStable(DateTime now) {
    if (rawKg == null) return false;
    final flagged = _frameStable;
    if (flagged != null) return flagged;
    final since = _heldSince;
    if (since == null) return false;
    return now.difference(since) >= stableHold;
  }

  void add(ScaleReading reading, DateTime now) {
    final kg = reading.kilograms;
    rawKg = kg;
    if (reading.stable != null) {
      _frameStable = reading.stable;
      _heldKg = kg;
      _heldSince = null;
      return;
    }
    _frameStable = null;
    if (_heldKg == kg && _heldSince != null) return;
    _heldKg = kg;
    _heldSince = now;
  }

  void tare() {
    tareKg = rawKg ?? 0;
  }

  void clear() {
    rawKg = null;
    tareKg = 0;
    _frameStable = null;
    _heldKg = null;
    _heldSince = null;
  }
}
