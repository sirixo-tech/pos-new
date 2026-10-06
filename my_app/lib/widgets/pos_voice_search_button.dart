import 'package:flutter/material.dart';

import 'package:speech_to_text/speech_to_text.dart';

import '../services/pos_speech.dart';
import '../services/menu_voice_matcher.dart';
import '../theme/pos_theme.dart';
import 'pos_listening_bars.dart';

/// Mic for the POS item search. Spoken words become the search text.
class PosVoiceSearchButton extends StatefulWidget {
  const PosVoiceSearchButton({
    super.key,
    required this.onText,
    this.onListening,
    this.onBindStop,
    this.speech,
    this.itemNames = const [],
  });

  final ValueChanged<String> onText;
  final void Function(bool listening, String transcript)? onListening;
  final void Function(Future<void> Function() stop)? onBindStop;
  final PosSpeech? speech;
  final List<String> itemNames;

  @override
  State<PosVoiceSearchButton> createState() => _PosVoiceSearchButtonState();
}

class _PosVoiceSearchButtonState extends State<PosVoiceSearchButton> {
  var _listening = false;
  String _transcript = '';
  PosSpeech get _speech => widget.speech ?? PosSpeech.instance;

  void _setListening(bool listening, [String transcript = '']) {
    if (!mounted) return;
    _transcript = transcript;
    setState(() => _listening = listening);
    widget.onListening?.call(listening, transcript);
  }

  Future<void> _stop() async {
    _setListening(false, _transcript);
    await _speech.stop();
  }

  void _showError(String message) {
    if (!mounted) return;
    _setListening(false, _transcript);
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _stop();
      return;
    }
    _setListening(true);
    if (widget.itemNames.isEmpty) {
      _showError('Load the menu before using voice search.');
      return;
    }
    final started = await _speech.listen(
      vocabulary: menuVoiceVocabulary(widget.itemNames),
      mode: ListenMode.search,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 5),
      onListening: (listening) {
        if (!mounted) return;
        _setListening(listening, _transcript);
      },
      onError: (error) => _showError(
        'Voice search could not recognize speech. Check microphone permission '
        'and the device speech language, then try again. ($error)',
      ),
      onResult: (words, isFinal) {
        if (!mounted) return;
        final text = matchMenuVoice(words, widget.itemNames);
        if (text == null) {
          if (isFinal) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text(
                  'No matching menu item heard. Say the item name again.',
                ),
              ),
            );
          }
          return;
        }
        if (isFinal) widget.onText(text);
        _setListening(!isFinal, text);
        if (isFinal) _speech.stop();
      },
    );
    if (!mounted) return;
    if (!started && _listening) {
      _showError(
        'Voice search is unavailable. Check microphone permission '
        'and speech recognition settings on this device.',
      );
    }
  }

  @override
  void dispose() {
    if (_listening) {
      _speech.stop();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.onBindStop?.call(_stop);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: _listening ? 'Stop voice search' : 'Search items by voice',
        child: Material(
          color: _listening
              ? accent.withValues(alpha: 0.14)
              : PosTheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 32,
              width: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _listening
                      ? accent.withValues(alpha: 0.45)
                      : PosTheme.border.withValues(alpha: 0.85),
                ),
              ),
              child: _listening
                  ? PosListeningBars(active: true, color: accent, height: 16)
                  : Icon(
                      Icons.mic_none_rounded,
                      size: 18,
                      color: PosTheme.inkMuted,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
