import 'dart:async';

import 'package:flutter/material.dart';

import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../theme/pos_theme.dart';
import '../utils/order_cancel_reasons.dart';
import '../utils/pos_user_facing_error.dart';
import 'pos_auth_hero_panel.dart';
import 'pos_navigator.dart';
import 'pos_network_logo.dart';
import 'pos_platform_logo.dart';
import 'pos_powered_by.dart';

class PosPrimaryButton extends StatelessWidget {
  const PosPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.color,
    this.glow = true,
    this.shortcutLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final Color? color;
  final bool glow;

  /// Optional keyboard hint (e.g. `F3`) shown beside the label.
  final String? shortcutLabel;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    final enabled = onPressed != null && !loading;

    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        gradient: enabled ? PosTheme.ctaGradient(accent) : null,
        color: enabled ? null : PosTheme.inkFaint,
        boxShadow: enabled && glow ? PosTheme.buttonShadow(accent) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(PosTheme.radiusMd),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final narrow = w < 140;
              final showShortcut = shortcutLabel != null &&
                  shortcutLabel!.isNotEmpty &&
                  w >= 160;
              final showLabel = w >= 72;

              final child = loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: narrow ? 18 : 20),
                            if (showLabel) SizedBox(width: narrow ? 5 : 8),
                          ],
                          if (showLabel)
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                                fontSize: narrow ? 13.5 : 15,
                              ),
                            ),
                          if (showShortcut) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Text(
                                shortcutLabel!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Colors.white.withValues(alpha: 0.92),
                                  letterSpacing: 0.2,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );

              return Container(
                constraints: const BoxConstraints(minHeight: 50),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: narrow ? 8 : 18,
                  vertical: 12,
                ),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: IconTheme(
                    data: const IconThemeData(color: Colors.white),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class PosSurfaceCard extends StatelessWidget {
  const PosSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.accentBorder = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool accentBorder;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(
          color: accentBorder
              ? accent.withValues(alpha: 0.35)
              : PosTheme.border,
        ),
        boxShadow: PosTheme.cardShadow(),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        child: card,
      ),
    );
  }
}

class PosBrandPanel extends StatelessWidget {
  const PosBrandPanel({
    super.key,
    required this.accent,
    this.title,
    this.subtitle,
    this.icon = Icons.point_of_sale_rounded,
    this.brandMark,
    this.brandBody,
    this.footer,
  });

  final Color accent;
  final String? title;
  final String? subtitle;
  final IconData icon;
  /// Optional platform logo / mark shown above the title (e.g. lock screen).
  final Widget? brandMark;
  /// Optional middle content between title block and footer (fills tall panels).
  final Widget? brandBody;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: PosTheme.brandGradient(accent)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (brandMark != null)
                brandMark!
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: PosTheme.buttonShadow(accent),
                  ),
                  child: Icon(icon, color: Colors.white, size: 36),
                ),
              const Spacer(flex: 2),
              Text(
                title ?? PosAppInfo.displayName,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle ?? context.l10n.brandTagline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.45,
                    ),
              ),
              if (brandBody != null) ...[
                const SizedBox(height: 28),
                brandBody!,
                const Spacer(flex: 3),
              ] else
                const Spacer(flex: 3),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}

class PosEmptyState extends StatelessWidget {
  const PosEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(color);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;
        final tightHeight = maxH.isFinite && maxH < 220;
        final veryTight = maxH.isFinite && maxH < 140;
        final iconBox = veryTight ? 40.0 : (tightHeight ? 52.0 : 72.0);
        final iconGlyph = veryTight ? 20.0 : (tightHeight ? 26.0 : 34.0);
        final pad = veryTight ? 8.0 : (tightHeight ? 12.0 : 24.0);
        final gapAfterIcon = veryTight ? 8.0 : (tightHeight ? 10.0 : 18.0);

        final content = Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: soft.bg,
                  shape: BoxShape.circle,
                  boxShadow: veryTight ? null : PosTheme.cardShadow(color),
                ),
                child: Icon(icon, size: iconGlyph, color: soft.fg),
              ),
              SizedBox(height: gapAfterIcon),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: tightHeight ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: (tightHeight
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null && !veryTight) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: tightHeight ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (action != null && !veryTight) ...[
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        );

        final bounded = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxW.isFinite ? maxW.clamp(0, 320) : 320,
          ),
          child: content,
        );

        // Scale down rather than yellow-stripe when the cart pane is short/narrow.
        if (maxH.isFinite && maxH > 0) {
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: bounded,
            ),
          );
        }

        return Center(child: bounded);
      },
    );
  }
}

class PosStatusChip extends StatelessWidget {
  const PosStatusChip({
    super.key,
    required this.label,
    this.status,
    this.accent,
  });

  final String label;
  final String? status;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = posStatusColors(
      status,
      accent: accent ?? Theme.of(context).colorScheme.primary,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
        border: PosTheme.isDark
            ? Border.all(color: colors.fg.withValues(alpha: 0.28))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Login-style chrome for pre-shell auth / onboarding screens.
///
/// Restaurant (or platform) branding in the hero/header; “Powered by” sits
/// under the login form when restaurant branding is shown.
class PosAuthScaffold extends StatelessWidget {
  const PosAuthScaffold({
    super.key,
    required this.accent,
    required this.form,
    required this.statusLabel,
    required this.statusIcon,
    required this.headline,
    this.platform,
    this.serverUrl,
    this.logoUrl,
    this.locationLine,
    this.personLabel,
    this.personInitial,
    this.now,
    this.fallbackInitials = 'P',
    this.fallbackIcon = Icons.point_of_sale_rounded,
    this.footerNote,
    this.showClock = true,
    this.compactHeader,
    this.maxFormWidth = 400,
  });

  final Color accent;
  final Widget form;
  final String statusLabel;
  final IconData statusIcon;
  final String headline;
  final PosPlatformBranding? platform;
  final String? serverUrl;
  /// Restaurant logo URL only — do not pass the platform logo here.
  final String? logoUrl;
  final String? locationLine;
  final String? personLabel;
  final String? personInitial;
  final DateTime? now;
  final String fallbackInitials;
  final IconData fallbackIcon;
  final String? footerNote;
  final bool showClock;
  /// Override for the narrow layout header.
  final Widget? compactHeader;
  final double maxFormWidth;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final hasRestaurantLogo = logoUrl != null && logoUrl!.isNotEmpty;
    final header = compactHeader ??
        (hasRestaurantLogo
            ? _CompactRestaurantMark(
                logoUrl: logoUrl!,
                fallbackInitials: fallbackInitials,
                accent: accent,
              )
            : PosPlatformLogo(
                platform: platform,
                serverUrl: serverUrl,
                height: 72,
                maxWidth: 300,
              ));

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: PosAuthHeroPanel(
                accent: accent,
                statusIcon: statusIcon,
                statusLabel: statusLabel,
                logoUrl: logoUrl,
                headline: headline,
                locationLine: locationLine,
                personLabel: personLabel,
                personInitial: personInitial,
                now: now,
                fallbackInitials: fallbackInitials,
                fallbackIcon: fallbackIcon,
                footerNote: footerNote,
                showClock: showClock,
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                color: PosTheme.canvas,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxFormWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!hasRestaurantLogo) ...[
                              PosPlatformLogo(
                                platform: platform,
                                serverUrl: serverUrl,
                                height: 72,
                                maxWidth: 300,
                              ),
                              const SizedBox(height: 22),
                            ],
                            form,
                            if (hasRestaurantLogo) ...[
                              const SizedBox(height: 20),
                              PosPoweredBy(
                                platform: platform,
                                serverUrl: serverUrl,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: PosTheme.softCanvasGradient(accent),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(PosTheme.isCompact(context) ? 16 : 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxFormWidth.clamp(400, 460)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    header,
                    const SizedBox(height: 16),
                    form,
                    if (hasRestaurantLogo) ...[
                      const SizedBox(height: 20),
                      PosPoweredBy(
                        platform: platform,
                        serverUrl: serverUrl,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactRestaurantMark extends StatelessWidget {
  const _CompactRestaurantMark({
    required this.logoUrl,
    required this.fallbackInitials,
    required this.accent,
  });

  final String logoUrl;
  final String fallbackInitials;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosTheme.logoPlate,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.logoPlateBorder),
        boxShadow: PosTheme.cardShadow(accent),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: PosNetworkLogo(
          imageUrl: logoUrl,
          maxWidth: 192,
          maxHeight: 36,
          portraitSide: 56,
          alignment: Alignment.centerLeft,
          errorWidget: (context, url, error) => Text(
            fallbackInitials,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft selectable row used on context / terminal pickers.
class PosSelectTile extends StatelessWidget {
  const PosSelectTile({
    super.key,
    required this.title,
    required this.onTap,
    this.selected = false,
    this.subtitle,
    this.leading,
    this.enabled = true,
    this.trailing = PosSelectTileTrailing.check,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final bool enabled;
  final PosSelectTileTrailing trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final highlighted =
        selected || trailing == PosSelectTileTrailing.chevron;

    return Material(
      color: selected ? soft.bg : PosTheme.surface,
      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusMd),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.45)
                  : PosTheme.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: highlighted && selected
                ? PosTheme.cardShadow(accent)
                : null,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: selected ? soft.fg : PosTheme.ink,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? soft.fg.withValues(alpha: 0.85)
                              : PosTheme.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                trailing == PosSelectTileTrailing.chevron
                    ? Icons.chevron_right_rounded
                    : (selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined),
                size: 22,
                color: selected || trailing == PosSelectTileTrailing.chevron
                    ? accent
                    : PosTheme.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum PosSelectTileTrailing { check, chevron }

class PosSearchField extends StatefulWidget {
  const PosSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.onClear,
    this.onSubmitted,
    this.onScan,
    this.onHeldQr,
    this.heldQrLabel,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onHeldQr;
  final String? heldQrLabel;
  final VoidCallback? onScan;
  final FocusNode? focusNode;

  @override
  State<PosSearchField> createState() => _PosSearchFieldState();
}

class _PosSearchFieldState extends State<PosSearchField> {
  late FocusNode _focusNode;
  bool _ownedFocus = false;

  @override
  void initState() {
    super.initState();
    _ownedFocus = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocus);
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant PosSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocus);
      if (_ownedFocus) {
        _focusNode.dispose();
      }
      _ownedFocus = widget.focusNode == null;
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focusNode.removeListener(_onFocus);
    if (_ownedFocus) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final hasText = widget.controller.text.isNotEmpty;
    final focused = _focusNode.hasFocus;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final l10n = context.l10n;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 48,
      decoration: BoxDecoration(
        color: focused ? PosTheme.surface : PosTheme.searchFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? accent.withValues(alpha: 0.55)
              : PosTheme.border.withValues(alpha: 0.95),
          width: focused ? 1.5 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: focused
                  ? soft.bg
                  : PosTheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: focused
                    ? accent.withValues(alpha: 0.22)
                    : PosTheme.border.withValues(alpha: 0.8),
              ),
            ),
            child: Icon(
              Icons.search_rounded,
              size: 18,
              color: focused ? soft.fg : PosTheme.inkMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: PosTheme.ink,
                height: 1.2,
              ),
              cursorColor: accent,
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.hintText ?? l10n.menuSearchHint,
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: PosTheme.inkFaint.withValues(alpha: 0.95),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (hasText)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: PosTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: widget.onClear,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.onHeldQr != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: context.posText(
                  'qrPendingShortcut',
                  'Show the held UPI QR',
                ),
                child: Material(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: widget.onHeldQr,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 32,
                      constraints: const BoxConstraints(maxWidth: 148),
                      padding: EdgeInsets.symmetric(horizontal: wide ? 10 : 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF059669).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.qr_code_2_rounded,
                            size: 16,
                            color: Color(0xFF047857),
                          ),
                          if (wide &&
                              (widget.heldQrLabel?.trim().isNotEmpty ??
                                  false)) ...[
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 96),
                              child: Text(
                                widget.heldQrLabel!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.onScan != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: l10n.menuBarcodeTooltip,
                child: Material(
                  color: focused
                      ? soft.bg
                      : PosTheme.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: widget.onScan,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 32,
                      padding: EdgeInsets.symmetric(horizontal: wide ? 10 : 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: focused
                              ? accent.withValues(alpha: 0.2)
                              : PosTheme.border.withValues(alpha: 0.85),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 16,
                            color: focused ? soft.fg : PosTheme.inkMuted,
                          ),
                          if (wide) ...[
                            const SizedBox(width: 6),
                            Text(
                              l10n.menuScan,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: focused ? soft.fg : PosTheme.inkMuted,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

OverlayEntry? _posToastEntry;
Timer? _posToastTimer;

/// Compact top-center toast for POS (keeps cart / keypad clear).
void showPosSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
  Duration duration = const Duration(seconds: 2, milliseconds: 800),
}) {
  // Drop any legacy bottom snackbars so they don't stack under the toast.
  ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
  _dismissPosToast();

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final accent = Theme.of(context).colorScheme.primary;
  final media = MediaQuery.of(context);
  final top = media.padding.top + 12;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return _PosToast(
        top: top,
        message: message,
        error: error,
        accent: accent,
        onDismiss: () {
          if (_posToastEntry == entry) {
            _dismissPosToast();
          }
        },
      );
    },
  );

  _posToastEntry = entry;
  overlay.insert(entry);
  _posToastTimer = Timer(duration, () {
    if (_posToastEntry == entry) {
      _dismissPosToast();
    }
  });
}

/// Error toast with staff-safe copy (no URLs, API paths, or raw exceptions).
void showPosErrorSnackBar(BuildContext context, Object error) {
  showPosSnackBar(
    context,
    posUserFacingError(error),
    error: true,
  );
}

void _dismissPosToast() {
  _posToastTimer?.cancel();
  _posToastTimer = null;
  _posToastEntry?.remove();
  _posToastEntry = null;
}

class _PosToast extends StatefulWidget {
  const _PosToast({
    required this.top,
    required this.message,
    required this.error,
    required this.accent,
    required this.onDismiss,
  });

  final double top;
  final String message;
  final bool error;
  final Color accent;
  final VoidCallback onDismiss;

  @override
  State<_PosToast> createState() => _PosToastState();
}

class _PosToastState extends State<_PosToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.18),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    try {
      await _controller.reverse();
    } catch (_) {
      // Controller may already be disposed if overlay was removed.
    }
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.error ? const Color(0xFFDC2626) : widget.accent;
    final iconBg = widget.error
        ? (PosTheme.isDark
            ? const Color(0xFF4C0519)
            : const Color(0xFFFEE2E2))
        : posAccentSoft(widget.accent).bg;
    final icon =
        widget.error ? Icons.error_outline_rounded : Icons.check_circle_rounded;
    final borderColor =
        widget.error ? const Color(0xFFFECACA) : PosTheme.border;

    return Positioned(
      top: widget.top,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: Dismissible(
                  key: const ValueKey('pos-toast'),
                  direction: DismissDirection.up,
                  onDismissed: (_) => widget.onDismiss(),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: PosTheme.surface,
                      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(icon, color: iconColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: PosTheme.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _close,
                          tooltip: context.l10n.commonDismiss,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: PosTheme.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared chrome for POS dialogs (header strip + body + footer).
class PosDialogShell extends StatelessWidget {
  const PosDialogShell({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.icon = Icons.info_outline_rounded,
    this.headerColor,
    this.footer,
    this.maxWidth = 420,
    this.onClose,
    /// Fill a side panel / bottom sheet instead of a centered [Dialog].
    this.embedded = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? headerColor;
  final Widget body;
  final Widget? footer;
  final double maxWidth;
  final VoidCallback? onClose;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final accent = headerColor ?? Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final media = MediaQuery.sizeOf(context);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    if (embedded) {
      // Match cart / reports bottom-sheet chrome (not dialog gradient).
      return Material(
        color: PosTheme.canvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: soft.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: soft.fg, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: PosTheme.ink,
                                  ),
                        ),
                        if (hasSubtitle) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: PosTheme.inkMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onClose != null)
                    Material(
                      color: soft.bg,
                      borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                      child: InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.close_rounded,
                            color: soft.fg,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  12 + MediaQuery.viewInsetsOf(context).bottom.clamp(0, 24),
                ),
                child: body,
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: PosTheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: PosTheme.border.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                child: footer,
              ),
          ],
        ),
      );
    }

    final content = Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            decoration: BoxDecoration(
              gradient: PosTheme.modalHeaderGradient(seed: accent),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: soft.fg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    tooltip: context.l10n.commonClose,
                    color: Colors.white,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: body,
            ),
          ),
          if (footer != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: PosTheme.canvas,
                border: Border(
                  top: BorderSide(
                    color: PosTheme.border.withValues(alpha: 0.9),
                  ),
                ),
              ),
              child: footer,
            ),
        ],
      ),
    );

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: media.width < 420 ? 16 : 28,
        vertical: 24,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: media.height * 0.9,
        ),
        child: content,
      ),
    );
  }
}

/// Shared Cancel + primary action row used by confirm and admin form dialogs.
Widget posDialogActionFooter({
  required BuildContext context,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
  String? cancelLabel,
  String? confirmLabel,
  bool destructive = false,
  Color? confirmColor,
}) {
  final l10n = context.l10n;
  final accent = Theme.of(context).colorScheme.primary;
  final resolvedConfirm = confirmLabel ?? l10n.commonConfirm;
  final resolvedCancel = cancelLabel ?? l10n.commonCancel;
  final fill = confirmColor ??
      (destructive ? const Color(0xFFDC2626) : accent);

  return Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: PosTheme.inkMuted,
            side: BorderSide(color: PosTheme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            resolvedCancel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: fill,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          child: Text(resolvedConfirm),
        ),
      ),
    ],
  );
}

Future<bool> showPosConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  String? subtitle,
  IconData? icon,
}) async {
  final l10n = context.l10n;
  final accent = Theme.of(context).colorScheme.primary;
  final headerColor =
      destructive ? const Color(0xFFB91C1C) : accent;

  // Prefer the nearest navigator (e.g. lock-screen overlay). Fall back to root.
  final hasLocalNav = Navigator.maybeOf(context) != null;
  final result = await posAfterNavigatorSettled<bool>(context, (rootContext) {
    final navContext = hasLocalNav && context.mounted ? context : rootContext;
    return showDialog<bool>(
      context: navContext,
      useRootNavigator: !hasLocalNav,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => PosDialogShell(
        title: title,
        subtitle: subtitle ??
            (destructive ? l10n.confirmDestructiveSubtitle : null),
        icon: icon ??
            (destructive
                ? Icons.warning_amber_rounded
                : Icons.help_outline_rounded),
        headerColor: headerColor,
        onClose: () => Navigator.pop(ctx, false),
        body: Text(
          message,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: PosTheme.ink,
          ),
        ),
        footer: posDialogActionFooter(
          context: ctx,
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
          destructive: destructive,
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () => Navigator.pop(ctx, true),
        ),
      ),
    );
  });
  return result == true;
}

/// Result of the POS cancel-order confirmation sheet.
enum PosCancelOrderChoice {
  cancel,
  cancelAndRefund,
}

class PosCancelOrderResult {
  const PosCancelOrderResult({
    required this.choice,
    this.cancelReason,
    this.cancelNote,
  });

  final PosCancelOrderChoice choice;
  final String? cancelReason;
  final String? cancelNote;
}

/// Confirm cancelling an order. Paid/partial orders can also mark a refund.
/// Cancel reason + note are optional (older clients omit them).
Future<PosCancelOrderResult?> showPosCancelOrderDialog(
  BuildContext context, {
  required bool canRefund,
  String? amountLabel,
}) async {
  final l10n = context.l10n;
  final message = canRefund && (amountLabel ?? '').trim().isNotEmpty
      ? l10n.ordersCancelPaidMessage(amountLabel!.trim())
      : l10n.ordersCancelMessage;

  return showDialog<PosCancelOrderResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => _PosCancelOrderDialog(
      canRefund: canRefund,
      message: message,
      title: l10n.ordersCancelTitle,
      subtitle: l10n.confirmDestructiveSubtitle,
      cancelLabel: l10n.ordersCancelConfirm,
      cancelRefundLabel: l10n.ordersCancelAndRefund,
      keepLabel: l10n.ordersCancelKeep,
    ),
  );
}

/// Pick a payment method when marking an order paid.
/// [activeGatewaySlugs] should be restaurant QR gateways (e.g. phonepe, paytm).
Future<String?> showPosMarkPaidMethodDialog(
  BuildContext context, {
  Iterable<String> activeGatewaySlugs = const [],
}) async {
  String selected = 'cash';
  final methods = markPaidPaymentMethods(activeGatewaySlugs);
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return PosDialogShell(
            title: context.posText(
              'markPaidMethodTitle',
              'How did they pay?',
            ),
            subtitle: context.posText(
              'markPaidMethodDescription',
              'Select the payment method used so reports stay accurate.',
            ),
            icon: Icons.payments_outlined,
            headerColor: const Color(0xFF047857),
            body: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in methods)
                  ChoiceChip(
                    label: Text(manualPaymentMethodLabel(context, method)),
                    selected: selected == method,
                    onSelected: (_) => setLocal(() => selected = method),
                  ),
              ],
            ),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.posText('markPaidConfirm', 'Mark as paid'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: PosTheme.inkMuted,
                    side: BorderSide(color: PosTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(context.l10n.commonCancel),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _PosCancelOrderDialog extends StatefulWidget {
  const _PosCancelOrderDialog({
    required this.canRefund,
    required this.message,
    required this.title,
    required this.subtitle,
    required this.cancelLabel,
    required this.cancelRefundLabel,
    required this.keepLabel,
  });

  final bool canRefund;
  final String message;
  final String title;
  final String subtitle;
  final String cancelLabel;
  final String cancelRefundLabel;
  final String keepLabel;

  @override
  State<_PosCancelOrderDialog> createState() => _PosCancelOrderDialogState();
}

class _PosCancelOrderDialogState extends State<_PosCancelOrderDialog> {
  String? _reason;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  PosCancelOrderResult _result(PosCancelOrderChoice choice) {
    final note = _noteController.text.trim();
    return PosCancelOrderResult(
      choice: choice,
      cancelReason: _reason,
      cancelNote: note.isEmpty ? null : note,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PosDialogShell(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: Icons.warning_amber_rounded,
      headerColor: const Color(0xFFB91C1C),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.message,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.posText(
              'cancelReasonLabel',
              'Cancel reason (optional)',
            ),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PosTheme.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in kOrderCancelReasons)
                ChoiceChip(
                  label: Text(orderCancelReasonLabel(context, code)),
                  selected: _reason == code,
                  onSelected: (selected) {
                    setState(() => _reason = selected ? code : null);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: context.posText(
                'cancelNotePlaceholder',
                'Add any extra detail for the audit trail…',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.canRefund) ...[
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _result(PosCancelOrderChoice.cancelAndRefund),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              child: Text(widget.cancelRefundLabel),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.tonal(
            onPressed: () =>
                Navigator.pop(context, _result(PosCancelOrderChoice.cancel)),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: const Color(0xFFB91C1C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            child: Text(widget.cancelLabel),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: PosTheme.inkMuted,
              side: BorderSide(color: PosTheme.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              widget.keepLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dismisses the software keyboard when the pointer lands outside the
/// currently focused field — works for cart notes, search, PIN, etc.
class PosKeyboardDismiss extends StatelessWidget {
  const PosKeyboardDismiss({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final focus = FocusManager.instance.primaryFocus;
        if (focus == null || !focus.hasFocus) return;
        final box = focus.context?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) {
          focus.unfocus();
          return;
        }
        final local = box.globalToLocal(event.position);
        if (!(Offset.zero & box.size).contains(local)) {
          focus.unfocus();
        }
      },
      child: child,
    );
  }
}
