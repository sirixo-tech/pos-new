import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../services/pos_storage.dart';
import '../theme/pos_theme.dart';
import '../utils/pos_layout.dart';
import 'pos_overlay.dart';

class PosMoreMenuItem {
  const PosMoreMenuItem({
    required this.id,
    required this.icon,
    required this.label,
    this.subtitle,
    this.enabled = true,
    this.destructive = false,
    this.badge,
  });

  final String id;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool enabled;
  final bool destructive;
  final String? badge;
}

class PosMoreMenuSection {
  const PosMoreMenuSection({this.title, required this.items});

  final String? title;
  final List<PosMoreMenuItem> items;
}

/// Overflow menu: bottom sheet on phone, right side panel on wide / web.
Future<String?> showPosMoreMenu({
  required BuildContext context,
  required List<PosMoreMenuSection> sections,
  String? title,
}) {
  final side = preferPosSidePanel(context);
  final label = title ?? context.l10n.shellMore;

  return showPosOverlay<String>(
    context: context,
    sidePanelWidth: 360,
    builder: (ctx) {
      final panel = _PosMoreMenuPanel(
        sections: sections,
        title: label,
        onSelect: (id) => Navigator.of(ctx).pop(id),
        onClose: () => Navigator.of(ctx).pop(),
      );

      if (side) {
        return PosSidePanelShell(child: panel);
      }

      return PosMobileSheetFrame(maxWidth: 560, child: panel);
    },
  );
}

class _PosMoreMenuPanel extends StatefulWidget {
  const _PosMoreMenuPanel({
    required this.sections,
    required this.title,
    required this.onSelect,
    required this.onClose,
  });

  final List<PosMoreMenuSection> sections;
  final String title;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  State<_PosMoreMenuPanel> createState() => _PosMoreMenuPanelState();
}

class _PosMoreMenuPanelState extends State<_PosMoreMenuPanel> {
  final _storage = PosStorage();
  bool _customizing = false;
  Set<String> _hidden = {};
  Set<String>? _expanded;

  @override
  void initState() {
    super.initState();
    _loadHidden();
  }

  Future<void> _loadHidden() async {
    final ids = await _storage.getMoreMenuHiddenIds();
    final expanded = await _storage.getMoreMenuExpandedTitles();
    if (!mounted) return;
    setState(() {
      _hidden = ids;
      _expanded = expanded;
    });
  }

  Future<void> _toggleSection(String title, List<String> titles) async {
    final next = Set<String>.from(_expanded ?? titles);
    if (next.contains(title)) {
      next.remove(title);
    } else {
      next.add(title);
    }
    setState(() => _expanded = next);
    await _storage.saveMoreMenuExpandedTitles(next);
  }

  Future<void> _toggleHidden(String id) async {
    setState(() {
      if (_hidden.contains(id)) {
        _hidden.remove(id);
      } else {
        _hidden.add(id);
      }
    });
    await _storage.saveMoreMenuHiddenIds(_hidden);
  }

  bool _isShown(String id) {
    if (_customizing) return true;
    return !_hidden.contains(id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PosMoreMenuHeader(
          title: widget.title,
          customizing: _customizing,
          onToggleCustomize: () => setState(() => _customizing = !_customizing),
          onClose: widget.onClose,
        ),
        Expanded(
          child: _PosMoreMenuBody(
            sections: widget.sections,
            customizing: _customizing,
            hidden: _hidden,
            expanded: _customizing ? null : _expanded,
            isShown: _isShown,
            onToggleHidden: _toggleHidden,
            onToggleSection: _toggleSection,
            onSelect: widget.onSelect,
          ),
        ),
      ],
    );
  }
}

class _PosMoreMenuHeader extends StatelessWidget {
  const _PosMoreMenuHeader({
    required this.title,
    required this.customizing,
    required this.onToggleCustomize,
    required this.onClose,
  });

  final String title;
  final bool customizing;
  final VoidCallback onToggleCustomize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final soft = posAccentSoft(Theme.of(context).colorScheme.primary);

    return Padding(
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
            child: Icon(Icons.more_horiz_rounded, color: soft.fg, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: PosTheme.ink,
              ),
            ),
          ),
          Material(
            color: customizing ? soft.fg : soft.bg,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onToggleCustomize,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      customizing ? Icons.check_rounded : Icons.tune_rounded,
                      size: 15,
                      color: customizing ? Colors.white : soft.fg,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      customizing ? l10n.commonDone : l10n.shellMoreCustomize,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: customizing ? Colors.white : soft.fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: soft.bg,
            borderRadius: BorderRadius.circular(PosTheme.radiusSm),
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(PosTheme.radiusSm),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.close_rounded, color: soft.fg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosMoreMenuBody extends StatelessWidget {
  const _PosMoreMenuBody({
    required this.sections,
    required this.customizing,
    required this.hidden,
    required this.expanded,
    required this.isShown,
    required this.onToggleHidden,
    required this.onToggleSection,
    required this.onSelect,
  });

  final List<PosMoreMenuSection> sections;
  final bool customizing;
  final Set<String> hidden;
  final Set<String>? expanded;
  final bool Function(String id) isShown;
  final ValueChanged<String> onToggleHidden;
  final void Function(String title, List<String> titles) onToggleSection;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = <PosMoreMenuSection>[];
    for (final section in sections) {
      final items = section.items.where((item) => isShown(item.id)).toList();
      if (items.isEmpty) continue;
      visible.add(PosMoreMenuSection(title: section.title, items: items));
    }

    final titles = [
      for (final section in visible)
        if (section.title != null && section.title!.trim().isNotEmpty)
          section.title!,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      children: [
        if (customizing)
          Container(
            margin: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.shellMoreCustomizeHint,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (var s = 0; s < visible.length; s++) ...[
          if (s > 0) const SizedBox(height: 8),
          if (visible[s].title != null && visible[s].title!.trim().isNotEmpty)
            _MoreSectionHeading(
              title: visible[s].title!,
              expanded:
                  expanded == null || expanded!.contains(visible[s].title),
              onTap: () => onToggleSection(visible[s].title!, titles),
            ),
          if (visible[s].title == null ||
              visible[s].title!.trim().isEmpty ||
              expanded == null ||
              expanded!.contains(visible[s].title))
            DecoratedBox(
              decoration: BoxDecoration(
                color: PosTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: PosTheme.border.withValues(alpha: 0.9),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < visible[s].items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 52,
                        color: PosTheme.border.withValues(alpha: 0.75),
                      ),
                    _PosMoreMenuTile(
                      item: visible[s].items[i],
                      customizing: customizing,
                      selected: !hidden.contains(visible[s].items[i].id),
                      onToggleHidden: () =>
                          onToggleHidden(visible[s].items[i].id),
                      onTap: visible[s].items[i].enabled
                          ? () => onSelect(visible[s].items[i].id)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _MoreSectionHeading extends StatelessWidget {
  const _MoreSectionHeading({
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: PosTheme.inkFaint,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: PosTheme.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosMoreMenuTile extends StatelessWidget {
  const _PosMoreMenuTile({
    required this.item,
    required this.customizing,
    required this.selected,
    required this.onToggleHidden,
    required this.onTap,
  });

  final PosMoreMenuItem item;
  final bool customizing;
  final bool selected;
  final VoidCallback onToggleHidden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cancelTone = posStatusColors('cancelled');
    final destructive = item.destructive;
    final enabled = onTap != null;
    final fg = !enabled && !customizing
        ? PosTheme.inkFaint
        : destructive
        ? cancelTone.fg
        : PosTheme.ink;
    final iconFg = !enabled && !customizing
        ? PosTheme.inkFaint
        : destructive
        ? cancelTone.fg
        : PosTheme.inkMuted;
    final iconBg = !enabled && !customizing
        ? PosTheme.surfaceMuted
        : destructive
        ? cancelTone.bg
        : PosTheme.surfaceMuted;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: customizing ? onToggleHidden : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, size: 17, color: iconFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (item.subtitle != null &&
                        item.subtitle!.trim().isNotEmpty)
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (customizing)
                Checkbox(
                  value: selected,
                  activeColor: accent,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (_) => onToggleHidden(),
                )
              else if (item.badge != null && item.badge!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: PosTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.badge!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ),
              ] else if (enabled)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: PosTheme.inkFaint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App-bar trigger for [showPosMoreMenu].
class PosMoreMenuButton extends StatelessWidget {
  const PosMoreMenuButton({
    super.key,
    required this.accent,
    required this.tooltip,
    required this.sections,
    required this.onSelected,
    this.embedded = false,
  });

  final Color accent;
  final String tooltip;
  final List<PosMoreMenuSection> sections;
  final ValueChanged<String> onSelected;
  final bool embedded;

  Future<void> _open(BuildContext context) async {
    final selected = await showPosMoreMenu(
      context: context,
      sections: sections,
      title: tooltip,
    );
    if (selected == null) return;
    onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.more_horiz_rounded,
      size: 20,
      color: PosTheme.ink.withValues(alpha: 0.78),
    );

    if (embedded) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(context),
            hoverColor: accent.withValues(alpha: 0.08),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: usePosHandheldLayout(context) ? 12 : 10,
              ),
              child: icon,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(10),
            hoverColor: accent.withValues(alpha: 0.08),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PosTheme.border),
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}
