import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/media_url.dart';
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

  @override
  State<PosMenuItemCard> createState() => _PosMenuItemCardState();
}

class _PosMenuItemCardState extends State<PosMenuItemCard>
    with SingleTickerProviderStateMixin {
  bool _imageFailed = false;
  late AnimationController _flashController;
  late Animation<double> _flashScale;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _flashScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 60),
    ]).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant PosMenuItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imageUrl != widget.item.imageUrl ||
        oldWidget.serverUrl != widget.serverUrl) {
      _imageFailed = false;
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _triggerFlash() {
    _flashController.forward(from: 0);
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _triggerFlash();
    widget.onTap();
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
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
    final showQtyBadge = widget.item.hasOptions && inCart;
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
    final showDescription = !widget.compact &&
        description != null &&
        description.isNotEmpty;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final unavailable = widget.item.isManuallyUnavailable;
    final outsideSchedule = widget.item.isOutsideSchedule;

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
                  top: Radius.circular(PosTheme.radiusLg - (inCart ? 1.5 : 1)),
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
                        fadeInDuration: const Duration(milliseconds: 180),
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
                        child: PosItemTypeBadge(
                          type: widget.item.itemType!,
                          compact: widget.compact,
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
                              ? const Color(0xCC991B1B)
                              : const Color(0xCCB45309),
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.compact ? 6 : 8,
                            vertical: widget.compact ? 4 : 5,
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
                    if (showQtyBadge)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            '×${widget.inTicketQty}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    if (inCart && !widget.item.hasOptions)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '×${widget.inTicketQty}',
                            style: TextStyle(
                              color: soft.fg,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              height: 1,
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
                soft: soft,
                showFromPrice: showFromPrice,
                showStepper: showStepper,
                showDescription: showDescription,
                description: description,
                itemName: itemName,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize:
                    boundedHeight ? MainAxisSize.max : MainAxisSize.min,
                children: [
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

  Widget _buildFooter({
    required Color primary,
    required ({Color bg, Color fg}) soft,
    required bool showFromPrice,
    required bool showStepper,
    required bool showDescription,
    required String? description,
    required String itemName,
  }) {
    // 15px semi-bold price — readable without overpowering the card.
    final actionHeight = widget.compact ? 26.0 : 30.0;
    final priceStyle = GoogleFonts.inter(
      color: primary,
      fontWeight: FontWeight.w600,
      fontSize: widget.compact ? 13 : 14,
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
              if (normalizePosItemType(widget.item.itemType) != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: PosItemTypeMark(
                    type: widget.item.itemType!,
                    size: widget.compact ? 12 : 14,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  itemName,
                  maxLines: widget.compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: widget.compact ? 12.5 : 13.5,
                    height: 1.25,
                    letterSpacing: -0.15,
                    color: PosTheme.ink,
                  ),
                ),
              ),
            ],
          ),
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
            height: showFromPrice && !widget.compact ? 36 : actionHeight,
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
                                formatMoney(_minDisplayPrice(), widget.currency),
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
                if (showStepper)
                  _Stepper(
                    quantity: widget.simpleCartLine!.quantity,
                    compact: widget.compact,
                    accent: primary,
                    onDecrement: () =>
                        widget.onDecrementSimple?.call(widget.simpleCartLine!),
                    onIncrement: () {
                      HapticFeedback.selectionClick();
                      _triggerFlash();
                      widget.onIncrementSimple?.call(widget.simpleCartLine!);
                    },
                  )
                else
                  ScaleTransition(
                    scale: _flashScale,
                    child: _AddButton(
                      accent: primary,
                      soft: soft,
                      compact: widget.compact,
                      hasOptions: widget.item.hasOptions,
                      height: actionHeight,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _triggerFlash();
                        widget.onTap();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.accent,
    required this.soft,
    required this.compact,
    required this.hasOptions,
    required this.height,
    required this.onPressed,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final bool compact;
  final bool hasOptions;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final showLabel = hasOptions && !compact;

    // Avoid AnimatedContainer width: null ↔ finite — Flutter cannot lerp those
    // constraints and it cascades into broken card/image layout in GridView.
    return Material(
      color: hasOptions ? soft.bg : accent,
      borderRadius: BorderRadius.circular(12),
      elevation: hasOptions ? 0 : 2,
      shadowColor: accent.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height,
          width: showLabel ? null : height,
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 10 : 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: hasOptions
                ? Border.all(color: accent.withValues(alpha: 0.28))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasOptions ? Icons.tune_rounded : Icons.add_rounded,
                color: hasOptions ? soft.fg : Colors.white,
                size: compact ? 16 : 18,
              ),
              if (showLabel) ...[
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: Text(
                    context.l10n.menuChoose,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: soft.fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
  });

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
  });

  final int quantity;
  final bool compact;
  final Color accent;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 32.0;
    // Always use a dark filled bar so white +/- stay readable in both themes.
    final barColor = Color.lerp(PosTheme.inkLight, accent, 0.22)!;
    return Material(
      color: barColor,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperButton(
              icon: Icons.remove_rounded,
              size: size,
              foreground: Colors.white,
              onTap: onDecrement,
            ),
            SizedBox(
              width: compact ? 22 : 24,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 11 : 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _StepperButton(
              icon: Icons.add_rounded,
              size: size,
              foreground: Colors.white,
              onTap: onIncrement,
            ),
          ],
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
  });

  final IconData icon;
  final double size;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, color: foreground, size: size * 0.48),
      ),
    );
  }
}
