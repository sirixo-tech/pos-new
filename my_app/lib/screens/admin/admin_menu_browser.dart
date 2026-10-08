import 'package:flutter/material.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../theme/pos_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pos_item_type_badge.dart';
import 'admin_menu_image_picker.dart';

const _kTypeCol = 50.0;
const _kTypePriceGap = 18.0;
const _kPriceCol = 84.0;
const _kColGap = 20.0;
const _kAvailableCol = 76.0;
const _kScheduleCol = 100.0;
const _kActionsCol = 72.0;
/// Phone menu manager: category chips on top, items grouped underneath.
class AdminMobileMenuBrowser extends StatelessWidget {
  const AdminMobileMenuBrowser({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.currency,
    required this.canManageItems,
    required this.canEditItems,
    required this.canToggle,
    required this.busy,
    required this.onSelectCategory,
    required this.onToggleItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final List<AdminMenuCategory> categories;
  final int? selectedCategoryId;
  final String currency;
  final bool canManageItems;
  final bool canEditItems;
  final bool canToggle;
  final bool busy;
  final ValueChanged<int?> onSelectCategory;
  final ValueChanged<int> onToggleItem;
  final void Function(AdminMenuItem item, int categoryId) onEditItem;
  final ValueChanged<AdminMenuItem> onDeleteItem;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final visible = selectedCategoryId == null
        ? categories
        : categories.where((category) => category.id == selectedCategoryId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            children: [
              _CategoryChip(
                label: context.posText('adminMenuAll', 'All'),
                selected: selectedCategoryId == null,
                accent: accent,
                onTap: () => onSelectCategory(null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                _CategoryChip(
                  label: category.name,
                  selected: category.id == selectedCategoryId,
                  accent: accent,
                  onTap: () => onSelectCategory(category.id),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
            children: [
              for (final category in visible) ...[
                _SectionTitle(title: category.name),
                if (category.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.posText('adminNoItemsInCategory', 'No items yet.'),
                      style: TextStyle(
                        color: PosTheme.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  for (final item in category.items)
                    _CompactItemRow(
                      item: item,
                      currency: currency,
                      canEditItems: canEditItems,
                      canManageItems: canManageItems,
                      canToggle: canToggle,
                      busy: busy,
                      accent: accent,
                      onToggle: () => onToggleItem(item.id),
                      onEdit: () => onEditItem(item, category.id),
                      onDelete: () => onDeleteItem(item),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Desktop menu manager: categories on the left, the selected category's items on the right.
class AdminDesktopMenuBrowser extends StatelessWidget {
  const AdminDesktopMenuBrowser({
    super.key,
    required this.categories,
    required this.selected,
    required this.currency,
    required this.timeSlots,
    required this.categorySearch,
    required this.itemSearch,
    required this.canManageCategories,
    required this.canManageItems,
    required this.canEditItems,
    required this.canToggle,
    required this.busy,
    required this.onCategoryQuery,
    required this.onItemQuery,
    required this.onSelectCategory,
    required this.onToggleCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddItem,
    this.onAddCategory,
    this.onReorderCategories,
    required this.onToggleItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final List<AdminMenuCategory> categories;
  final AdminMenuCategory? selected;
  final String currency;
  final List<AdminMenuTimeSlot> timeSlots;
  final TextEditingController categorySearch;
  final TextEditingController itemSearch;
  final bool canManageCategories;
  final bool canManageItems;
  final bool canEditItems;
  final bool canToggle;
  final bool busy;
  final ValueChanged<String> onCategoryQuery;
  final ValueChanged<String> onItemQuery;
  final ValueChanged<int> onSelectCategory;
  final ValueChanged<int> onToggleCategory;
  final ValueChanged<AdminMenuCategory> onEditCategory;
  final ValueChanged<AdminMenuCategory> onDeleteCategory;
  final ValueChanged<int> onAddItem;
  final VoidCallback? onAddCategory;
  final ValueChanged<List<int>>? onReorderCategories;
  final ValueChanged<int> onToggleItem;
  final void Function(AdminMenuItem item, int categoryId) onEditItem;
  final ValueChanged<AdminMenuItem> onDeleteItem;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final category = selected;
    final itemQuery = itemSearch.text.trim().toLowerCase();
    final items = category == null
        ? const <AdminMenuItem>[]
        : [
            for (final item in category.items)
              if (itemQuery.isEmpty ||
                  item.name.toLowerCase().contains(itemQuery) ||
                  (item.description?.toLowerCase().contains(itemQuery) ?? false))
                item,
          ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 268,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PosTheme.canvas,
              border: Border(right: BorderSide(color: PosTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: categorySearch,
                          hint: context.posText(
                            'adminSearchCategory',
                            'Search category',
                          ),
                          onChanged: onCategoryQuery,
                        ),
                      ),
                      if (onAddCategory != null) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: busy ? null : onAddCategory,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            context.posText('adminNewCategory', 'Category'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: onReorderCategories == null
                      ? ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          itemCount: categories.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final row = categories[index];
                            return _CategoryTile(
                              category: row,
                              selected: category?.id == row.id,
                              accent: accent,
                              onTap: () => onSelectCategory(row.id),
                            );
                          },
                        )
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          itemCount: categories.length,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final ids = [for (final row in categories) row.id];
                            final moved = ids.removeAt(oldIndex);
                            ids.insert(newIndex, moved);
                            onReorderCategories!(ids);
                          },
                          itemBuilder: (context, index) {
                            final row = categories[index];
                            return Padding(
                              key: ValueKey(row.id),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _CategoryTile(
                                category: row,
                                selected: category?.id == row.id,
                                accent: accent,
                                reorderIndex: index,
                                onTap: () => onSelectCategory(row.id),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: category == null
              ? Center(
                  child: Text(
                    context.posText('adminMenuNoMatch', 'No matches'),
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = constraints.maxWidth < 640
                        ? 640.0
                        : constraints.maxWidth;
                    return Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: _ItemPane(
                            category: category,
                            items: items,
                            currency: currency,
                            timeSlots: timeSlots,
                            itemSearch: itemSearch,
                            canManageCategories: canManageCategories,
                            canManageItems: canManageItems,
                            canEditItems: canEditItems,
                            canToggle: canToggle,
                            busy: busy,
                            accent: accent,
                            onItemQuery: onItemQuery,
                            onToggleCategory: () => onToggleCategory(category.id),
                            onEditCategory: () => onEditCategory(category),
                            onDeleteCategory: () => onDeleteCategory(category),
                            onAddItem: () => onAddItem(category.id),
                            onToggleItem: onToggleItem,
                            onEditItem: onEditItem,
                            onDeleteItem: onDeleteItem,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ItemPane extends StatelessWidget {
  const _ItemPane({
    required this.category,
    required this.items,
    required this.currency,
    required this.timeSlots,
    required this.itemSearch,
    required this.canManageCategories,
    required this.canManageItems,
    required this.canEditItems,
    required this.canToggle,
    required this.busy,
    required this.accent,
    required this.onItemQuery,
    required this.onToggleCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddItem,
    required this.onToggleItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final AdminMenuCategory category;
  final List<AdminMenuItem> items;
  final String currency;
  final List<AdminMenuTimeSlot> timeSlots;
  final TextEditingController itemSearch;
  final bool canManageCategories;
  final bool canManageItems;
  final bool canEditItems;
  final bool canToggle;
  final bool busy;
  final Color accent;
  final ValueChanged<String> onItemQuery;
  final VoidCallback onToggleCategory;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;
  final VoidCallback onAddItem;
  final ValueChanged<int> onToggleItem;
  final void Function(AdminMenuItem item, int categoryId) onEditItem;
  final ValueChanged<AdminMenuItem> onDeleteItem;

  @override
  Widget build(BuildContext context) {
    return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ItemPaneHeader(
                      category: category,
                      itemSearch: itemSearch,
                      canManageCategories: canManageCategories,
                      canManageItems: canManageItems,
                      canToggle: canToggle,
                      busy: busy,
                      onItemQuery: onItemQuery,
                      onToggleCategory: onToggleCategory,
                      onEditCategory: onEditCategory,
                      onDeleteCategory: onDeleteCategory,
                      onAddItem: onAddItem,
                    ),
                    _ItemTableHeader(),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                context.posText(
                                  'adminNoItemsInCategory',
                                  'No items yet.',
                                ),
                                style: TextStyle(
                                  color: PosTheme.inkMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                              itemCount: items.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: PosTheme.border),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _DesktopItemRow(
                                  item: item,
                                  currency: currency,
                                  schedule: _scheduleLabel(
                                    context,
                                    item,
                                    timeSlots,
                                  ),
                                  canManageItems: canManageItems,
                                  canEditItems: canEditItems,
                                  canToggle: canToggle,
                                  busy: busy,
                                  accent: accent,
                                  onToggle: () => onToggleItem(item.id),
                                  onEdit: () => onEditItem(item, category.id),
                                  onDelete: () => onDeleteItem(item),
                                );
                              },
                            ),
                    ),
                  ],
    );
  }
}

String _scheduleLabel(
  BuildContext context,
  AdminMenuItem item,
  List<AdminMenuTimeSlot> slots,
) {
  if (item.timeSlotIds.isEmpty) {
    return context.posText('adminScheduleAllDay', 'All day');
  }
  final names = [
    for (final slot in slots)
      if (item.timeSlotIds.contains(slot.id)) slot.name,
  ];
  if (names.isEmpty) return context.posText('adminScheduleAllDay', 'All day');
  return names.join(', ');
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Material(
      color: selected ? soft.bg : PosTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 148),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : PosTheme.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: selected ? soft.fg : PosTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.2,
                color: PosTheme.ink,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: PosTheme.inkMuted),
        ],
      ),
    );
  }
}

class _CompactItemRow extends StatelessWidget {
  const _CompactItemRow({
    required this.item,
    required this.currency,
    required this.canEditItems,
    required this.canManageItems,
    required this.canToggle,
    required this.busy,
    required this.accent,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminMenuItem item;
  final String currency;
  final bool canEditItems;
  final bool canManageItems;
  final bool canToggle;
  final bool busy;
  final Color accent;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PosTheme.surface,
        child: InkWell(
          onTap: canEditItems && !busy ? onEdit : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: item.isAvailable ? PosTheme.ink : PosTheme.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatMoney(item.price, currency),
                        style: TextStyle(
                          color: PosTheme.inkMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canToggle)
                  Switch(
                    value: item.isAvailable,
                    onChanged: busy ? null : (_) => onToggle(),
                  ),
                AdminMenuThumb(imageUrl: item.imageUrl, size: 52),
                if (canManageItems)
                  IconButton(
                    tooltip: context.posText('adminDelete', 'Delete'),
                    onPressed: busy ? null : onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: PosTheme.inkFaint,
                      size: 20,
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.reorderIndex,
  });

  final AdminMenuCategory category;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final int? reorderIndex;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Material(
      color: selected ? soft.bg : PosTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.7) : PosTheme.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              if (reorderIndex != null)
                ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: PosTheme.inkFaint,
                    ),
                  ),
                ),
              AdminMenuThumb(
                imageUrl: category.imageUrl,
                icon: Icons.category_outlined,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: category.isActive ? PosTheme.ink : PosTheme.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.posText(
                        'adminMenuItemCount',
                        '{n} items',
                        {'n': '${category.items.length}'},
                      ),
                      style: TextStyle(
                        color: PosTheme.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: category.isActive
                    ? context.posText('adminActive', 'Active')
                    : context.posText('adminInactive', 'Inactive'),
                active: category.isActive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemPaneHeader extends StatelessWidget {
  const _ItemPaneHeader({
    required this.category,
    required this.itemSearch,
    required this.canManageCategories,
    required this.canManageItems,
    required this.canToggle,
    required this.busy,
    required this.onItemQuery,
    required this.onToggleCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddItem,
  });

  final AdminMenuCategory category;
  final TextEditingController itemSearch;
  final bool canManageCategories;
  final bool canManageItems;
  final bool canToggle;
  final bool busy;
  final ValueChanged<String> onItemQuery;
  final VoidCallback onToggleCategory;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          AdminMenuThumb(
            imageUrl: category.imageUrl,
            icon: Icons.category_outlined,
            size: 42,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: PosTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(
                      label: category.isActive
                          ? context.posText('adminActive', 'Active')
                          : context.posText('adminInactive', 'Inactive'),
                      active: category.isActive,
                    ),
                    Text(
                      context.posText(
                        'adminMenuItemCount',
                        '{n} items',
                        {'n': '${category.items.length}'},
                      ),
                      style: TextStyle(
                        color: PosTheme.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      context.posText(
                        'adminCategoryId',
                        'Category ID: {id}',
                        {'id': '${category.id}'},
                      ),
                      style: TextStyle(
                        color: PosTheme.inkFaint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: _SearchField(
                controller: itemSearch,
                hint: context.posText(
                  'adminSearchItems',
                  'Search items in all categories',
                ),
                onChanged: onItemQuery,
              ),
            ),
          ),
          if (canManageItems) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: busy ? null : onAddItem,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.posText('adminNewItem', 'Add item')),
            ),
          ],
          if (canToggle) ...[
            const SizedBox(width: 4),
              Switch(
              value: category.isActive,
              onChanged: busy ? null : (_) => onToggleCategory(),
            ),
          ],
          if (canManageCategories)
            PopupMenuButton<String>(
              tooltip: context.posText('adminActions', 'Actions'),
              onSelected: (value) {
                if (value == 'edit') onEditCategory();
                if (value == 'delete') onDeleteCategory();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(context.posText('adminEdit', 'Edit')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.posText('adminDelete', 'Delete')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ItemTableHeader extends StatelessWidget {
  const _ItemTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: PosTheme.inkMuted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(context.posText('adminColImage', 'Image'), style: style)),
          Expanded(child: Text(context.posText('adminColItem', 'Item name'), style: style)),
          SizedBox(width: _kTypeCol, child: Text(context.posText('adminColType', 'Type'), style: style)),
          const SizedBox(width: _kTypePriceGap),
          SizedBox(width: _kPriceCol, child: Text(context.posText('adminColPrice', 'Price'), style: style)),
          const SizedBox(width: _kColGap),
          SizedBox(width: _kAvailableCol, child: Text(context.posText('adminColAvailable', 'Available'), style: style)),
          const SizedBox(width: _kColGap),
          SizedBox(width: _kScheduleCol, child: Text(context.posText('adminColSchedule', 'Schedule'), style: style)),
          const SizedBox(width: _kColGap),
          SizedBox(width: _kActionsCol, child: Text(context.posText('adminColActions', 'Actions'), style: style)),
        ],
      ),
    );
  }
}

class _DesktopItemRow extends StatelessWidget {
  const _DesktopItemRow({
    required this.item,
    required this.currency,
    required this.schedule,
    required this.canManageItems,
    required this.canEditItems,
    required this.canToggle,
    required this.busy,
    required this.accent,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminMenuItem item;
  final String currency;
  final String schedule;
  final bool canManageItems;
  final bool canEditItems;
  final bool canToggle;
  final bool busy;
  final Color accent;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = item.itemType;
    return Material(
      color: PosTheme.surface,
      child: InkWell(
        onTap: canEditItems && !busy ? onEdit : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              AdminMenuThumb(imageUrl: item.imageUrl, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: item.isAvailable ? PosTheme.ink : PosTheme.inkMuted,
                  ),
                ),
              ),
              SizedBox(
                width: _kTypeCol,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: type == null || type.trim().isEmpty
                      ? Text('—', style: TextStyle(color: PosTheme.inkFaint))
                      : PosItemTypeBadge(type: type, dense: true),
                ),
              ),
              const SizedBox(width: _kTypePriceGap),
              SizedBox(
                width: _kPriceCol,
                child: Text(
                  formatMoney(item.price, currency),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: _kColGap),
              SizedBox(
                width: _kAvailableCol,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: canToggle
                      ? Switch(
                          value: item.isAvailable,
                          onChanged: busy ? null : (_) => onToggle(),
                        )
                      : Icon(
                          item.isAvailable
                              ? Icons.check_circle_rounded
                              : Icons.remove_circle_outline,
                          color: item.isAvailable
                              ? const Color(0xFF16A34A)
                              : PosTheme.inkFaint,
                          size: 18,
                        ),
                ),
              ),
              const SizedBox(width: _kColGap),
              SizedBox(
                width: _kScheduleCol,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ScheduleChip(label: schedule),
                ),
              ),
              const SizedBox(width: _kColGap),
              SizedBox(
                width: _kActionsCol,
                child: Row(
                  children: [
                    if (canEditItems)
                      IconButton(
                        tooltip: context.posText('adminEdit', 'Edit'),
                        onPressed: busy ? null : onEdit,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(Icons.edit_outlined, color: accent, size: 18),
                      ),
                    if (canManageItems)
                      IconButton(
                        tooltip: context.posText('adminDelete', 'Delete'),
                        onPressed: busy ? null : onDelete,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: PosTheme.inkFaint,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosTheme.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: PosTheme.inkMuted,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF15803D) : PosTheme.inkMuted;
    final bg = active ? const Color(0xFFF0FDF4) : PosTheme.surfaceMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: PosTheme.isDark ? posAccentSoft(color).bg : bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: PosTheme.isDark ? posAccentSoft(color).fg : color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        isDense: true,
        filled: true,
        fillColor: PosTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosTheme.radiusSm),
          borderSide: BorderSide(color: PosTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosTheme.radiusSm),
          borderSide: BorderSide(color: PosTheme.border),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onChanged: onChanged,
    );
  }
}
