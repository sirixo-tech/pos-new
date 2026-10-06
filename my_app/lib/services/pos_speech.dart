import 'package:speech_to_text/speech_to_text.dart';

/// One microphone session for menu voice entry and POS item search.
class PosSpeech {
  PosSpeech._();

  static final PosSpeech instance = PosSpeech._();

  final SpeechToText _speech = SpeechToText();
  Future<bool>? _ready;

  bool get isListening => _speech.isListening;

  Future<bool> prepare() {
    return _ready ??= _speech.initialize().then((ready) => ready).catchError((
      _,
    ) {
      _ready = null;
      return false;
    });
  }

  Future<bool> listen({
    required void Function(String words, bool isFinal) onResult,
    ListenMode mode = ListenMode.dictation,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final ready = await prepare();
    if (!ready) return false;
    if (_speech.isListening) {
      await _speech.stop();
    }
    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          listenMode: mode,
          partialResults: true,
          listenFor: listenFor,
          pauseFor: pauseFor,
        ),
      );
    } catch (_) {
      return false;
    }
    return true;
  }

  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }
}
