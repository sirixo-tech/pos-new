import 'dart:async';
import 'package:flutter/material.dart';

class MenuImportProgress extends StatefulWidget {
  const MenuImportProgress({
    super.key,
    required this.progress,
    required this.items,
    required this.filename,
    required this.publishing,
    required this.busy,
    required this.onRetry,
    required this.onCancel,
  });
  final num? progress;
  final int items;
  final String filename;
  final bool publishing, busy;
  final VoidCallback onRetry, onCancel;
  @override
  State<MenuImportProgress> createState() => _MenuImportProgressState();
}

class _MenuImportProgressState extends State<MenuImportProgress> {
  final _started = DateTime.now();
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF009C73);
    const muted = Color(0xFF71839A);
    final seconds = DateTime.now().difference(_started).inSeconds;
    final elapsed = '${seconds ~/ 60}m ${seconds % 60}s';
    final progress = widget.progress?.isFinite == true
        ? widget.progress!.clamp(0, 100)
        : null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E8F1)),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            color: const Color(0xFFF1FCF7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.document_scanner_outlined,
                      color: green,
                      size: 28,
                    ),
                    Text(
                      widget.publishing ? 'Publishing menu' : 'Reading menu',
                      style: const TextStyle(color: green),
                    ),
                    Text(
                      '${widget.items} items',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.publishing
                      ? 'Your menu is going live'
                      : 'AI is scanning your menu',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF12253E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.publishing
                            ? 'Publishing items'
                            : 'AI is reading your menu',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                    Text(
                      progress == null
                          ? 'Waiting for progress'
                          : '${progress.round()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    color: green,
                    backgroundColor: const Color(0xFFE1E8EF),
                    value: progress == null ? null : progress / 100,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Elapsed: $elapsed',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: green,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.publishing
                      ? 'Saving your menu items…'
                      : 'Extracting dishes and prices…',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF12253E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  seconds >= 120
                      ? 'This is taking longer than usual. We are still checking the server.'
                      : 'Extraction time varies with menu size and server load. Keep this screen open.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 18),
                ...List.generate(
                  3,
                  (i) => Container(
                    height: 32,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: widget.busy ? null : widget.onRetry,
                      icon: const Icon(Icons.refresh, size: 17),
                      label: const Text('Check status'),
                    ),
                    OutlinedButton(
                      onPressed: widget.busy ? null : widget.onCancel,
                      child: const Text('Discard draft'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
