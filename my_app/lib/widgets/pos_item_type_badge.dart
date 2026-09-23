import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../theme/pos_theme.dart';

/// Normalized POS menu item diet / type key (`veg`, `non_veg`, `drink`, …).
String? normalizePosItemType(String? raw) {
  if (raw == null) return null;
  final t = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  if (t.isEmpty) return null;
  switch (t) {
    case 'veg':
    case 'vegetarian':
      return 'veg';
    case 'non_veg':
    case 'nonveg':
    case 'non_vegetarian':
      return 'non_veg';
    case 'vegan':
      return 'vegan';
    case 'egg':
    case 'eggetarian':
      return 'egg';
    case 'drink':
    case 'beverage':
    case 'drinks':
      return 'drink';
    default:
      return t;
  }
}

/// FSSAI-style veg / non-veg marks plus drink / egg / vegan indicators.
class PosItemTypeMark extends StatelessWidget {
  const PosItemTypeMark({
    super.key,
    required this.type,
    this.size = 16,
  });

  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final key = normalizePosItemType(type);
    if (key == null) return const SizedBox.shrink();

    switch (key) {
      case 'veg':
        return _BoxedMark(
          size: size,
          color: const Color(0xFF16A34A),
          child: _Dot(color: const Color(0xFF16A34A), size: size * 0.38),
        );
      case 'non_veg':
        return _BoxedMark(
          size: size,
          color: const Color(0xFFDC2626),
          child: _Triangle(color: const Color(0xFFDC2626), size: size * 0.42),
        );
      case 'vegan':
        return _BoxedMark(
          size: size,
          color: const Color(0xFF059669),
          child: Icon(
            Icons.eco_rounded,
            size: size * 0.62,
            color: const Color(0xFF059669),
          ),
        );
      case 'egg':
        return _BoxedMark(
          size: size,
          color: const Color(0xFFD97706),
          child: Icon(
            Icons.egg_rounded,
            size: size * 0.62,
            color: const Color(0xFFD97706),
          ),
        );
      case 'drink':
        return _BoxedMark(
          size: size,
          color: const Color(0xFF0284C7),
          child: Icon(
            Icons.local_cafe_rounded,
            size: size * 0.58,
            color: const Color(0xFF0284C7),
          ),
        );
      default:
        return _BoxedMark(
          size: size,
          color: const Color(0xFF64748B),
          child: _Dot(color: const Color(0xFF64748B), size: size * 0.32),
        );
    }
  }
}

/// Badge with mark + short label (matches web POS ItemTypeBadge).
class PosItemTypeBadge extends StatelessWidget {
  const PosItemTypeBadge({
    super.key,
    required this.type,
    this.compact = false,
  });

  final String type;
  final bool compact;

  static String? labelFor(String? type, AppLocalizations l10n) {
    final key = normalizePosItemType(type);
    if (key == null) return null;
    switch (key) {
      case 'veg':
        return l10n.dietVeg;
      case 'non_veg':
        return l10n.dietNonVeg;
      case 'vegan':
        return l10n.dietVegan;
      case 'egg':
        return l10n.dietEgg;
      case 'drink':
        return l10n.dietDrink;
      default:
        return key.replaceAll('_', ' ');
    }
  }

  Color _accent(String key) {
    switch (key) {
      case 'veg':
        return const Color(0xFF15803D);
      case 'non_veg':
        return const Color(0xFFB91C1C);
      case 'vegan':
        return const Color(0xFF047857);
      case 'egg':
        return const Color(0xFFB45309);
      case 'drink':
        return const Color(0xFF0369A1);
      default:
        return const Color(0xFF475569);
    }
  }

  Color _bg(String key) {
    switch (key) {
      case 'veg':
        return const Color(0xFFF0FDF4);
      case 'non_veg':
        return const Color(0xFFFEF2F2);
      case 'vegan':
        return const Color(0xFFECFDF5);
      case 'egg':
        return const Color(0xFFFFFBEB);
      case 'drink':
        return const Color(0xFFF0F9FF);
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = normalizePosItemType(type);
    if (key == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final label = labelFor(key, l10n) ?? key;
    final accent = _accent(key);
    final soft = posAccentSoft(accent);
    final fg = PosTheme.isDark ? soft.fg : accent;
    final bg = PosTheme.isDark ? soft.bg : _bg(key).withValues(alpha: 0.96);
    final markSize = compact ? 13.0 : 15.0;

    if (compact) {
      return Tooltip(
        message: label,
        child: PosItemTypeMark(type: key, size: markSize),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
        boxShadow: PosTheme.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PosItemTypeMark(type: key, size: markSize),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: fg,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoxedMark extends StatelessWidget {
  const _BoxedMark({
    required this.size,
    required this.color,
    required this.child,
  });

  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.14),
          border: Border.all(color: color, width: size * 0.1),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Triangle extends StatelessWidget {
  const _Triangle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.9),
      painter: _TrianglePainter(color),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
