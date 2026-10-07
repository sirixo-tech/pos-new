import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../providers/pos_locale_controller.dart';
import '../theme/pos_theme.dart';
import '../widgets/pos_more_menu.dart';
import '../widgets/pos_more_menu_sections.dart';

/// Phone Settings tab. Same actions as the header More menu.
class PosMobileSettingsPage extends StatelessWidget {
  const PosMobileSettingsPage({super.key, required this.onSelected});

  final Future<void> Function(String value) onSelected;

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final l10n = context.l10n;
    final locale = context.watch<PosLocaleController>();
    final bootstrap = pos.bootstrap;
    final guest = bootstrap?.guestOrdering ?? const PosGuestOrdering();
    final storeAccepting = guest.acceptOnlineOrders;
    final storeStatusLabel = guest.open
        ? l10n.storeOpen
        : (guest.isPaused || !storeAccepting ? l10n.storePaused : l10n.storeClosed);
    final caps = bootstrap?.adminCapabilities;
    final canViewMenu =
        caps?.canViewMenu == true ||
        caps?.canManageMenu == true ||
        caps?.canManageMenuItems == true;
    final platforms =
        bootstrap?.marketplacePlatforms ?? const <MarketplacePlatformInfo>[];
    final notificationCount = pos.registerBillUnreadCount;
    final allowDelivery = bootstrap?.allowsPosDelivery ?? true;

    return PosMoreMenuPage(
      title: 'Settings',
      onSelect: (value) => onSelected(value),
      sections: [
        PosMoreMenuSection(
          title: 'Quick actions',
          items: [
            PosMoreMenuItem(
              id: '_notifications',
              icon: Icons.notifications_outlined,
              label: l10n.waiterNavAlerts,
              badge: notificationCount > 0 ? '$notificationCount' : null,
            ),
            if (allowDelivery)
              PosMoreMenuItem(
                id: '_delivery',
                icon: Icons.delivery_dining_rounded,
                label: context.posText('shellDeliveryOrders', 'Delivery orders'),
              ),
            PosMoreMenuItem(
              id: bootstrap?.currentShift == null ? 'open_shift' : 'close_shift',
              icon: Icons.schedule_rounded,
              label: bootstrap?.currentShift == null
                  ? l10n.opsOpenOptional
                  : l10n.opsCloseShift,
            ),
          ],
        ),
        ...buildPosMoreMenuSections(
          context: context,
          l10n: l10n,
          storeAccepting: storeAccepting,
          storeStatusLabel: storeStatusLabel,
          canManageStore: caps?.canManageSettings == true,
          canAccessAdmin: caps?.canAccessAdmin == true,
          canViewMenu: canViewMenu,
          marketplacePlatforms: platforms,
          showLanguageSwitcher: locale.showSwitcher,
          terminalCount: bootstrap?.posTerminals.length ?? 0,
          canChangeLocation: pos.canChangeLocation,
          hasPin: pos.session?.hasPosPin == true,
          canUseCaptain: pos.canUseCaptain,
          canChooseWorkMode: pos.canChooseWorkMode,
          checkingForUpdates: pos.checkingForUpdates,
          pendingOrderCount: pos.pendingOrderCount,
          hasDeviceBinding: pos.deviceBinding != null,
          includeShortcuts: false,
        ),
      ],
    );
  }
}

class PosMobileNavBar extends StatelessWidget {
  const PosMobileNavBar({
    super.key,
    required this.index,
    required this.ordersCount,
    required this.onSelected,
  });

  final int index;
  final int ordersCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    const items = [
      (Icons.point_of_sale_rounded, 'POS'),
      (Icons.receipt_long_rounded, 'Orders'),
      (Icons.flare_rounded, 'AI'),
      (Icons.menu_book_rounded, 'Menu'),
      (Icons.bar_chart_rounded, 'Reports'),
    ];

    return ColoredBox(
      color: PosTheme.canvas,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PosTheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: PosTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: PosTheme.isDark ? 0.35 : 0.08,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: items[i].$1,
                        label: items[i].$2,
                        selected: index == i,
                        accent: accent,
                        capsule: soft.bg,
                        badge: i == 1 && ordersCount > 0 ? ordersCount : null,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.capsule,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final Color capsule;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : PosTheme.inkMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? capsule : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: badge != null,
                  backgroundColor: accent,
                  label: Text(
                    '${badge ?? 0}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: label == 'AI'
                      ? _AiMark(color: color)
                      : Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
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

/// One centered sparkle, same box as the other tab icons.
class _AiMark extends StatelessWidget {
  const _AiMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _AiMarkPainter(color),
    );
  }
}

class _AiMarkPainter extends CustomPainter {
  _AiMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawPath(
      _spark(center, size.shortestSide * 0.40),
      Paint()..color = color,
    );
  }

  Path _spark(Offset center, double radius) {
    final path = Path()..moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(
      center.dx,
      center.dy,
      center.dx + radius,
      center.dy,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy,
      center.dx,
      center.dy + radius,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy,
      center.dx - radius,
      center.dy,
    );
    path.quadraticBezierTo(
      center.dx,
      center.dy,
      center.dx,
      center.dy - radius,
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _AiMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
