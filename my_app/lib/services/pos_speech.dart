import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// One microphone session for menu voice entry and POS item search.
class PosSpeech {
  PosSpeech({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  static final PosSpeech instance = PosSpeech();

  final SpeechToText _speech;
  Future<bool>? _ready;
  ValueChanged<bool>? _onListening;
  ValueChanged<String>? _onError;
  static const _menuChannel = MethodChannel('selfx/menu_speech');
  bool _menuListening = false;
  Timer? _menuTimer;

  bool get isListening => _menuListening || _speech.isListening;

  Future<bool> prepare() async {
    try {
      final ready = await (_ready ??= _speech.initialize(
        onStatus: (status) {
          if (status == 'listening') _onListening?.call(true);
          if (status == 'notListening' || status == 'done') {
            _onListening?.call(false);
          }
        },
        onError: (error) {
          _onError?.call(error.errorMsg);
          _onListening?.call(false);
        },
      ));
      if (!ready) _ready = null;
      return ready;
    } catch (_) {
      _ready = null;
      return false;
    }
  }

  Future<bool> listen({
    required void Function(String words, bool isFinal) onResult,
    ValueChanged<bool>? onListening,
    ValueChanged<String>? onError,
    List<String> vocabulary = const [],
    ListenMode mode = ListenMode.dictation,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (isListening) {
      await stop();
    }
    _onListening = onListening;
    _onError = onError;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        vocabulary.isNotEmpty) {
      _menuChannel.setMethodCallHandler((call) async {
        final data = call.arguments;
        if (call.method == 'result' && data is Map && _menuListening) {
          onResult(data['words'] as String? ?? '', data['final'] == true);
        }
      });
      try {
        _menuListening =
            await _menuChannel.invokeMethod<bool>('listen', {
              'words': vocabulary,
            }) ??
            false;
        _onListening?.call(_menuListening);
        if (_menuListening) {
          _menuTimer = Timer(listenFor, () => unawaited(stop()));
        }
        return _menuListening;
      } on MissingPluginException catch (_) {
        _onError?.call(
          'Stop and restart the Windows app to load menu voice search.',
        );
        return false;
      } on PlatformException catch (_) {
        _onError?.call('Windows speech recognition could not start.');
        return false;
      }
    }
    final ready = await prepare();
    if (!ready) return false;
    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          listenMode: mode,
          partialResults: true,
          listenFor: listenFor,
          // Windows SAPI may only return words after the phrase is complete.
          // Its sound notifications do not reset the plugin's silence timer.
          // Keep listening until the session limit or an explicit stop instead.
          pauseFor: defaultTargetPlatform == TargetPlatform.windows
              ? null
              : pauseFor,
          cancelOnError: true,
          contextualPhrases: vocabulary,
        ),
      );
    } catch (_) {
      _onError?.call('Speech recognition could not start.');
      _onListening?.call(false);
      return false;
    }
    return _speech.isListening;
  }

  Future<void> stop() async {
    _menuTimer?.cancel();
    if (_menuListening) {
      _menuListening = false;
      await _menuChannel.invokeMethod<void>('stop');
      _onListening?.call(false);
    }
    if (_speech.isListening) {
      await _speech.stop();
    }
  }
}
