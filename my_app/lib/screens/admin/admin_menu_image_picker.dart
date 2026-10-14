import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/pos_l10n.dart';
import '../../theme/pos_theme.dart';
import 'admin_photo_camera.dart';

class AdminMenuImagePickerSection extends StatelessWidget {
  const AdminMenuImagePickerSection({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.pickedImage,
    required this.picking,
    required this.onPick,
    this.onCamera,
    this.onGenerate,
    this.placeholderIcon = Icons.restaurant_rounded,
    this.compactPreview = false,
  });

  final String label;
  final String? imageUrl;
  final XFile? pickedImage;
  final bool picking;
  final VoidCallback onPick;
  final VoidCallback? onCamera;
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

  static Future<XFile?> pickFromCamera(BuildContext context) =>
      showAdminPhotoCamera(context);

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
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context);
              final availableHeight =
                  media.size.height - media.viewInsets.bottom;
              final height = compactPreview
                  ? (availableHeight * 0.22).clamp(130.0, 190.0)
                  : constraints.maxWidth * 3 / 4;
              return Container(
                height: height,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PosTheme.border),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPreview(context),
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: PosTheme.surface.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: PosTheme.border.withValues(alpha: 0.8),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ImageActionButton(
                                icon: Icons.photo_library_outlined,
                                label: pickedImage != null
                                    ? context.posText(
                                        'adminChangePhoto',
                                        'Change photo',
                                      )
                                    : context.posText(
                                        'adminUpdatePhoto',
                                        'Update photo',
                                      ),
                                fallbackLabel: 'Update photo',
                                loading: picking && onGenerate == null,
                                onTap: picking ? null : onPick,
                              ),
                              if (onCamera != null) ...[
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: PosTheme.border.withValues(alpha: 0.6),
                                ),
                                _ImageActionButton(
                                  icon: Icons.camera_alt_outlined,
                                  label: 'Take photo',
                                  onTap: picking ? null : onCamera,
                                ),
                              ],
                              if (onGenerate != null) ...[
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: PosTheme.border.withValues(alpha: 0.6),
                                ),
                                _ImageActionButton(
                                  icon: Icons.auto_awesome_rounded,
                                  label: 'Generate with AI',
                                  color: const Color(0xFFFF6900),
                                  loading: picking && onGenerate != null,
                                  onTap: picking ? null : onGenerate,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
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
          Icon(placeholderIcon, size: 36, color: PosTheme.inkFaint),
          const SizedBox(height: 6),
          Text(
            context.posText('adminNoPhotoYet', 'No photo yet'),
            style: TextStyle(color: PosTheme.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.icon,
    required this.label,
    this.fallbackLabel,
    required this.onTap,
    this.color,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final String? fallbackLabel;
  final VoidCallback? onTap;
  final Color? color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? PosTheme.ink;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                if (fallbackLabel != null && fallbackLabel != label)
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        fallbackLabel!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: effectiveColor,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 20,
                          color: onTap == null
                              ? PosTheme.inkFaint
                              : effectiveColor,
                        ),
                ),
              ],
            ),
          ),
        ),
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
