import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Network logo that sizes its slot from the image's intrinsic aspect ratio.
///
/// - **Portrait** (tall): compact tall slot  
/// - **Square / near-square**: square mark (avoids a wide empty plate)  
/// - **Landscape** (wordmark): wide short strip, width capped to content
class PosNetworkLogo extends StatefulWidget {
  const PosNetworkLogo({
    super.key,
    required this.imageUrl,
    this.maxWidth = 140,
    this.maxHeight = 36,
    this.portraitSide,
    this.alignment = Alignment.centerLeft,
    this.fadeInDuration = const Duration(milliseconds: 150),
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double maxWidth;
  final double maxHeight;

  /// Preferred side length for square / portrait marks.
  /// Defaults to ~1.35× [maxHeight].
  final double? portraitSide;
  final Alignment alignment;
  final Duration fadeInDuration;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  @override
  State<PosNetworkLogo> createState() => _PosNetworkLogoState();
}

class _PosNetworkLogoState extends State<PosNetworkLogo> {
  /// width / height — null until resolved.
  double? _aspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveAspect();
  }

  @override
  void didUpdateWidget(covariant PosNetworkLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _aspect = null;
      _resolveAspect();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolveAspect() {
    _detach();
    final provider = CachedNetworkImageProvider(widget.imageUrl);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (h <= 0 || !mounted) return;
        final next = w / h;
        if (_aspect != next) {
          setState(() => _aspect = next);
        }
      },
      onError: (_, _) {},
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  /// Assume square until known so we don't flash a wide empty landscape plate.
  double get _resolvedAspect => _aspect ?? 1.0;

  Size get _slot {
    final aspect = _resolvedAspect;
    final maxW = widget.maxWidth;
    final maxH = widget.maxHeight;
    final markSide = (widget.portraitSide ?? maxH * 1.35)
        .clamp(maxH, maxW);

    // Tall portrait
    if (aspect < 0.85) {
      final h = markSide;
      final w = (h * aspect).clamp(maxH * 0.55, h);
      return Size(w, h);
    }

    // Square / near-square (includes most badge-style logos)
    if (aspect <= 1.35) {
      return Size(markSide, markSide);
    }

    // Wide wordmark — size to content within max bounds (don't force maxWidth)
    var h = maxH;
    var w = h * aspect;
    if (w > maxW) {
      w = maxW;
      h = w / aspect;
    }
    return Size(w, h.clamp(maxH * 0.7, maxH));
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return SizedBox(
      width: slot.width,
      height: slot.height,
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        width: slot.width,
        height: slot.height,
        memCacheWidth: (slot.width * dpr).round(),
        memCacheHeight: (slot.height * dpr).round(),
        fit: BoxFit.contain,
        alignment: widget.alignment,
        fadeInDuration: widget.fadeInDuration,
        placeholder: widget.placeholder,
        errorWidget: widget.errorWidget,
      ),
    );
  }
}
