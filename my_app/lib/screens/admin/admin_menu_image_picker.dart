import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/pos_l10n.dart';
import '../../theme/pos_theme.dart';

class AdminMenuImagePickerSection extends StatelessWidget {
  const AdminMenuImagePickerSection({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.pickedImage,
    required this.picking,
    required this.onPick,
    this.onGenerate,
    this.placeholderIcon = Icons.restaurant_rounded,
    this.compactPreview = false,
  });

  final String label;
  final String? imageUrl;
  final XFile? pickedImage;
  final bool picking;
  final VoidCallback onPick;
  final VoidCallback? onGenerate;
  final IconData placeholderIcon;
  final bool compactPreview;

  static Future<XFile?> pickFromGallery() {
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: PosTheme.ink,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context);
              final availableHeight =
                  media.size.height - media.viewInsets.bottom;
              final height = compactPreview
                  ? (availableHeight * 0.22).clamp(100.0, 180.0)
                  : constraints.maxWidth * 3 / 4;
              return SizedBox(
                height: height,
                width: double.infinity,
                child: _buildPreview(context),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: picking ? null : onPick,
                icon: picking && onGenerate == null
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_outlined, size: 18),
                label: Text(
                  pickedImage != null
                      ? context.posText('adminChangePhoto', 'Change photo')
                      : context.posText('adminUpdatePhoto', 'Update photo'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (onGenerate != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: picking ? null : onGenerate,
                  icon: picking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text(
                    'Generate with AI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (pickedImage != null) {
      return FutureBuilder<Uint8List>(
        future: pickedImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return ColoredBox(
              color: PosTheme.surfaceMuted,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        },
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => ColoredBox(
          color: PosTheme.surfaceMuted,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, _, _) => _placeholder(context),
      );
    }

    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: PosTheme.surfaceMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(placeholderIcon, size: 40, color: PosTheme.inkFaint),
          const SizedBox(height: 8),
          Text(
            context.posText('adminNoPhotoYet', 'No photo yet'),
            style: TextStyle(color: PosTheme.inkMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Small square thumbnail for list rows.
class AdminMenuThumb extends StatelessWidget {
  const AdminMenuThumb({
    super.key,
    this.imageUrl,
    this.size = 44,
    this.icon = Icons.restaurant_rounded,
  });

  final String? imageUrl;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.border),
        color: PosTheme.surfaceMuted,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  Icon(icon, size: size * 0.42, color: PosTheme.inkFaint),
              errorWidget: (_, _, _) =>
                  Icon(icon, size: size * 0.42, color: PosTheme.inkFaint),
            )
          : Icon(icon, size: size * 0.42, color: PosTheme.inkFaint),
    );
  }
}
