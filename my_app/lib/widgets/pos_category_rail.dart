import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../theme/pos_theme.dart';
import '../utils/media_url.dart';
import '../utils/pos_layout.dart';

class PosCategoryRail extends StatelessWidget {
  const PosCategoryRail({
    super.key,
    required this.categories,
    required this.activeCategoryId,
    required this.onSelect,
    this.horizontal = false,
    this.searchActive = false,
    this.allItemsLabel,
    this.navLabel,
    this.accent,
    this.serverUrl,
    this.showImages = true,
  });

  final List<MenuCategory> categories;
  final int? activeCategoryId;
  final ValueChanged<int?> onSelect;
  final bool horizontal;
  final bool searchActive;
  final String? allItemsLabel;
  final String? navLabel;
  final Color? accent;
  final String? serverUrl;
  final bool showImages;

  void _select(int? id) {
    HapticFeedback.selectionClick();
    onSelect(id);
  }

  @override
  Widget build(BuildContext context) {
    final primary = accent ?? Theme.of(context).colorScheme.primary;
    final l10n = context.l10n;
    final resolvedAllItems = allItemsLabel ?? l10n.menuAllItems;
    final resolvedNav = navLabel ?? l10n.menuNavLabel;

    if (horizontal) {
      return Material(
        color: PosTheme.surface,
        child: Container(
          height: usePosHandheldLayout(context) ? 60 : 132,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: PosTheme.border)),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: usePosHandheldLayout(context) ? 6 : 10,
            ),
            itemCount: categories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CategoryChip(
                  label: resolvedAllItems,
                  isActive: !searchActive && activeCategoryId == null,
                  accent: primary,
                  onTap: () => _select(null),
                  icon: Icons.apps_rounded,
                );
              }

              final category = categories[index - 1];
              final lang = Localizations.localeOf(context).languageCode;
              return _CategoryChip(
                label: category.localizedName(lang),
                isActive: !searchActive && category.id == activeCategoryId,
                accent: primary,
                onTap: () => _select(category.id),
                imageUrl: showImages
                    ? resolveMediaUrl(category.imageUrl, serverUrl: serverUrl)
                    : null,
              );
            },
          ),
        ),
      );
    }

    return Material(
      color: PosTheme.surface,
      child: Container(
        width: usePosHandheldLayout(context)
            ? (MediaQuery.sizeOf(context).width < 400 ? 84 : 104)
            : 128,
        decoration: BoxDecoration(
          color: PosTheme.surface,
          border: Border(right: BorderSide(color: PosTheme.border)),
          boxShadow: [
            BoxShadow(
              color: PosTheme.ink.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      resolvedNav.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: PosTheme.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                children: [
                  _CategoryTile(
                    label: resolvedAllItems,
                    isActive: !searchActive && activeCategoryId == null,
                    accent: primary,
                    onTap: () => _select(null),
                    icon: Icons.apps_rounded,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: PosTheme.border.withValues(alpha: 0.9),
                    ),
                  ),
                  ...categories.map((category) {
                    final lang = Localizations.localeOf(context).languageCode;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CategoryTile(
                        label: category.localizedName(lang),
                        isActive:
                            !searchActive && category.id == activeCategoryId,
                        accent: primary,
                        onTap: () => _select(category.id),
                        imageUrl: showImages
                            ? resolveMediaUrl(
                                category.imageUrl,
                                serverUrl: serverUrl,
                              )
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical rail item — image/icon stack + label with active accent rail.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.isActive,
    required this.accent,
    required this.onTap,
    this.imageUrl,
    this.icon,
  });

  final String label;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;
  final String? imageUrl;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final soft = accent.withValues(alpha: isActive ? 0.12 : 0.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? accent.withValues(alpha: 0.22)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CategoryAvatar(
                imageUrl: imageUrl,
                icon: icon,
                isActive: isActive,
                accent: accent,
                size: usePosHandheldLayout(context) ? 32 : 52,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: usePosHandheldLayout(context) ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  height: 1.15,
                  letterSpacing: -0.1,
                  color: isActive ? accent : PosTheme.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal compact chip for phone layout.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.accent,
    required this.onTap,
    this.imageUrl,
    this.icon,
  });

  final String label;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;
  final String? imageUrl;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    if (usePosHandheldLayout(context)) {
      return Material(
        color: isActive ? soft.bg : PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? accent.withValues(alpha: 0.4)
                    : PosTheme.border,
              ),
            ),
            child: Row(
              children: [
                _CategoryAvatar(
                  imageUrl: imageUrl,
                  icon: icon,
                  isActive: isActive,
                  accent: accent,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive ? soft.fg : PosTheme.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 112,
          height: 112,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: isActive
                  ? soft.bg
                  : PosTheme.surfaceMuted.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? soft.fg.withValues(alpha: 0.28)
                    : PosTheme.border.withValues(alpha: 0.8),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _CategoryAvatar(
                  imageUrl: imageUrl,
                  icon: icon,
                  isActive: isActive,
                  accent: accent,
                  size: 52,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      height: 1.15,
                      letterSpacing: -0.1,
                      color: isActive ? soft.fg : PosTheme.inkMuted,
                    ),
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

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({
    required this.isActive,
    required this.accent,
    required this.size,
    this.imageUrl,
    this.icon,
  });

  final String? imageUrl;
  final IconData? icon;
  final bool isActive;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final radius = size * 0.28;
    final cachePx = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      padding: EdgeInsets.all(isActive ? 2.5 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius + (isActive ? 2.5 : 0)),
        gradient: isActive
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
              )
            : null,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: isActive ? PosTheme.surface : PosTheme.surfaceMuted,
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: size,
                  height: size,
                  memCacheWidth: cachePx,
                  memCacheHeight: cachePx,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 160),
                  placeholder: (_, _) => _glyph(size, accent, isActive),
                  errorWidget: (_, _, _) => _glyph(size, accent, isActive),
                )
              : _glyph(size, accent, isActive),
        ),
      ),
    );
  }

  Widget _glyph(double size, Color accent, bool isActive) {
    final soft = posAccentSoft(accent);
    return ColoredBox(
      color: isActive ? soft.bg : PosTheme.surfaceMuted,
      child: Center(
        child: Icon(
          icon ?? Icons.restaurant_rounded,
          size: size >= 48 ? 22 : 18,
          color: isActive ? soft.fg : PosTheme.inkFaint,
        ),
      ),
    );
  }
}
