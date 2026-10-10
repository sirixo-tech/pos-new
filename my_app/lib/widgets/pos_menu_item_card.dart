import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/media_url.dart';
import '../utils/pos_layout.dart';
import 'pos_item_type_badge.dart';

class PosMenuItemCard extends StatefulWidget {
  const PosMenuItemCard({
    super.key,
    required this.item,
    required this.currency,
    required this.onTap,
    this.accent,
    this.compact = false,
    this.inTicketQty = 0,
    this.simpleCartLine,
    this.onIncrementSimple,
    this.onDecrementSimple,
    this.serverUrl,
    this.showImage = true,
    this.handheld = false,
    this.photoGrid = false,
  });

  final MenuItem item;
  final String currency;
  final VoidCallback onTap;
  final Color? accent;
  final bool compact;
  final int inTicketQty;
  final CartLine? simpleCartLine;
  final ValueChanged<CartLine>? onIncrementSimple;
  final ValueChanged<CartLine>? onDecrementSimple;
  final String? serverUrl;
  final bool showImage;
  final bool handheld;
  final bool photoGrid;

  @override
  State<PosMenuItemCard> createState() => _PosMenuItemCardState();
}

class _PosMenuItemCardState extends State<PosMenuItemCard> {
  bool _imageFailed = false;

  @override
  void didUpdateWidget(covariant PosMenuItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imageUrl != widget.item.imageUrl ||
        oldWidget.serverUrl != widget.serverUrl) {
      _imageFailed = false;
    }
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(0, 2))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  double _minDisplayPrice() {
    if (widget.item.variants.isEmpty) return widget.item.price;
    var minPrice = widget.item.price;
    for (final variant in widget.item.variants) {
      if (variant.price < minPrice) minPrice = variant.price;
    }
    return minPrice;
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.accent ?? Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(primary);
    final inCart = widget.inTicketQty > 0;
    final showStepper = widget.simpleCartLine != null && inCart;
    final showFromPrice = widget.item.variants.isNotEmpty;
    final imageUrl = resolveMediaUrl(
      widget.item.imageUrl,
      serverUrl: widget.serverUrl,
    );
    final showPlaceholder =
        imageUrl == null || imageUrl.isEmpty || _imageFailed;
    final lang = Localizations.localeOf(context).languageCode;
    final itemName = widget.item.localizedName(lang);
    final description = widget.item.localizedDescription(lang)?.trim();
    final showDescription =
        !widget.compact && description != null && description.isNotEmpty;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final unavailable = widget.item.isManuallyUnavailable;
    final outsideSchedule = widget.item.isOutsideSchedule;

    if (widget.handheld) {
      return _buildHandheldCard(itemName, imageUrl, primary, showStepper);
    }

    if (!widget.showImage || showPlaceholder) {
      return _buildColorCard(
        itemName: itemName,
        showStepper: showStepper,
        showFromPrice: showFromPrice,
        unavailable: unavailable,
        outsideSchedule: outsideSchedule,
      );
    }

    return Opacity(
      opacity: unavailable ? 0.78 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: inCart ? soft.bg : PosTheme.surface,
          borderRadius: BorderRadius.circular(PosTheme.radiusLg),
          border: Border.all(
            color: unavailable
                ? const Color(0xFFB91C1C).withValues(alpha: 0.45)
                : outsideSchedule
                ? const Color(0xFFB45309).withValues(alpha: 0.4)
                : inCart
                ? primary.withValues(alpha: 0.42)
                : PosTheme.border,
            width: inCart || unavailable || outsideSchedule ? 1.5 : 1,
          ),
          boxShadow: inCart
              ? PosTheme.cardShadow(primary)
              : PosTheme.cardShadow(),
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(PosTheme.radiusLg),
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(PosTheme.radiusLg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boundedHeight = constraints.maxHeight.isFinite;
                final imageCacheW = constraints.maxWidth.isFinite
                    ? (constraints.maxWidth * dpr).round()
                    : null;
                final imageCacheH = boundedHeight
                    ? ((constraints.maxHeight * 0.55) * dpr).round()
                    : imageCacheW;
                final image = ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      PosTheme.radiusLg - (inCart ? 1.5 : 1),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (showPlaceholder)
                        _InitialsPlaceholder(
                          initials: _initials(itemName),
                          name: itemName,
                          accent: primary,
                          compact: widget.compact,
                        )
                      else
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: imageCacheW,
                          memCacheHeight: imageCacheH,
                          fadeInDuration: Duration.zero,
                          errorWidget: (context, url, error) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _imageFailed = true);
                            });
                            return _InitialsPlaceholder(
                              initials: _initials(itemName),
                              name: itemName,
                              accent: primary,
                              compact: widget.compact,
                            );
                          },
                          placeholder: (context, url) => Container(
                            color: PosTheme.surfaceMuted,
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primary.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.02),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.38),
                              ],
                              stops: const [0, 0.45, 1],
                            ),
                          ),
                        ),
                      ),
                      if (normalizePosItemType(widget.item.itemType) != null)
                        Positioned(
                          top: widget.compact ? 6 : 8,
                          left: widget.compact ? 6 : 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: PosItemTypeMark(
                                type: widget.item.itemType!,
                                size: widget.compact ? 14 : 16,
                              ),
                            ),
                          ),
                        ),
                      if (widget.item.isManuallyUnavailable ||
                          widget.item.isOutsideSchedule)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            color: widget.item.isManuallyUnavailable
                                ? const Color(0xE6B83232)
                                : const Color(0xCCB45309),
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.compact ? 6 : 8,
                              vertical: widget.compact ? 6 : 7,
                            ),
                            child: Text(
                              widget.item.isManuallyUnavailable
                                  ? context.posText(
                                      'menuNotAvailableBadge',
                                      'Not available',
                                    )
                                  : context.posText(
                                      'menuOutsideScheduleBadge',
                                      'Outside schedule',
                                    ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: widget.compact ? 9.5 : 11,
                                height: 1.1,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      if (widget.item.hasOptions && !widget.compact)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _GlassChip(
                            icon: Icons.tune_rounded,
                            label: context.l10n.menuOptions,
                          ),
                        ),
                      if (showStepper)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: IgnorePointer(
                              ignoring: unavailable || outsideSchedule,
                              child: _Stepper(
                                quantity: widget.inTicketQty,
                                compact: widget.compact,
                                accent: primary,
                                onDecrement: () => widget.onDecrementSimple
                                    ?.call(widget.simpleCartLine!),
                                onIncrement: () => widget.onIncrementSimple
                                    ?.call(widget.simpleCartLine!),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );

                // Never use Expanded under unbounded height — image collapses to 0.
                // Grid cells are height-bounded; popular/list cards use 4:3.
                final footer = _buildFooter(
                  primary: primary,
                  showFromPrice: showFromPrice,
                  showStepper: false,
                  showDescription: showDescription,
                  description: description,
                  itemName: itemName,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: boundedHeight && widget.showImage
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  children: [
                    if (widget.showImage)
                      if (boundedHeight)
                        Expanded(child: image)
                      else
                        AspectRatio(aspectRatio: 4 / 3, child: image),
                    footer,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandheldCard(
    String name,
    String? imageUrl,
    Color accent,
    bool stepper,
  ) {
    if (widget.photoGrid) {
      return _buildPhotoCard(name, imageUrl, accent, stepper);
    }
    final inCart = widget.inTicketQty > 0;
    final unavailable = widget.item.isManuallyUnavailable;
    final status = unavailable
        ? 'Not available'
        : widget.item.isOutsideSchedule
        ? 'Outside schedule'
        : null;
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 48,
        child: widget.showImage && imageUrl != null && !_imageFailed
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: (48 * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                placeholder: (_, _) => _colorMonogram(name, 48),
                errorWidget: (_, _, _) => _colorMonogram(name, 48),
              )
            : ColoredBox(
                color: _colorCardFill(),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 280;
        return Material(
          color: inCart ? posAccentSoft(accent).bg : PosTheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 76),
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: inCart
                      ? accent.withValues(alpha: 0.4)
                      : PosTheme.border,
                ),
              ),
              child: Row(
                children: [
                  thumbnail,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: PosTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (normalizePosItemType(widget.item.itemType) !=
                                null)
                              PosItemTypeMark(
                                type: widget.item.itemType!,
                                size: 12,
                              ),
                            Text(
                              '${widget.item.variants.isNotEmpty ? '${context.l10n.menuFrom} ' : ''}${formatMoney(_minDisplayPrice(), widget.currency)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        if (status != null)
                          Text(
                            status,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB45309),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (stepper && !narrow)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Decrease quantity',
                          onPressed: () => widget.onDecrementSimple?.call(
                            widget.simpleCartLine!,
                          ),
                          icon: const Icon(Icons.remove_rounded, size: 18),
                        ),
                        Text(
                          '${widget.inTicketQty}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Increase quantity',
                          onPressed: () => widget.onIncrementSimple?.call(
                            widget.simpleCartLine!,
                          ),
                          icon: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      tooltip: widget.item.hasOptions
                          ? context.l10n.menuOptions
                          : stepper
                          ? 'Increase quantity'
                          : 'Add item',
                      onPressed: stepper
                          ? () => widget.onIncrementSimple?.call(
                              widget.simpleCartLine!,
                            )
                          : _handleTap,
                      icon: Icon(
                        widget.item.hasOptions
                            ? Icons.tune_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 24,
                        color: accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _quantityBadge() => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          '\u00D7${widget.inTicketQty}',
          style: const TextStyle(
            color: Color(0xFFB54708),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );

  Widget _buildPhotoCard(
    String name,
    String? imageUrl,
    Color accent,
    bool stepper,
  ) {
    final unavailable =
        widget.item.isManuallyUnavailable || widget.item.isOutsideSchedule;
    return Material(
      color: PosTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unavailable ? const Color(0xFFEF9A9A) : PosTheme.border,
        ),
      ),
      child: InkWell(
        onTap: unavailable ? null : _handleTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 2.2,
                      child:
                          widget.showImage && imageUrl != null && !_imageFailed
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 480,
                              placeholder: (_, _) => _handheldColorMark(accent),
                              errorWidget: (_, _, _) =>
                                  _handheldColorMark(accent),
                            )
                          : _handheldColorMark(accent),
                    ),
                  ),
                  if (unavailable)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: widget.item.isManuallyUnavailable
                            ? const Color(0xCCB93232)
                            : const Color(0xCCB45309),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            widget.item.isManuallyUnavailable
                                ? 'Not available'
                                : 'Outside schedule',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(12) * 1.15 * 2,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosTheme.ink,
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (normalizePosItemType(widget.item.itemType) != null) ...[
                    PosItemTypeMark(type: widget.item.itemType!, size: 12),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      '${widget.item.variants.isNotEmpty ? '${context.l10n.menuFrom} ' : ''}${formatMoney(_minDisplayPrice(), widget.currency)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Spacer(),
              if (stepper)
                SizedBox(
                  height: 44,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: accent.withValues(alpha: .3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: IconButton(
                              onPressed: unavailable
                                  ? null
                                  : () => widget.onDecrementSimple?.call(
                                      widget.simpleCartLine!,
                                    ),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFFDE7E7),
                                foregroundColor: const Color(0xFFE53935),
                                shape: const RoundedRectangleBorder(),
                                minimumSize: const Size(0, 44),
                              ),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${widget.inTicketQty}',
                                style: TextStyle(
                                  color: PosTheme.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: IconButton(
                              onPressed: unavailable
                                  ? null
                                  : () => widget.onIncrementSimple?.call(
                                      widget.simpleCartLine!,
                                    ),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFE5F4E9),
                                foregroundColor: const Color(0xFF239B4B),
                                shape: const RoundedRectangleBorder(),
                                minimumSize: const Size(0, 44),
                              ),
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: Tooltip(
                    message: widget.item.hasOptions
                        ? 'Choose options'
                        : 'Add item',
                    child: OutlinedButton(
                      onPressed: unavailable ? null : _handleTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        minimumSize: const Size(0, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.standard,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        side: BorderSide(color: accent.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 18),
                          SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              'ADD',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const _colorCardPalette = <Color>[
    Color(0xFFD4F1FA),
    Color(0xFFF8D5E4),
    Color(0xFFF8DCC8),
    Color(0xFFD4F0DC),
    Color(0xFFFBF3C2),
  ];

  static const _colorCardPrice = Color(0xFFFF5C1F);

  Widget _colorMonogram(String itemName, double circle) {
    return Container(
      width: circle,
      height: circle,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(itemName),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: circle > 60 ? 22 : (widget.compact ? 16 : 18),
          color: const Color(0xFF1F2937),
          height: 1,
        ),
      ),
    );
  }

  Widget _handheldColorMark(Color accent) {
    return ColoredBox(
      color: _colorCardFill(),
      child: Center(
        child: Icon(Icons.restaurant_rounded, color: accent, size: 30),
      ),
    );
  }

  Color _colorCardFill() {
    final index = widget.item.id.abs() % _colorCardPalette.length;
    return _colorCardPalette[index];
  }

  Widget _buildColorCard({
    required String itemName,
    required bool showStepper,
    required bool showFromPrice,
    required bool unavailable,
    required bool outsideSchedule,
  }) {
    final fill = _colorCardFill();
    return Opacity(
      opacity: unavailable ? 0.78 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: _handleTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bounded = constraints.maxHeight.isFinite;
                final circle = bounded
                    ? (widget.compact ? 64.0 : 72.0)
                    : (widget.compact ? 48.0 : 56.0);
                return SizedBox(
                  height: bounded ? constraints.maxHeight : null,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          widget.compact ? 10 : 12,
                          widget.compact ? 8 : 10,
                          widget.compact ? 10 : 12,
                          widget.compact ? 8 : 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: bounded
                              ? MainAxisSize.max
                              : MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child:
                                  normalizePosItemType(widget.item.itemType) ==
                                      null
                                  ? const SizedBox(height: 16)
                                  : PosItemTypeMark(
                                      type: widget.item.itemType!,
                                      size: 14,
                                    ),
                            ),
                            if (bounded)
                              Expanded(
                                child: Center(
                                  child: _colorMonogram(itemName, circle),
                                ),
                              )
                            else ...[
                              const SizedBox(height: 8),
                              Center(child: _colorMonogram(itemName, circle)),
                            ],
                            if (showStepper)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Center(
                                  child: _Stepper(
                                    quantity: widget.inTicketQty,
                                    compact: true,
                                    soft:
                                        !widget.handheld &&
                                        !usePosHandheldLayout(context),
                                    accent: _colorCardPrice,
                                    onDecrement: () => widget.onDecrementSimple
                                        ?.call(widget.simpleCartLine!),
                                    onIncrement: () => widget.onIncrementSimple
                                        ?.call(widget.simpleCartLine!),
                                  ),
                                ),
                              ),
                            SizedBox(height: widget.compact ? 8 : 10),
                            Text(
                              itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: widget.compact ? 14.3 : 15.4,
                                height: 1.15,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            if (widget.item.variants.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.item.variants
                                    .map((variant) => variant.name)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                  height: 1.1,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    showFromPrice
                                        ? '${context.l10n.menuFrom} ${formatMoney(_minDisplayPrice(), widget.currency)}'
                                        : formatMoney(
                                            _minDisplayPrice(),
                                            widget.currency,
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _colorCardPrice,
                                      fontWeight: FontWeight.w700,
                                      fontSize: widget.compact ? 14.3 : 15.4,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                if (widget.inTicketQty > 0)
                                  _quantityBadge()
                                else
                                  Material(
                                    color: _colorCardPrice,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: _handleTap,
                                      child: const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: Icon(
                                          Icons.add_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (unavailable || outsideSchedule)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            color: unavailable
                                ? const Color(0xE6B83232)
                                : const Color(0xCCB45309),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              unavailable
                                  ? context.posText(
                                      'menuNotAvailableBadge',
                                      'Not available',
                                    )
                                  : context.posText(
                                      'menuOutsideScheduleBadge',
                                      'Outside schedule',
                                    ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
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
        ),
      ),
    );
  }

  Widget _buildFooter({
    required Color primary,
    required bool showFromPrice,
    required bool showStepper,
    required bool showDescription,
    required String? description,
    required String itemName,
  }) {
    // 15px semi-bold price — readable without overpowering the card.
    final actionHeight = widget.compact ? 28.6 : 33.0;
    final priceStyle = GoogleFonts.inter(
      color: primary,
      fontWeight: FontWeight.w600,
      fontSize: widget.compact ? 14.3 : 15.4,
      height: 1.0,
      letterSpacing: -0.025 * 14,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final fromLabelStyle = GoogleFonts.inter(
      color: PosTheme.inkFaint,
      fontWeight: FontWeight.w600,
      fontSize: 10,
      height: 1.0,
      letterSpacing: 0.4,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 7 : 9,
        widget.compact ? 5 : 7,
        widget.compact ? 7 : 9,
        widget.compact ? 6 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  itemName,
                  maxLines: widget.item.variants.isNotEmpty
                      ? 1
                      : (widget.compact ? 1 : 2),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: widget.compact ? 14.03 : 15.15,
                    height: 1.25,
                    letterSpacing: -0.15,
                    color: PosTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          if (widget.item.variants.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              widget.item.variants.map((variant) => variant.name).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: widget.compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: PosTheme.inkMuted,
                height: 1.2,
              ),
            ),
          ],
          if (showDescription) ...[
            const SizedBox(height: 3),
            Text(
              description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: PosTheme.inkMuted,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 4),
          SizedBox(
            height: showFromPrice && !widget.compact ? 39.6 : actionHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: showFromPrice && !widget.compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.menuFrom,
                                style: fromLabelStyle,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatMoney(
                                  _minDisplayPrice(),
                                  widget.currency,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: priceStyle,
                              ),
                            ],
                          )
                        : Text.rich(
                            TextSpan(
                              children: [
                                if (showFromPrice)
                                  TextSpan(
                                    text: '${context.l10n.menuFrom} ',
                                    style: fromLabelStyle,
                                  ),
                                TextSpan(
                                  text: formatMoney(
                                    _minDisplayPrice(),
                                    widget.currency,
                                  ),
                                  style: priceStyle,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
                if (widget.inTicketQty > 0) _quantityBadge(),
                if (widget.inTicketQty == 0)
                  Tooltip(
                    message: widget.item.hasOptions
                        ? context.l10n.menuOptions
                        : 'Add item',
                    child: Material(
                      color: primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _handleTap,
                        child: const SizedBox(
                          width: 28,
                          height: 28,
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showStepper)
                  _Stepper(
                    quantity: widget.simpleCartLine!.quantity,
                    compact: widget.compact,
                    accent: primary,
                    onDecrement: () =>
                        widget.onDecrementSimple?.call(widget.simpleCartLine!),
                    onIncrement: () {
                      HapticFeedback.selectionClick();
                      widget.onIncrementSimple?.call(widget.simpleCartLine!);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsPlaceholder extends StatelessWidget {
  const _InitialsPlaceholder({
    required this.initials,
    required this.name,
    required this.accent,
    required this.compact,
  });

  final String initials;
  final String name;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            soft.bg,
            Color.alphaBlend(accent.withValues(alpha: 0.08), PosTheme.surface),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 40 : 48,
              height: compact ? 40 : 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PosTheme.surface.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Text(
                initials,
                style: TextStyle(
                  color: soft.fg,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 15 : 17,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: soft.fg.withValues(alpha: 0.8),
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.compact,
    required this.accent,
    required this.onDecrement,
    required this.onIncrement,
    this.soft = false,
  });

  final bool soft;
  final int quantity;
  final bool compact;
  final Color accent;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 38.0;
    final barColor = Colors.white.withValues(alpha: soft ? 0.85 : 1);
    final preferredWidth = (compact ? 122.0 : 134.0) + (soft ? 8 : 0);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth.isFinite
            ? preferredWidth.clamp(0.0, constraints.maxWidth)
            : preferredWidth,
        child: Material(
          color: barColor,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: _StepperButton(
                    icon: Icons.remove_rounded,
                    size: size,
                    foreground: const Color(0xFF239B4B),
                    opacity: soft ? 0.82 : 1,
                    onTap: onDecrement,
                  ),
                ),
                Expanded(
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF172033),
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 13 : 14,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: _StepperButton(
                    icon: Icons.add_rounded,
                    size: size,
                    foreground: const Color(0xFFE53935),
                    opacity: soft ? 0.82 : 1,
                    onTap: onIncrement,
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

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.size,
    required this.foreground,
    required this.onTap,
    this.opacity = 1,
  });

  final double opacity;
  final IconData icon;
  final double size;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: size + 6,
        height: size + 14,
        decoration: BoxDecoration(
          color:
              (icon == Icons.remove_rounded
                      ? const Color(0xFFE0F2E6)
                      : const Color(0xFFFDE7E7))
                  .withValues(alpha: opacity),
        ),
        child: Icon(icon, color: foreground, size: size * 0.48),
      ),
    );
  }
}
