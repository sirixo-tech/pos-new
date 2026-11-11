import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/scale/scale_line_settings.dart';
import 'package:my_app/services/scale/scale_reading_session.dart';
import 'package:my_app/utils/weighed_barcode.dart';

void main() {
  test('scale frames split on CR, LF, and ETX', () {
    final buffer = ScaleFrameBuffer();
    expect(buffer.push('ST,GS,+  0.750'), isEmpty);
    expect(buffer.push('kg\r\nUS,NT,  1.205 kg\n'), [
      'ST,GS,+  0.750kg',
      'US,NT,  1.205 kg',
    ]);
  });

  test('a reading without ST or US is stable only after it holds', () {
    final session = ScaleReadingSession(
      stableHold: const Duration(milliseconds: 600),
    );
    final start = DateTime(2026, 1, 1, 12);
    final reading = ScaleFrame.parse('0.750')!;
    session.add(reading, start);
    expect(session.isStable(start), isFalse);
    expect(
      session.isStable(start.add(const Duration(milliseconds: 599))),
      isFalse,
    );
    expect(
      session.isStable(start.add(const Duration(milliseconds: 600))),
      isTrue,
    );
    expect(session.netKg, 0.750);
  });

  test('ST is stable immediately and tare is removed from the net weight', () {
    final session = ScaleReadingSession();
    final now = DateTime(2026, 1, 1, 12);
    session.add(ScaleFrame.parse('ST,GS,+  0.200kg')!, now);
    session.tare();
    session.add(ScaleFrame.parse('ST,GS,+  0.950kg')!, now);
    expect(session.isStable(now), isTrue);
    expect(session.netKg, 0.750);
  });

  test('US stays unsettled and a poll command keeps its line endings', () {
    final session = ScaleReadingSession();
    final now = DateTime(2026, 1, 1, 12);
    session.add(ScaleFrame.parse('US,NT,  1.205 kg')!, now);
    expect(session.isStable(now), isFalse);
    expect(
      const ScaleLineSettings(command: r'W\r\n').commandBytes,
      [87, 13, 10],
    );
  });
}
