import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/pos_l10n.dart';
import '../../theme/pos_theme.dart';

/// Celebratory acknowledgment after captain sends a KOT (replaces a toast).
Future<void> showKotSentDialog(
  BuildContext context, {
  required String orderNumber,
  String? token,
  String? tableName,
}) {
  HapticFeedback.mediumImpact();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => _KotSentDialog(
      orderNumber: orderNumber,
      token: token,
      tableName: tableName,
    ),
  );
}

class _KotSentDialog extends StatelessWidget {
  const _KotSentDialog({
    required this.orderNumber,
    this.token,
    this.tableName,
  });

  final String orderNumber;
  final String? token;
  final String? tableName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.sizeOf(context);
    final tokenLabel = (token != null && token!.trim().isNotEmpty)
        ? l10n.ordersTokenLabel(token!.trim())
        : null;
    final subtitle = [
      if (tableName != null && tableName!.trim().isNotEmpty) tableName!.trim(),
      orderNumber,
    ].join(' · ');

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: media.width < 420 ? 28 : 48,
        vertical: 24,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.waiterKotSentTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (tokenLabel != null)
                      Text(
                        tokenLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      Text(
                        orderNumber,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (subtitle.isNotEmpty && tokenLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    const _SuccessBurst(),
                    const SizedBox(height: 28),
                    Text(
                      l10n.waiterKotSentSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: PosTheme.inkMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          l10n.commonDone,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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
}

class _SuccessBurst extends StatelessWidget {
  const _SuccessBurst();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(148, 148),
            painter: _ConfettiPainter(),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final specs = <_Speck>[
      _Speck(0.12, 0.55, const Color(0xFFF43F5E), _SpeckKind.dot),
      _Speck(0.28, 0.22, const Color(0xFF14B8A6), _SpeckKind.square),
      _Speck(0.48, 0.12, const Color(0xFFFBBF24), _SpeckKind.diamond),
      _Speck(0.72, 0.2, const Color(0xFFEC4899), _SpeckKind.squiggle),
      _Speck(0.88, 0.42, const Color(0xFF22D3EE), _SpeckKind.dot),
      _Speck(0.9, 0.7, const Color(0xFFF97316), _SpeckKind.square),
      _Speck(0.7, 0.9, const Color(0xFFA855F7), _SpeckKind.diamond),
      _Speck(0.42, 0.94, const Color(0xFFEF4444), _SpeckKind.dot),
      _Speck(0.18, 0.82, const Color(0xFF84CC16), _SpeckKind.squiggle),
      _Speck(0.08, 0.35, const Color(0xFFF59E0B), _SpeckKind.square),
    ];

    for (final speck in specs) {
      final angle = speck.angleTurns * math.pi * 2;
      final radius = size.shortestSide * speck.radiusFactor * 0.48;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final paint = Paint()
        ..color = speck.color
        ..style = PaintingStyle.fill;

      switch (speck.kind) {
        case _SpeckKind.dot:
          canvas.drawCircle(pos, 4.5, paint);
        case _SpeckKind.square:
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(0.4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -4, 8, 8),
              const Radius.circular(1.5),
            ),
            paint,
          );
          canvas.restore();
        case _SpeckKind.diamond:
          final path = Path()
            ..moveTo(pos.dx, pos.dy - 5.5)
            ..lineTo(pos.dx + 5, pos.dy)
            ..lineTo(pos.dx, pos.dy + 5.5)
            ..lineTo(pos.dx - 5, pos.dy)
            ..close();
          canvas.drawPath(path, paint);
        case _SpeckKind.squiggle:
          final path = Path()
            ..moveTo(pos.dx - 6, pos.dy)
            ..quadraticBezierTo(pos.dx - 2, pos.dy - 6, pos.dx + 2, pos.dy)
            ..quadraticBezierTo(pos.dx + 6, pos.dy + 6, pos.dx + 9, pos.dy);
          canvas.drawPath(
            path,
            Paint()
              ..color = speck.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..strokeCap = StrokeCap.round,
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _SpeckKind { dot, square, diamond, squiggle }

class _Speck {
  const _Speck(this.angleTurns, this.radiusFactor, this.color, this.kind);

  final double angleTurns;
  final double radiusFactor;
  final Color color;
  final _SpeckKind kind;
}
