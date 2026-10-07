import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_codec;
import 'package:image_picker/image_picker.dart';

import '../../services/customer_display/dqr222_customer_display_service.dart';
import '../../services/customer_display/dqr222_media_protocol.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_ui.dart';

/// Change the idle slides stored on the connected DQR display.
class Dqr222AdvertisementPage extends StatefulWidget {
  const Dqr222AdvertisementPage({super.key});

  @override
  State<Dqr222AdvertisementPage> createState() =>
      _Dqr222AdvertisementPageState();
}

class _Dqr222AdvertisementPageState extends State<Dqr222AdvertisementPage> {
  final _nameController = TextEditingController();
  List<Dqr222AdvertisementImage> _images = const [];
  List<Dqr222AdvertisementImage> _audioFiles = const [];
  String? _audioError;
  Uint8List? _bytes;
  String? _detail;
  String? _replacing;
  Uint8List? _audioBytes;
  String? _audioSlot;
  String? _audioDetail;
  String? _message;
  bool _messageIsError = false;
  bool _loading = true;
  bool _busy = false;
  final AudioPlayer _preview = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _preview.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _message = null;
      _audioError = null;
    });
    Object? imageError;
    Object? audioError;
    List<Dqr222AdvertisementImage>? images;
    List<Dqr222AdvertisementImage>? audio;
    try {
      images = await getDqr222AdvertisementImages();
    } catch (error) {
      imageError = error;
    }
    try {
      audio = await getDqr222AdvertisementImages(
        kind: Dqr222MediaKind.audio,
      );
    } catch (error) {
      audioError = error;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (images != null) _images = images;
      if (audio != null) _audioFiles = audio;
      _audioError = audioError == null ? null : _errorText(audioError);
      if (imageError != null) {
        _message = _errorText(imageError);
        _messageIsError = true;
      }
    });
  }

  Future<void> _pick({String? replaceName}) async {
    if (_busy) return;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length >= dqr222AdvertisementSizeLimit) {
        throw const FormatException(
          'Advertisement JPEG must be under 100 KB (100,000 bytes).',
        );
      }
      if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
        throw const FormatException('Select a JPEG image.');
      }
      final decoded = image_codec.decodeJpg(bytes);
      if (decoded == null) {
        throw const FormatException('The selected JPEG cannot be decoded.');
      }
      if (decoded.width != 320 || decoded.height != 480) {
        throw FormatException(
          'Use a 320 × 480 portrait JPEG. This one is '
          '${decoded.width} × ${decoded.height}.',
        );
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _replacing = replaceName;
        _detail = '320 × 480 · ${_formatBytes(bytes.length)}';
        _nameController.text = replaceName ?? _suggestName(file.name);
        _message = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _errorText(error);
        _messageIsError = true;
      });
    }
  }

  String _suggestName(String selectedName) {
    final normalized = selectedName.trim().replaceFirst(
      RegExp(r'\.jpg$', caseSensitive: false),
      '.jpeg',
    );
    try {
      final name = normalizeDqr222AdvertisementFileName(normalized);
      final taken = _images.any(
        (image) => image.fileName.toLowerCase() == name.toLowerCase(),
      );
      if (!taken) return name;
    } on FormatException {
      // Fall through to the next free number.
    }
    var next = 1;
    for (final image in _images) {
      final number = int.tryParse(image.fileName.split('.').first);
      if (number != null && number >= next) next = number + 1;
    }
    return '$next.jpeg';
  }

  Future<void> _upload() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final fileName = _nameController.text.trim();
    setState(() {
      _busy = true;
      _message = 'Saving $fileName on the display. Keep it connected.';
      _messageIsError = false;
    });
    try {
      final result = await uploadDqr222AdvertisementImage(
        filePath: fileName,
        fileName: fileName,
        fileBytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _detail = null;
        _replacing = null;
        _nameController.clear();
        _busy = false;
        _message = result.replacedExisting
            ? '${result.fileName} replaced. The display will show it in the idle rotation.'
            : '${result.fileName} added. It joins the idle rotation with the other slides.';
        _messageIsError = false;
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _errorText(error);
        _messageIsError = true;
      });
    }
  }

  Future<void> _delete(Dqr222AdvertisementImage image) async {
    final ok = await showPosConfirmDialog(
      context,
      title: 'Remove this slide?',
      message:
          '${image.fileName} will be deleted from the display. The other slides stay. '
          'Keep a copy of the JPEG if you may want it back.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _message = 'Removing ${image.fileName}…';
      _messageIsError = false;
    });
    try {
      final images = await deleteDqr222AdvertisementImage(image.fileName);
      if (!mounted) return;
      setState(() {
        _images = images;
        _busy = false;
        _message =
            '${image.fileName} removed. The remaining slides keep rotating.';
        _messageIsError = false;
        if (_replacing == image.fileName) {
          _bytes = null;
          _replacing = null;
          _detail = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _errorText(error);
        _messageIsError = true;
      });
    }
  }

  Future<void> _pickAudio(String slot) async {
    if (_busy) return;
    if (!dqr222AudioSlots.containsKey(slot)) return;
    try {
      const group = XTypeGroup(
        label: 'MP3 audio',
        extensions: ['mp3'],
        mimeTypes: ['audio/mpeg', 'audio/mp3'],
      );
      final file = await openFile(acceptedTypeGroups: [group]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!looksLikeDqr222Mp3(bytes)) {
        throw const FormatException('Select an MP3 audio file.');
      }
      if (bytes.length > 1966080) {
        throw const FormatException(
          'Audio must be 1,966,080 bytes or smaller.',
        );
      }
      await _preview.stop();
      if (!mounted) return;
      setState(() {
        _audioBytes = bytes;
        _audioSlot = slot;
        _audioDetail = _formatBytes(bytes.length);
        _bytes = null;
        _detail = null;
        _replacing = null;
        _message = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _errorText(error);
        _messageIsError = true;
      });
    }
  }

  Future<void> _previewPickedAudio() async {
    final bytes = _audioBytes;
    if (bytes == null || _busy) return;
    try {
      await _preview.stop();
      await _preview.play(BytesSource(bytes));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _errorText(error);
        _messageIsError = true;
      });
    }
  }

  Future<void> _playOnDevice(String fileName) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = 'Playing $fileName on the display speaker…';
      _messageIsError = false;
    });
    try {
      await playDqr222Audio(fileName);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '$fileName is playing on the display.';
        _messageIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _errorText(error);
        _messageIsError = true;
      });
    }
  }

  Future<void> _uploadAudio() async {
    final bytes = _audioBytes;
    final slot = _audioSlot;
    if (bytes == null || slot == null) return;
    setState(() {
      _busy = true;
      _message = 'Saving $slot on the display. Keep it connected.';
      _messageIsError = false;
    });
    try {
      await _preview.stop();
      final result = await uploadDqr222AdvertisementImage(
        filePath: slot,
        fileName: slot,
        fileBytes: bytes,
        kind: Dqr222MediaKind.audio,
      );
      if (!mounted) return;
      setState(() {
        _audioBytes = null;
        _audioSlot = null;
        _audioDetail = null;
        _busy = false;
        _message = result.replacedExisting
            ? '${dqr222AudioSlots[slot] ?? slot} replaced on the display.'
            : '${dqr222AudioSlots[slot] ?? slot} saved on the display.';
        _messageIsError = false;
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _errorText(error);
        _messageIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('DQR images'),
        actions: [
          IconButton(
            tooltip: 'Read images and audio from the display',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final audio = _AudioList(
            rows: _deviceAudioRows(_audioFiles),
            loading: _loading,
            busy: _busy,
            error: _audioError,
            replacing: _audioSlot,
            onListen: _playOnDevice,
            onReplace: _pickAudio,
          );
          final list = _ImageList(
            images: _images,
            loading: _loading,
            busy: _busy,
            replacing: _replacing,
            accent: accent,
            onReplace: (name) => _pick(replaceName: name),
            onDelete: _delete,
            onAdd: () => _pick(),
          );
          final side = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HowItWorksCard(),
              const SizedBox(height: 12),
              _ComposerCard(
                bytes: _bytes,
                detail: _detail,
                replacing: _replacing,
                nameController: _nameController,
                busy: _busy,
                onClear: () => setState(() {
                  _bytes = null;
                  _detail = null;
                  _replacing = null;
                  _nameController.clear();
                }),
                onSave: _bytes == null || _busy ? null : _upload,
              ),
              if (_audioSlot != null) ...[
                const SizedBox(height: 12),
                _AudioComposerCard(
                  slot: _audioSlot!,
                  detail: _audioDetail,
                  busy: _busy,
                  onListen: _previewPickedAudio,
                  onClear: () => setState(() {
                    _audioBytes = null;
                    _audioSlot = null;
                    _audioDetail = null;
                    _preview.stop();
                  }),
                  onSave: _audioBytes == null || _busy ? null : _uploadAudio,
                ),
              ],
            ],
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              if (_message != null) ...[
                _StatusBanner(message: _message!, error: _messageIsError),
                const SizedBox(height: 12),
              ],
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          list,
                          const SizedBox(height: 16),
                          audio,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: side),
                  ],
                )
              else ...[
                side,
                const SizedBox(height: 16),
                list,
                const SizedBox(height: 16),
                audio,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How these images change',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The DQR keeps the slides on the display itself. When it is idle — '
            'not showing the cart or a payment QR — it plays every JPEG stored '
            'there, one after another, about every 5 seconds.',
            style: TextStyle(color: PosTheme.inkMuted, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            'This screen reads that list. There is no fixed number of slides. '
            'If the display has 3 images you will see 3. If it has 8 you will see 8. '
            'Every image in the list can be replaced or removed.',
            style: TextStyle(color: PosTheme.inkMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          const _Step(n: '1', text: 'Tap Replace on the slide you want to change.'),
          const _Step(
            n: '2',
            text: 'Choose a portrait JPEG that is exactly 320 × 480 pixels and under 100 KB.',
          ),
          const _Step(
            n: '3',
            text: 'Tap Save to display. The new picture is written over the same file name, so only that slide changes.',
          ),
          const _Step(
            n: '4',
            text: 'When the display is idle again, that new picture is in the rotation. Cart and payment screens are not replaced by these slides.',
          ),
          const SizedBox(height: 8),
          Text(
            'Add image creates a new slide. Remove deletes only that file. '
            'Keep the cable connected until the success message, and wait until a payment QR has finished. '
            'Audio below is read from the same display. Listen plays it on the display speaker. Replace writes a new MP3 over that sound.',
            style: TextStyle(color: PosTheme.inkMuted, height: 1.4, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: PosTheme.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageList extends StatelessWidget {
  const _ImageList({
    required this.images,
    required this.loading,
    required this.busy,
    required this.replacing,
    required this.accent,
    required this.onReplace,
    required this.onDelete,
    required this.onAdd,
  });

  final List<Dqr222AdvertisementImage> images;
  final bool loading;
  final bool busy;
  final String? replacing;
  final Color accent;
  final ValueChanged<String> onReplace;
  final ValueChanged<Dqr222AdvertisementImage> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'On this display',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loading
                          ? 'Reading the display…'
                          : images.isEmpty
                              ? 'No slides stored yet'
                              : '${images.length} slide${images.length == 1 ? '' : 's'} in the idle rotation',
                      style: TextStyle(color: PosTheme.inkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: busy ? null : onAdd,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Add image'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (images.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 18),
              child: Text(
                'Nothing is stored yet. Add a 320 × 480 JPEG and it becomes the first idle slide.',
                style: TextStyle(color: PosTheme.inkMuted, height: 1.4),
              ),
            )
          else
            for (var i = 0; i < images.length; i++)
              _ImageRow(
                index: i + 1,
                image: images[i],
                selected: replacing == images[i].fileName,
                busy: busy,
                accent: accent,
                onReplace: () => onReplace(images[i].fileName),
                onDelete: () => onDelete(images[i]),
              ),
        ],
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({
    required this.index,
    required this.image,
    required this.selected,
    required this.busy,
    required this.accent,
    required this.onReplace,
    required this.onDelete,
  });

  final int index;
  final Dqr222AdvertisementImage image;
  final bool selected;
  final bool busy;
  final Color accent;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.08) : PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.45) : PosTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PosTheme.border),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: PosTheme.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  image.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PosTheme.ink,
                  ),
                ),
                Text(
                  _formatBytes(image.size),
                  style: TextStyle(fontSize: 12, color: PosTheme.inkMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onReplace,
            child: const Text('Replace'),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.bytes,
    required this.detail,
    required this.replacing,
    required this.nameController,
    required this.busy,
    required this.onClear,
    required this.onSave,
  });

  final Uint8List? bytes;
  final String? detail;
  final String? replacing;
  final TextEditingController nameController;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final picked = bytes != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            replacing == null ? 'New slide' : 'Replace $replacing',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            picked
                ? (replacing == null
                    ? 'This file will be added. The slides already on the display stay.'
                    : 'This file will overwrite $replacing. The other slides stay.')
                : 'Choose Replace on a slide, or Add image, to pick a JPEG.',
            style: TextStyle(color: PosTheme.inkMuted, height: 1.35),
          ),
          if (picked) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: PosTheme.surfaceMuted,
                child: SizedBox(
                  height: 220,
                  child: Image.memory(bytes!, fit: BoxFit.contain),
                ),
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(detail!, style: TextStyle(color: PosTheme.inkMuted)),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              enabled: replacing == null && !busy,
              decoration: InputDecoration(
                labelText: 'File name on the display',
                helperText: replacing == null
                    ? 'Use a simple name such as 4.jpeg'
                    : 'The name stays the same so this slide is replaced',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSave,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded),
                    label: const Text('Save to display'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: busy ? null : onClear,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFB91C1C) : const Color(0xFF047857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, height: 1.35),
      ),
    );
  }
}

class _DeviceAudio {
  const _DeviceAudio({
    required this.fileName,
    required this.label,
    this.size,
    this.onDeviceName,
  });

  final String fileName;
  final String label;
  final int? size;
  final String? onDeviceName;

  bool get present => size != null;
  bool get canReplace => dqr222AudioSlots.containsKey(fileName);
}

List<_DeviceAudio> _deviceAudioRows(List<Dqr222AdvertisementImage> files) {
  final used = <String>{};
  final rows = <_DeviceAudio>[];
  for (final slot in dqr222AudioSlots.entries) {
    Dqr222AdvertisementImage? match;
    for (final file in files) {
      if (file.fileName.toLowerCase() == slot.key.toLowerCase()) {
        match = file;
        break;
      }
    }
    if (match != null) used.add(match.fileName.toLowerCase());
    rows.add(
      _DeviceAudio(
        fileName: slot.key,
        label: slot.value,
        size: match?.size,
        onDeviceName: match?.fileName,
      ),
    );
  }
  for (final file in files) {
    if (used.contains(file.fileName.toLowerCase())) continue;
    rows.add(
      _DeviceAudio(
        fileName: file.fileName,
        label: 'Stored on the display',
        size: file.size,
        onDeviceName: file.fileName,
      ),
    );
  }
  return rows;
}

class _AudioList extends StatelessWidget {
  const _AudioList({
    required this.rows,
    required this.loading,
    required this.busy,
    required this.error,
    required this.replacing,
    required this.onListen,
    required this.onReplace,
  });

  final List<_DeviceAudio> rows;
  final bool loading;
  final bool busy;
  final String? error;
  final String? replacing;
  final ValueChanged<String> onListen;
  final ValueChanged<String> onReplace;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final present = rows.where((row) => row.present).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Audio on this display',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            loading
                ? 'Reading audio from the display…'
                : error != null
                    ? error!
                    : '$present sound${present == 1 ? '' : 's'} stored on the display',
            style: TextStyle(
              color: error == null ? PosTheme.inkMuted : const Color(0xFFB91C1C),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final row in rows)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                decoration: BoxDecoration(
                  color: replacing == row.fileName
                      ? accent.withValues(alpha: 0.08)
                      : PosTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: replacing == row.fileName
                        ? accent.withValues(alpha: 0.45)
                        : PosTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      color: row.present ? accent : PosTheme.inkFaint,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: PosTheme.ink,
                            ),
                          ),
                          Text(
                            row.present
                                ? '${row.onDeviceName} · ${_formatBytes(row.size!)}'
                                : 'Not on this display',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: PosTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: busy || !row.present
                          ? null
                          : () => onListen(row.onDeviceName ?? row.fileName),
                      child: const Text('Listen'),
                    ),
                    if (row.canReplace)
                      TextButton(
                        onPressed: busy ? null : () => onReplace(row.fileName),
                        child: Text(row.present ? 'Replace' : 'Add'),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AudioComposerCard extends StatelessWidget {
  const _AudioComposerCard({
    required this.slot,
    required this.detail,
    required this.busy,
    required this.onListen,
    required this.onClear,
    required this.onSave,
  });

  final String slot;
  final String? detail;
  final bool busy;
  final VoidCallback onListen;
  final VoidCallback onClear;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final label = dqr222AudioSlots[slot] ?? slot;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Replace $label',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This MP3 will overwrite $slot. The other sounds stay. '
            'Listen here plays it on this device before it is saved.',
            style: TextStyle(color: PosTheme.inkMuted, height: 1.35),
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text('$slot · $detail', style: TextStyle(color: PosTheme.ink)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_rounded),
                  label: const Text('Save to display'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: busy ? null : onListen,
                child: const Text('Listen'),
              ),
              TextButton(
                onPressed: busy ? null : onClear,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

String _errorText(Object error) {
  var text = error.toString();
  for (final prefix in [
    'Exception: ',
    'FormatException: ',
    'Bad state: ',
    'Invalid argument(s): ',
  ]) {
    if (text.startsWith(prefix)) text = text.substring(prefix.length);
  }
  return text;
}
