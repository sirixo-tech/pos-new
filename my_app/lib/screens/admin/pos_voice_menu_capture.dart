import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/pos_speech.dart';
import '../../services/voice_menu_parser.dart';
import '../../widgets/pos_listening_bars.dart';

class SpokenMenuResult {
  const SpokenMenuResult({this.csv, this.message});

  final Uint8List? csv;
  final String? message;
}

/// Starts listening immediately and shows the listening card until the menu is spoken.
Future<SpokenMenuResult> captureSpokenMenu(BuildContext context) {
  final completer = Completer<SpokenMenuResult>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SpokenMenuOverlay(
      onDone: (result) {
        if (completer.isCompleted) return;
        entry.remove();
        completer.complete(result);
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return completer.future;
}

class _SpokenMenuOverlay extends StatefulWidget {
  const _SpokenMenuOverlay({required this.onDone});

  final ValueChanged<SpokenMenuResult> onDone;

  @override
  State<_SpokenMenuOverlay> createState() => _SpokenMenuOverlayState();
}

class _SpokenMenuOverlayState extends State<_SpokenMenuOverlay> {
  String _transcript = '';
  final String _hint = 'Listening for the menu';
  String? _notice;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    if (!_closed) PosSpeech.instance.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    final started = await PosSpeech.instance.listen(
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      onListening: (_) {},
      onError: (_) => _noticeOnly(
        'Allow the microphone and speech recognition, then try again.',
      ),
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() => _transcript = words);
        if (isFinal) _finishFromTranscript();
      },
    );
    if (!started) {
      _noticeOnly('Allow the microphone and speech recognition, then try again.');
    }
  }

  void _noticeOnly(String message) {
    PosSpeech.instance.stop();
    if (!mounted) {
      _finish(const SpokenMenuResult());
      return;
    }
    setState(() => _notice = message);
  }

  void _finishFromTranscript() {
    if (_notice != null) {
      _finish(const SpokenMenuResult());
      return;
    }
    final lines = parseVoiceMenu(_transcript);
    final ready = lines.where((line) => line.isReady).toList();
    if (lines.isEmpty || ready.length != lines.length) {
      _noticeOnly('Say each item, then its price.');
      return;
    }
    _finish(SpokenMenuResult(csv: voiceMenuCsv(ready)));
  }

  void _finish(SpokenMenuResult result) {
    if (_closed) return;
    _closed = true;
    PosSpeech.instance.stop();
    widget.onDone(result);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _notice == null
              ? PosListeningStatus(
                  transcript: _transcript,
                  hint: _hint,
                  onStop: _finishFromTranscript,
                )
              : Material(
                  color: Colors.white,
                  elevation: 10,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      children: [
                        const Icon(Icons.mic_off_rounded, color: Color(0xFFB42318)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _notice!,
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => _finish(const SpokenMenuResult()),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Speaks menu items, then sends a CSV through the existing AI menu import.
class PosVoiceMenuCapture extends StatefulWidget {
  const PosVoiceMenuCapture({
    super.key,
    required this.busy,
    required this.onSubmit,
    this.onChangeSource,
  });

  final bool busy;
  final Future<void> Function(Uint8List csv) onSubmit;
  final VoidCallback? onChangeSource;

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
    final ready = lines.where((line) => line.isReady).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.mic_none_rounded, color: Color(0xFFC2410C)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Say the menu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (widget.onChangeSource != null)
                _VoiceChangeButton(
                  onPressed: widget.busy || _sending ? null : widget.onChangeSource,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Example: “Cappuccino 120, Latte 140 in Hot drinks.”',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Material(
                  color: _listening ? const Color(0xFFC2410C) : accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.busy || _sending ? null : _toggle,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Icon(
                        _listening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _listening ? 'Listening… tap to stop' : 'Tap and speak',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          if (_listening) ...[
            const SizedBox(height: 14),
            PosListeningStatus(
              transcript: _transcript,
              hint: 'Listening for menu items',
              onStop: _toggle,
            ),
          ],
          if (_transcript.isNotEmpty && !_listening) ...[
            const SizedBox(height: 14),
            Text(
              _transcript,
              style: const TextStyle(height: 1.4, color: Color(0xFF334155)),
            ),
          ],
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              ready == lines.length
                  ? '${lines.length} items ready'
                  : '$ready of ${lines.length} items have a price',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      line.category,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _lineLabel(line).split(' · ').last,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: line.isReady
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: widget.busy || _sending ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send for review'),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Say the item, then the price. You confirm prices before saving.',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF64748B)),
          ),
          if (_unavailable) ...[
            const SizedBox(height: 8),
            const Text(
              'Allow the microphone, then tap and speak again.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFFC2410C)),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF475569)),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceChangeButton extends StatelessWidget {
  const _VoiceChangeButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(84, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Change',
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      ),
    );
  }
}
