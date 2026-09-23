import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/pos_theme.dart';
import 'pos_network_logo.dart';

/// Wide auth left panel shared by login, lock, and onboarding screens.
///
/// Restaurant logo is the only mark here. Platform branding lives above the
/// sign-in form (right column / compact header).
class PosAuthHeroPanel extends StatelessWidget {
  const PosAuthHeroPanel({
    super.key,
    required this.accent,
    required this.statusLabel,
    required this.statusIcon,
    required this.headline,
    this.logoUrl,
    this.locationLine,
    this.personLabel,
    this.personInitial,
    this.now,
    this.fallbackInitials = 'P',
    this.fallbackIcon = Icons.point_of_sale_rounded,
    this.footerNote,
    this.showClock = true,
  });

  final Color accent;
  final String statusLabel;
  final IconData statusIcon;
  final String headline;
  final String? logoUrl;
  final String? locationLine;
  final String? personLabel;
  final String? personInitial;
  final DateTime? now;
  final String fallbackInitials;
  final IconData fallbackIcon;
  final String? footerNote;
  final bool showClock;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now();
    final timeLabel = DateFormat('h:mm').format(clock);
    final amPm = DateFormat('a').format(clock);
    final dateLabel = DateFormat('EEEE · MMM d').format(clock);
    final hasRestaurantLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(gradient: PosTheme.brandGradient(accent)),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -100,
            bottom: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(44, 36, 44, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  if (hasRestaurantLogo)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: PosNetworkLogo(
                          imageUrl: logoUrl!,
                          maxWidth: 200,
                          maxHeight: 52,
                          portraitSide: 88,
                          alignment: Alignment.centerLeft,
                          errorWidget: (context, url, error) => Text(
                            fallbackInitials,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        fallbackInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 40,
                          height: 1.05,
                          letterSpacing: -1,
                        ),
                  ),
                  if (locationLine != null && locationLine!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      locationLine!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (personLabel != null && personLabel!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.18),
                          child: Text(
                            (personInitial ?? personLabel!.substring(0, 1))
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            personLabel!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(flex: 3),
                  if (showClock) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 56,
                            height: 1,
                            letterSpacing: -1.5,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 8),
                          child: Text(
                            amPm,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  if (footerNote != null && footerNote!.isNotEmpty) ...[
                    SizedBox(height: showClock ? 12 : 0),
                    Text(
                      footerNote!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
