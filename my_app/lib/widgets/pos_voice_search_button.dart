import 'package:flutter/material.dart';

import 'package:speech_to_text/speech_to_text.dart';

import '../services/pos_speech.dart';
import '../theme/pos_theme.dart';
import 'pos_listening_bars.dart';

/// Mic for the POS item search. Spoken words become the search text.
class PosVoiceSearchButton extends StatefulWidget {
  const PosVoiceSearchButton({
    super.key,
    required this.onText,
    this.onListening,
    this.onBindStop,
  });

  final ValueChanged<String> onText;
  final void Function(bool listening, String transcript)? onListening;
  final void Function(Future<void> Function() stop)? onBindStop;

  @override
  State<PosVoiceSearchButton> createState() => _PosVoiceSearchButtonState();
}

class _PosVoiceSearchButtonState extends State<PosVoiceSearchButton> {
  var _listening = false;

  void _setListening(bool listening, [String transcript = '']) {
    if (mounted) setState(() => _listening = listening);
    widget.onListening?.call(listening, transcript);
  }

  Future<void> _toggle() async {
    if (_listening) {
      await PosSpeech.instance.stop();
      _setListening(false);
      return;
    }
    _setListening(true);
    final started = await PosSpeech.instance.listen(
      mode: ListenMode.search,
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(milliseconds: 1200),
      onResult: (words, isFinal) {
        final text = words.trim().replaceAll(RegExp(r'[.!?]+$'), '');
        if (text.isEmpty) return;
        widget.onText(text);
        widget.onListening?.call(true, text);
        if (isFinal) _setListening(false, text);
      },
    );
    if (!started) _setListening(false);
  }

  @override
  void dispose() {
    if (_listening) {
      PosSpeech.instance.stop();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.onBindStop?.call(_toggle);
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
