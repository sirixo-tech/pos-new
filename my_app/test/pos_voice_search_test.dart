import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/pos_speech.dart';
import 'package:my_app/widgets/pos_listening_bars.dart';
import 'package:my_app/widgets/pos_voice_search_button.dart';
import 'package:speech_to_text/speech_to_text.dart';

class TestSpeech extends PosSpeech {
  void Function(String, bool)? result;
  ValueChanged<bool>? listening;
  ValueChanged<String>? error;
  Duration? silenceLimit;
  int starts = 0;
  int stops = 0;

  @override
  Future<bool> listen({
    required void Function(String words, bool isFinal) onResult,
    ValueChanged<bool>? onListening,
    ValueChanged<String>? onError,
    List<String> vocabulary = const [],
    ListenMode mode = ListenMode.dictation,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    starts++;
    result = onResult;
    listening = onListening;
    error = onError;
    silenceLimit = pauseFor;
    onListening?.call(true);
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    listening?.call(false);
  }
}

void main() {
  testWidgets('unrelated speech never changes search and allows a retry', (
    tester,
  ) async {
    final speech = TestSpeech();
    final queries = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosVoiceSearchButton(
            speech: speech,
            itemNames: const ['Plain dosa', 'Idli'],
            onText: queries.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    speech.result!('good news', true);
    await tester.pump();
    expect(queries, isEmpty);
    expect(speech.stops, 0);
    expect(
      find.text('No matching menu item heard. Say the item name again.'),
      findsOneWidget,
    );
    speech.result!('Dosa', true);
    await tester.pump();
    expect(queries, ['dosa']);
    expect(speech.stops, 1);
  });
  testWidgets('listening bars fit the 32 pixel microphone interior', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 32,
            height: 30,
            child: PosListeningBars(active: true, height: 16),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('$platform voice results update search and stop on final', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final speech = TestSpeech();
      final words = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosVoiceSearchButton(
              speech: speech,
              onText: words.add,
              itemNames: const ['Masala dosa'],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(speech.silenceLimit, const Duration(seconds: 5));
      speech.result!('Masala', false);
      await tester.pump();
      expect(words, isEmpty);
      speech.result!('Masala dosa.', true);
      await tester.pump();
      expect(words.last, 'masala dosa');
      expect(speech.stops, 1);
      expect(find.byType(PosListeningBars), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('native stop clears listening and bound stop never restarts', (
    tester,
  ) async {
    final speech = TestSpeech();
    Future<void> Function()? stop;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosVoiceSearchButton(
            speech: speech,
            itemNames: const ['Dosa'],
            onText: (_) {},
            onBindStop: (callback) => stop = callback,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    speech.listening!(false);
    await tester.pump();
    expect(find.byType(PosListeningBars), findsNothing);
    await stop!();
    expect(speech.starts, 1);
  });
}
