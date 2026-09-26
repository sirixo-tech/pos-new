import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_catalog_layout_settings.dart';
import '../providers/pos_category_bar_settings.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/pos_layout.dart';
import 'pos_cart_panel.dart';
import 'pos_category_rail.dart';
import 'pos_menu_item_card.dart';
import 'pos_overlay.dart';
import 'pos_ui.dart';

/// Shared register ordering surface: category rail + menu grid + cart panel.
/// Used by [PosShell] and waiter Start order so both match visually.
class PosRegisterWorkspace extends StatefulWidget {
  const PosRegisterWorkspace({
    super.key,
    required this.searchController,
    required this.onItemTap,
    required this.onPay,
    this.onPark,
    this.searchFocus,
    this.primaryLabel,
    this.primaryIcon,
    this.primaryColor,
    this.lockServiceContext = false,
  });

  final TextEditingController searchController;
  final FocusNode? searchFocus;
  final ValueChanged<MenuItem> onItemTap;
  final VoidCallback onPay;
  final VoidCallback? onPark;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final Color? primaryColor;
  final bool lockServiceContext;

  @override
  State<PosRegisterWorkspace> createState() => _PosRegisterWorkspaceState();
}

class _PosRegisterWorkspaceState extends State<PosRegisterWorkspace> {
  bool _cartOpen = false;

  Future<void> _openCart() async {
    if (_cartOpen) return;
    setState(() => _cartOpen = true);
    await showPosBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return SizedBox(
          height: posMobileSheetHeight(sheetContext),
          child: _MobileCartSheet(
            onClose: () => Navigator.of(sheetContext).pop(),
            onPay: () {
              Navigator.of(sheetContext).maybePop();
              widget.onPay();
            },
            onPark: widget.onPark == null
                ? null
                : () {
                    Navigator.of(sheetContext).maybePop();
                    widget.onPark!();
                  },
            primaryLabel: widget.primaryLabel,
            primaryIcon: widget.primaryIcon,
            primaryColor: widget.primaryColor,
            lockServiceContext: widget.lockServiceContext,
          ),
        );
      },
    );
    if (mounted) setState(() => _cartOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final accent = Theme.of(context).colorScheme.primary;
    final desktop = usePosDesktopLayout(context);

    return Stack(
      children: [
        desktop ? _desktopLayout(accent) : _phoneLayout(accent),
        if (!desktop && !_cartOpen)
          Positioned(
            right: 16,
            bottom: 16,
            child: _ViewCartPillHost(
              accent: accent,
              onTap: _openCart,
            ),
          ),
      ],
    );
  }

  Widget _desktopLayout(Color accent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = PosTheme.isShort(context);
        final categoriesOnTop =
            context.select((PosCategoryBarSettings s) => s.isTop);
        final cartWidth = (constraints.maxWidth * 0.40).clamp(
          short ? 280.0 : 320.0,
          PosTheme.cartPanelWidth,
        );
        final compactCart = short || cartWidth < 340;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!categoriesOnTop)
              _PosCategoryRailHost(
                accent: accent,
                searchController: widget.searchController,
              ),
            Expanded(
              child: _menuColumn(
                accent,
                categoriesOnTop: categoriesOnTop,
              ),
            ),
            SizedBox(
              width: cartWidth,
              child: PosCartPanel(
                compact: compactCart,
                onPay: widget.onPay,
                onPark: widget.onPark,
                primaryLabel: widget.primaryLabel,
                primaryIcon: widget.primaryIcon,
                primaryColor: widget.primaryColor,
                lockServiceContext: widget.lockServiceContext,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _phoneLayout(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PosCategoryRailHost(
          accent: accent,
          searchController: widget.searchController,
          horizontal: true,
        ),
        Expanded(child: _menuColumn(accent)),
      ],
    );
  }

  Widget _menuColumn(Color accent, {bool categoriesOnTop = false}) {
    return ColoredBox(
      color: PosTheme.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchStrip(
            controller: widget.searchController,
            focusNode: widget.searchFocus,
            onChanged: (q) => context.read<PosController>().setSearchQuery(q),
            onClear: () {
              widget.searchController.clear();
              context.read<PosController>().setSearchQuery('');
            },
            onSubmitted: (value) {
              final pos = context.read<PosController>();
              final match = pos.matchBarcode(value);
              if (match == null) return;
              widget.searchController.clear();
              pos.setSearchQuery('');
              final variant = match.variant;
              if (variant != null && match.item.modifiers.isEmpty) {
                pos.addToCart(
                  CartLine(menuItem: match.item, variant: variant),
                );
                return;
              }
              widget.onItemTap(match.item);
            },
          ),
          if (categoriesOnTop)
            _PosCategoryRailHost(
              accent: accent,
              searchController: widget.searchController,
              horizontal: true,
            ),
          Expanded(
            child: _MenuScrollBody(
              accent: accent,
              onItemTap: widget.onItemTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosCategoryRailHost extends StatelessWidget {
  const _PosCategoryRailHost({
    required this.accent,
    required this.searchController,
    this.horizontal = false,
  });

  final Color accent;
  final TextEditingController searchController;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final categories = context.select((PosController p) => p.categories);
    final activeCategoryId =
        context.select((PosController p) => p.activeCategoryId);
    final searchActive =
        context.select((PosController p) => p.searchQuery.isNotEmpty);
    final serverUrl = context.select(
      (PosController p) => p.serverUrl ?? p.session?.serverUrl,
    );
    final showCategoryImages = context.select(
      (PosCatalogLayoutSettings s) => s.showsCategoryImages,
    );

    return PosCategoryRail(
      categories: categories,
      activeCategoryId: activeCategoryId,
      accent: accent,
      serverUrl: serverUrl,
      showImages: showCategoryImages,
      horizontal: horizontal,
      searchActive: searchActive,
      onSelect: (id) {
        searchController.clear();
        final pos = context.read<PosController>();
        pos.setSearchQuery('');
        pos.selectCategory(id);
      },
    );
  }
}

class _SearchStrip extends StatefulWidget {
  const _SearchStrip({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.onSubmitted,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_SearchStrip> createState() => _SearchStripState();
}

class _SearchStripState extends State<_SearchStrip> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      widget.onChanged(value);
    });
  }

  void _onClear() {
    _debounce?.cancel();
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(
          bottom: BorderSide(color: PosTheme.border.withValues(alpha: 0.9)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PosSearchField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: _onQueryChanged,
            onClear: _onClear,
            onSubmitted: widget.onSubmitted,
          ),
        ],
      ),
    );
  }
}

class _MenuScrollBody extends StatelessWidget {
  const _MenuScrollBody({
    required this.accent,
    required this.onItemTap,
  });

  final Color accent;
  final ValueChanged<MenuItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final menuEmpty = context.select((PosController p) => p.menuItemsEmpty);
    final showPopular =
        context.select((PosController p) => p.showPopularStrip);
    final searchQuery = context.select((PosController p) => p.searchQuery);
    final items = context.select((PosController p) => p.itemsToDisplay);
    final popularItems = context.select((PosController p) => p.popularItems);
    final currency = context.select((PosController p) => p.currency);
    final serverUrl = context.select(
      (PosController p) => p.serverUrl ?? p.session?.serverUrl,
    );
    final categoryTitle =
        context.select((PosController p) => p.activeCategoryTitle);
    final categorySubtitle =
        context.select((PosController p) => p.activeCategorySubtitle);
    final cartQty =
        context.select((PosController p) => p.cartQtyByMenuItemId);
    final simpleLines =
        context.select((PosController p) => p.simpleCartLineByMenuItemId);
    final showItemImages = context.select(
      (PosCatalogLayoutSettings s) => s.showsItemImages,
    );
    final pos = context.read<PosController>();

    if (menuEmpty) {
      return PosEmptyState(
        icon: Icons.search_off_rounded,
        title: context.l10n.menuNoItemsTitle,
        subtitle: context.l10n.menuNoItemsSubtitle,
        accent: accent,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final paneWidth = constraints.maxWidth;
        final crossAxisCount = posMenuGridCrossAxisCount(paneWidth);

        return CustomScrollView(
          slivers: [
            if (showPopular)
              SliverToBoxAdapter(
                child: _PopularSection(
                  items: popularItems,
                  currency: currency,
                  accent: accent,
                  serverUrl: serverUrl,
                  onTap: onItemTap,
                  qtyByItemId: cartQty,
                  simpleLineByItemId: simpleLines,
                  onIncrementSimple: pos.incrementSimpleCartLine,
                  onDecrementSimple: pos.decrementSimpleCartLine,
                  showImage: showItemImages,
                ),
              ),
            if (searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    context.l10n.menuSearchResults(searchQuery),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: PosTheme.ink,
                    ),
                  ),
                ),
              ),
            if (searchQuery.isEmpty && items.isNotEmpty)
              SliverToBoxAdapter(
                child: _CategorySectionHeader(
                  categoryName: categoryTitle,
                  subtitle: categorySubtitle,
                ),
              ),
            if (items.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: posMenuGridChildAspectRatio(
                      paneWidth,
                      compact: true,
                      images: showItemImages,
                    ),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return PosMenuItemCard(
                        key: ValueKey(item.id),
                        item: item,
                        currency: currency,
                        accent: accent,
                        compact: true,
                        serverUrl: serverUrl,
                        showImage: showItemImages,
                        inTicketQty: cartQty[item.id] ?? 0,
                        simpleCartLine: simpleLines[item.id],
                        onTap: () => onItemTap(item),
                        onIncrementSimple: pos.incrementSimpleCartLine,
                        onDecrementSimple: pos.decrementSimpleCartLine,
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PopularSection extends StatelessWidget {
  const _PopularSection({
    required this.items,
    required this.currency,
    required this.accent,
    required this.onTap,
    required this.qtyByItemId,
    required this.simpleLineByItemId,
    required this.onIncrementSimple,
    required this.onDecrementSimple,
    this.serverUrl,
    this.showImage = true,
  });

  final List<MenuItem> items;
  final String currency;
  final Color accent;
  final ValueChanged<MenuItem> onTap;
  final Map<int, int> qtyByItemId;
  final Map<int, CartLine?> simpleLineByItemId;
  final ValueChanged<CartLine> onIncrementSimple;
  final ValueChanged<CartLine> onDecrementSimple;
  final String? serverUrl;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    final short = PosTheme.isShort(context);
    final stripHeight = showImage
        ? (short ? 148.0 : 200.0)
        : (short ? 148.0 : 168.0);
    final cardWidth = short ? 120.0 : 144.0;
    final pad = short
        ? const EdgeInsets.fromLTRB(12, 8, 12, 10)
        : const EdgeInsets.fromLTRB(16, 12, 16, 16);

    final soft = posAccentSoft(accent);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, short ? 4 : 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: soft.bg,
          borderRadius: BorderRadius.circular(PosTheme.radiusLg),
          border: Border.all(color: soft.fg.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: short ? 28 : 36,
                    height: short ? 28 : 36,
                    decoration: BoxDecoration(
                      color: soft.bg,
                      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
                      border: Border.all(color: soft.fg.withValues(alpha: 0.28)),
                    ),
                    child: Icon(
                      Icons.trending_up_rounded,
                      size: short ? 14 : 18,
                      color: soft.fg,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.menuPopularTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: PosTheme.ink,
                          ),
                        ),
                        if (!short)
                          Text(
                            context.l10n.menuPopularSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: PosTheme.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: short ? 8 : 12),
              SizedBox(
                height: stripHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => SizedBox(width: short ? 12 : 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return SizedBox(
                      width: cardWidth,
                      height: stripHeight,
                      child: PosMenuItemCard(
                        key: ValueKey('popular-${item.id}'),
                        item: item,
                        currency: currency,
                        accent: accent,
                        serverUrl: serverUrl,
                        showImage: showImage,
                        compact: true,
                        inTicketQty: qtyByItemId[item.id] ?? 0,
                        simpleCartLine: simpleLineByItemId[item.id],
                        onTap: () => onTap(item),
                        onIncrementSimple: onIncrementSimple,
                        onDecrementSimple: onDecrementSimple,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader({
    required this.categoryName,
    required this.subtitle,
  });

  final String categoryName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PosTheme.searchFill,
              borderRadius: BorderRadius.circular(PosTheme.radiusMd),
              border: Border.all(color: PosTheme.border),
            ),
            child: Icon(Icons.grid_view_rounded, size: 18, color: PosTheme.inkMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: PosTheme.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: PosTheme.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewCartPillHost extends StatelessWidget {
  const _ViewCartPillHost({
    required this.accent,
    required this.onTap,
  });

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = context.select((PosController p) => p.cartItemCount);
    if (count <= 0) return const SizedBox.shrink();
    return _ViewCartPill(
      count: count,
      accent: accent,
      onTap: onTap,
    );
  }
}

class _ViewCartPill extends StatelessWidget {
  const _ViewCartPill({
    required this.count,
    required this.accent,
    required this.onTap,
  });

  final int count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: accent.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(999),
      color: accent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_cart_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                context.l10n.shellViewCart,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
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

class _MobileCartSheet extends StatelessWidget {
  const _MobileCartSheet({
    required this.onClose,
    required this.onPay,
    this.onPark,
    this.primaryLabel,
    this.primaryIcon,
    this.primaryColor,
    this.lockServiceContext = false,
  });

  final VoidCallback onClose;
  final VoidCallback onPay;
  final VoidCallback? onPark;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final Color? primaryColor;
  final bool lockServiceContext;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final l10n = context.l10n;

    return PosBottomSheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: soft.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shopping_bag_rounded,
                    color: soft.fg,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.cartCurrentTicket,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                  ),
                ),
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
            child: PosCartPanel(
              compact: true,
              onPay: onPay,
              onPark: onPark,
              primaryLabel: primaryLabel,
              primaryIcon: primaryIcon,
              primaryColor: primaryColor,
              lockServiceContext: lockServiceContext,
            ),
          ),
        ],
      ),
    );
  }
}
