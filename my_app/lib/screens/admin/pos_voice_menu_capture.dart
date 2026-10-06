import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/pos_speech.dart';
import '../../services/voice_menu_parser.dart';
import '../../widgets/pos_listening_bars.dart';

/// Speaks menu items, then sends a CSV through the existing AI menu import.
class PosVoiceMenuCapture extends StatefulWidget {
  const PosVoiceMenuCapture({
    super.key,
    required this.busy,
    required this.onSubmit,
  });

  final bool busy;
  final Future<void> Function(Uint8List csv) onSubmit;

  @override
  State<PosVoiceMenuCapture> createState() => _PosVoiceMenuCaptureState();
}

class _PosVoiceMenuCaptureState extends State<PosVoiceMenuCapture> {
  var _listening = false;
  var _unavailable = false;
  var _sending = false;
  String _transcript = '';
  String? _message;

  @override
  void dispose() {
    if (_listening) PosSpeech.instance.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.busy || _sending) return;
    if (_listening) {
      await PosSpeech.instance.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() {
      _message = null;
      _unavailable = false;
      _listening = true;
    });
    final started = await PosSpeech.instance.listen(
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      onListening: (listening) {
        if (mounted) setState(() => _listening = listening);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _message =
              'Could not recognize speech. Check microphone permission '
              'and speech recognition settings, then try again.';
        });
      },
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _transcript = words;
          if (isFinal) _listening = false;
        });
      },
    );
    if (!mounted) return;
    if (!started) {
      setState(() {
        _listening = false;
        _unavailable = true;
      });
    }
  }

  Future<void> _submit() async {
    final lines = parseVoiceMenu(_transcript);
    if (lines.isEmpty) {
      setState(() => _message = 'Say at least one item and its price.');
      return;
    }
    final missing = lines.where((line) => !line.isReady).length;
    if (missing > 0) {
      setState(
        () => _message = missing == 1
            ? 'One item is missing a price.'
            : '$missing items are missing a price.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      await widget.onSubmit(voiceMenuCsv(lines));
      if (!mounted) return;
      setState(() {
        _transcript = '';
        _message = 'Sent to AI menu review.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _lineLabel(VoiceMenuLine line) {
    final price = line.price;
    final amount = price == null
        ? 'price needed'
        : price.toStringAsFixed(price % 1 == 0 ? 0 : 2);
    return '${line.name} · ${line.category} · $amount';
  }

  @override
  Widget build(BuildContext context) {
    final lines = parseVoiceMenu(_transcript);
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Speak the items',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF12253E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Say the item, then the price. Name the category when you want it grouped.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF71839A),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Example: “Cappuccino 120, Latte 140 in Hot drinks.”',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF12253E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_listening) ...[
            PosListeningStatus(
              transcript: _transcript,
              hint: 'Listening for menu items',
              onStop: _toggle,
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: widget.busy || _sending ? null : _toggle,
            icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(_listening ? 'Stop listening' : 'Tap and speak'),
            style: FilledButton.styleFrom(
              backgroundColor: _listening ? const Color(0xFFB45309) : accent,
              minimumSize: const Size(0, 48),
            ),
          ),
          if (_transcript.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_transcript, style: const TextStyle(height: 1.35)),
          ],
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _lineLabel(line),
                  style: TextStyle(
                    fontSize: 13,
                    color: line.isReady
                        ? const Color(0xFF12253E)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.busy || _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Review these items'),
            ),
          ],
          if (_unavailable) ...[
            const SizedBox(height: 8),
            const Text(
              'Allow the microphone in the browser, then tap and speak again.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF71839A)),
            ),
          ],
        ],
      ),
    );
  }
}
