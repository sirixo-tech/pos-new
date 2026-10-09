import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../providers/pos_locale_controller.dart';
import '../theme/pos_theme.dart';
import '../services/pos_storage.dart';
import '../widgets/pos_more_menu.dart';
import '../widgets/pos_more_menu_sections.dart';

/// Phone Settings tab. Same actions as the header More menu.
class PosMobileSettingsPage extends StatelessWidget {
  const PosMobileSettingsPage({
    super.key,
    required this.onSelected,
    this.onClose,
  });

  final VoidCallback? onClose;
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
        : (guest.isPaused || !storeAccepting
              ? l10n.storePaused
              : l10n.storeClosed);
    final caps = bootstrap?.adminCapabilities;
    final canViewMenu =
        caps?.canViewMenu == true ||
        caps?.canManageMenu == true ||
        caps?.canManageMenuItems == true;
    final platforms =
        bootstrap?.marketplacePlatforms ?? const <MarketplacePlatformInfo>[];
    final notificationCount = pos.registerBillUnreadCount;
    final allowDelivery = bootstrap?.allowsPosDelivery ?? true;

    final sections = <PosMoreMenuSection>[
      PosMoreMenuSection(
        title: 'Quick actions',
        items: [
          PosMoreMenuItem(
            id: '_notifications',
            icon: CupertinoIcons.bell,
            label: l10n.waiterNavAlerts,
            badge: notificationCount > 0 ? '$notificationCount' : null,
          ),
          if (allowDelivery)
            PosMoreMenuItem(
              id: '_delivery',
              icon: CupertinoIcons.car,
              label: context.posText('shellDeliveryOrders', 'Delivery orders'),
            ),
          PosMoreMenuItem(
            id: bootstrap?.currentShift == null ? 'open_shift' : 'close_shift',
            icon: CupertinoIcons.clock,
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
    ];
    return PosSettingsOverview(
      sections: sections,
      onSelected: onSelected,
      onClose: onClose,
    );
  }
}

class PosSettingsOverview extends StatefulWidget {
  const PosSettingsOverview({
    super.key,
    this.onClose,
    required this.sections,
    required this.onSelected,
  });
  final VoidCallback? onClose;
  final List<PosMoreMenuSection> sections;
  final Future<void> Function(String) onSelected;

  @override
  State<PosSettingsOverview> createState() => _PosSettingsOverviewState();
}

class _PosSettingsOverviewState extends State<PosSettingsOverview> {
  final Set<int> _expanded = {};
  List<PosMoreMenuSection> get sections => widget.sections;
  Future<void> Function(String) get onSelected => widget.onSelected;

  final _storage = PosStorage();
  Set<String> _hidden = {};
  bool _customizing = false;
  bool _loaded = false;
  Future<void> _save = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _loadCustomization();
  }

  Future<void> _loadCustomization() async {
    final hidden = await _storage.getMoreMenuHiddenIds();
    if (!mounted) return;
    setState(() {
      _hidden = hidden;
      _loaded = true;
    });
  }

  void _toggleItem(String id) {
    setState(() {
      if (!_hidden.add(id)) _hidden.remove(id);
    });
    final snapshot = Set<String>.from(_hidden);
    _save = _save.then((_) => _storage.saveMoreMenuHiddenIds(snapshot));
  }

  List<PosMoreMenuItem> _items(int index) => sections[index].items
      .where((item) => _customizing || !_hidden.contains(item.id))
      .toList();

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    const orange = Color(0xFFE85D04);
    final compact = MediaQuery.sizeOf(context).width < 480;
    const categories = [
      (
        'Quick Actions',
        'Shortcuts and common settings',
        CupertinoIcons.square_grid_2x2,
        orange,
      ),
      (
        'Store',
        'Store details, GST, business settings',
        CupertinoIcons.building_2_fill,
        orange,
      ),
      (
        'Register',
        'Register and payment settings',
        CupertinoIcons.creditcard,
        Color(0xFF7736C9),
      ),
      (
        'Display',
        'Screen, themes and display options',
        CupertinoIcons.desktopcomputer,
        Color(0xFF087EED),
      ),
      (
        'Security',
        'PIN, permissions and access control',
        CupertinoIcons.shield,
        Color(0xFF15962C),
      ),
      (
        'Device',
        'Hardware, printers and peripherals',
        CupertinoIcons.device_phone_portrait,
        Color(0xFF087EED),
      ),
      (
        'Support',
        'Help, diagnostics and remote support',
        CupertinoIcons.headphones,
        Color(0xFFE33145),
      ),
      (
        'Account',
        'Your profile and subscription',
        CupertinoIcons.person,
        Color(0xFF7736C9),
      ),
    ];
    return ColoredBox(
      color: PosTheme.canvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SettingsIcon(
                      icon: CupertinoIcons.gear_alt_fill,
                      color: orange,
                      size: compact ? 32 : 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: compact ? 17 : 19,
                          fontWeight: FontWeight.w600,
                          color: PosTheme.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: !_loaded
                          ? null
                          : () => setState(() => _customizing = !_customizing),
                      icon: const Icon(
                        CupertinoIcons.slider_horizontal_3,
                        size: 16,
                      ),
                      label: Text(_customizing ? 'Done' : 'Customize'),
                      style: TextButton.styleFrom(
                        foregroundColor: orange,
                        backgroundColor: orange.withValues(alpha: .13),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(CupertinoIcons.xmark, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your POS, store and device settings',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color.lerp(PosTheme.inkMuted, PosTheme.ink, .3)!,
                  ),
                ),
                const SizedBox(height: 14),
                if (_customizing) ...[
                  Text(
                    'Choose which actions appear in Settings.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color.lerp(PosTheme.inkMuted, PosTheme.ink, .3)!,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                for (var i = 0; i < categories.length; i++)
                  if (_items(i).isNotEmpty) ...[
                    _SettingsCategory(
                      title: categories[i].$1,
                      subtitle: categories[i].$2,
                      icon: categories[i].$3,
                      color: categories[i].$4,
                      expanded: _customizing || _expanded.contains(i),
                      onTap: () => setState(() {
                        if (!_expanded.add(i)) _expanded.remove(i);
                      }),
                    ),
                    if (_customizing || _expanded.contains(i))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: PosTheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: PosTheme.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var j = 0; j < _items(i).length; j++) ...[
                                if (j > 0)
                                  Divider(
                                    height: 1,
                                    indent: 64,
                                    color: PosTheme.border,
                                  ),
                                ListTile(
                                  leading: _SettingsIcon(
                                    icon: _items(i)[j].icon,
                                    color: Color.lerp(
                                      PosTheme.inkMuted,
                                      PosTheme.ink,
                                      .3,
                                    )!,
                                    size: 32,
                                  ),
                                  title: Text(
                                    _items(i)[j].label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: _items(i)[j].subtitle == null
                                      ? null
                                      : Text(_items(i)[j].subtitle!),
                                  trailing: _customizing
                                      ? Checkbox(
                                          value: !_hidden.contains(
                                            _items(i)[j].id,
                                          ),
                                          onChanged: (_) =>
                                              _toggleItem(_items(i)[j].id),
                                        )
                                      : const Icon(
                                          CupertinoIcons.chevron_right,
                                          size: 20,
                                        ),
                                  enabled: _customizing || _items(i)[j].enabled,
                                  onTap: _customizing
                                      ? () => _toggleItem(_items(i)[j].id)
                                      : _items(i)[j].enabled
                                      ? () => onSelected(_items(i)[j].id)
                                      : null,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                const SizedBox(height: 4),
                _SettingsCategory(
                  title: 'Sign out',
                  icon: CupertinoIcons.square_arrow_right,
                  color: const Color(0xFFD91616),
                  destructive: true,
                  onTap: () => onSelected('logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({
    required this.icon,
    required this.color,
    this.size = 36,
  });
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: size * .55),
  );
}

class _SettingsCategory extends StatelessWidget {
  const _SettingsCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.expanded = false,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool destructive;
  final bool expanded;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Material(
      color: destructive ? color.withValues(alpha: .035) : PosTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: destructive ? color.withValues(alpha: .2) : PosTheme.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              _SettingsIcon(icon: icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: destructive ? color : PosTheme.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color.lerp(
                            PosTheme.inkMuted,
                            PosTheme.ink,
                            .3,
                          )!,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                expanded
                    ? CupertinoIcons.chevron_down
                    : CupertinoIcons.chevron_right,
                color: Color.lerp(PosTheme.inkMuted, PosTheme.ink, .3)!,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
      (Icons.point_of_sale_outlined, 'POS'),
      (Icons.receipt_long_outlined, 'Orders'),
      (Icons.flare_rounded, 'AI'),
      (CupertinoIcons.list_bullet_below_rectangle, 'Menu'),
      (CupertinoIcons.chart_pie, 'Reports'),
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
        color: Colors.transparent,
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
                  backgroundColor: const Color(0xFFD91616),
                  label: Text(
                    '${badge ?? 0}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: label == 'AI'
                      ? _AiOrb(active: selected)
                      : Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
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

/// Small glass orb for the AI tab, in the same box as the other icons.
class _AiOrb extends StatefulWidget {
  const _AiOrb({required this.active});

  final bool active;

  @override
  State<_AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<_AiOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(28, 28),
          painter: _AiOrbPainter(t: _motion.value, active: widget.active),
        );
      },
    );
  }
}

class _AiOrbPainter extends CustomPainter {
  _AiOrbPainter({required this.t, required this.active});

  final double t;
  final bool active;

  static const _green = Color(0xFF3DDC8C);
  static const _cyan = Color(0xFF3EE0FF);
  static const _blue = Color(0xFF2F7BFF);
  static const _purple = Color(0xFFB07CFF);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Offset.zero & size;
    final turn = t * math.pi * 2;
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(turn),
          colors: const [_green, _cyan, _blue, _purple, _green],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center.translate(
        math.sin(turn) * radius * 0.12,
        math.cos(turn) * radius * 0.08,
      ),
      radius * 0.78,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF8FD4FF), _blue, _blue.withValues(alpha: 0)],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    for (var i = 0; i < 5; i++) {
      final angle = turn * 0.55 + i * 1.25;
      final orbit = radius * (0.22 + (i % 3) * 0.16);
      final spark =
          center +
          Offset(
            math.cos(angle) * orbit,
            math.sin(angle * 0.85) * orbit * 0.72,
          );
      final twinkle = (math.sin(turn * 2 + i) + 1) / 2;
      canvas.drawCircle(
        spark,
        0.55,
        Paint()..color = Colors.white.withValues(alpha: 0.25 + twinkle * 0.75),
      );
    }
    canvas.drawCircle(
      center.translate(0, -radius * 0.34),
      radius * 0.4,
      Paint()
        ..color = Colors.white.withValues(alpha: active ? 0.32 : 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: active ? 0.92 : 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _AiOrbPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.active != active;
}
