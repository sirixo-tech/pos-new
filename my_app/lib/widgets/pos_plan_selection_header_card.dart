import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/pos_controller.dart';
import '../screens/pos_billing_screen.dart';

/// Ultra-premium plan selection header card displayed at the top of Settings.
///
/// Matches the executive dark-slate design with business info and subscription tier,
/// navigating to [PosBillingScreen] upon interaction.
class PosPlanSelectionHeaderCard extends StatelessWidget {
  const PosPlanSelectionHeaderCard({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PosBillingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final bootstrap = pos.bootstrap;
    final restaurant = bootstrap?.restaurant;
    final branch = bootstrap?.branch;

    final restaurantName = (restaurant?.name.isNotEmpty ?? false)
        ? restaurant!.name
        : 'Godavari';

    final subtitle = (branch?.address?.isNotEmpty ?? false)
        ? branch!.address!
        : (branch?.name.isNotEmpty ?? false)
            ? branch!.name
            : (pos.session?.userEmail?.isNotEmpty ?? false)
                ? pos.session!.userEmail!
                : '+91 9949091899';

    final logoUrl = restaurant?.logoUrl;
    final initial = restaurantName.isNotEmpty
        ? restaurantName[0].toUpperCase()
        : 'G';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13151D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF242836), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CardContourWavePainter(),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleTap(context),
              borderRadius: BorderRadius.circular(18),
              splashColor: Colors.white.withValues(alpha: 0.05),
              highlightColor: Colors.white.withValues(alpha: 0.03),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Upper row: Restaurant profile
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
                    child: Row(
                      children: [
                        _buildAvatar(logoUrl, initial),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurantName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF64748B),
                          size: 22,
                        ),
                      ],
                    ),
                  ),

                  // Subtle divider
                  Container(
                    height: 1,
                    color: const Color(0xFF222635),
                  ),

                  // Lower row: Business Growth Plan
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF251C0F),
                            border: Border.all(
                              color: const Color(0xFFD97706).withValues(alpha: 0.45),
                              width: 1.2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Business Growth Plan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFEF3C7),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? logoUrl, String initial) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFF33384A),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildMonogram(initial),
          errorWidget: (_, __, ___) => _buildMonogram(initial),
        ),
      );
    }
    return _buildMonogram(initial);
  }

  Widget _buildMonogram(String initial) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E2332),
        border: Border.all(
          color: const Color(0xFF33394D),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Draws subtle concentric wave contours in the top-right corner of the card.
class _CardContourWavePainter extends CustomPainter {
  const _CardContourWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width * 0.92, size.height * 0.18);
    for (var r = 24.0; r <= 140.0; r += 14.0) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
