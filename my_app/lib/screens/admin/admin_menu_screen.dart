import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../providers/pos_admin_controller.dart';
import '../../providers/pos_controller.dart';
import '../../theme/pos_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pos_ui.dart';
import 'admin_chrome.dart';
import 'admin_menu_edit_dialogs.dart';
import 'admin_menu_image_picker.dart';
import 'admin_menu_reorder_screen.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<int> _collapsed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosAdminController>().loadMenu();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminMenuCategory> _filtered(List<AdminMenuCategory> categories) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return categories;

    final out = <AdminMenuCategory>[];
    for (final cat in categories) {
      final catMatch = cat.name.toLowerCase().contains(q) ||
          (cat.description?.toLowerCase().contains(q) ?? false);
      final items = catMatch
          ? cat.items
          : cat.items
              .where(
                (i) =>
                    i.name.toLowerCase().contains(q) ||
                    (i.description?.toLowerCase().contains(q) ?? false),
              )
              .toList();
      if (catMatch || items.isNotEmpty) {
        out.add(cat.copyWith(items: items));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<PosAdminController>();
    final currency = context.watch<PosController>().currency;

    if (admin.menuLoading && admin.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (admin.error != null && admin.categories.isEmpty) {
      return AdminErrorPane(
        message: admin.error!,
        onRetry: admin.loadMenu,
      );
    }

    final canManageCategories =
        admin.canManageMenuCategories || admin.canManageMenu;
    final canManageItems = admin.canManageMenuItems || admin.canManageMenu;
    final canEditItems = admin.canManageMenuItems;
    final canToggle = admin.canToggleMenuAvailability ||
        admin.canManageMenuItems ||
        admin.canManageMenu;

    final categories = _filtered(admin.categories);
    final totalItems =
        admin.categories.fold<int>(0, (n, c) => n + c.items.length);
    final unavailableItems = admin.categories
        .expand((c) => c.items)
        .where((i) => !i.isAvailable)
        .length;
    final inactiveCategories =
        admin.categories.where((c) => !c.isActive).length;

    return Column(
      children: [
        AdminToolbar(
          singleRowActions: true,
          leading: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: context.posText(
                  'adminMenuSearch',
                  'Search categories & items',
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.l10n.commonClear,
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                isDense: true,
                filled: true,
                fillColor: PosTheme.surfaceMuted,
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
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          children: [
            IconButton.filledTonal(
              tooltip: context.l10n.commonRefresh,
              onPressed: admin.menuLoading ? null : admin.loadMenu,
              icon: admin.menuLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
            ),
            if (canManageCategories || canManageItems)
              FilledButton.tonalIcon(
                onPressed: admin.mutating || admin.categories.isEmpty
                    ? null
                    : () => openAdminMenuReorder(context),
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: Text(
                  context.posText('adminMenuReorder', 'Reorder'),
                ),
              ),
            if (canManageCategories)
              FilledButton.tonalIcon(
                onPressed:
                    admin.mutating ? null : () => _editCategory(context, admin),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: Text(context.posText('adminNewCategory', 'Category')),
              ),
            if (canManageItems)
              FilledButton.icon(
                onPressed: admin.mutating || admin.categories.isEmpty
                    ? null
                    : () => _editItem(context, admin),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.posText('adminNewItem', 'Item')),
              ),
          ],
        ),
        if (admin.categories.isNotEmpty)
          _MenuSummaryBar(
            categoryCount: admin.categories.length,
            itemCount: totalItems,
            unavailableItemCount: unavailableItems,
            inactiveCategoryCount: inactiveCategories,
            filtered: _query.trim().isNotEmpty,
            filteredCategoryCount: categories.length,
            filteredItemCount:
                categories.fold<int>(0, (n, c) => n + c.items.length),
          ),
        if (admin.error != null)
          AdminInlineError(
            message: admin.error!,
            onDismiss: admin.clearError,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: admin.loadMenu,
            child: admin.categories.isEmpty
                ? AdminEmptyPane(
                    icon: Icons.restaurant_menu_rounded,
                    title: context.posText(
                      'adminMenuEmpty',
                      'No categories yet.',
                    ),
                    subtitle: context.posText(
                      'adminMenuEmptyHint',
                      'Add a category to start building your menu.',
                    ),
                    action: canManageCategories
                        ? FilledButton.icon(
                            onPressed: admin.mutating
                                ? null
                                : () => _editCategory(context, admin),
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: Text(
                              context.posText('adminNewCategory', 'Category'),
                            ),
                          )
                        : null,
                  )
                : categories.isEmpty
                    ? AdminEmptyPane(
                        icon: Icons.search_off_rounded,
                        title: context.posText(
                          'adminMenuNoMatch',
                          'No matches',
                        ),
                        subtitle: context.posText(
                          'adminMenuNoMatchHint',
                          'Try a different search term.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final expanded = !_collapsed.contains(category.id);
                          return _CategoryCard(
                            category: category,
                            currency: currency,
                            expanded: expanded,
                            canManageCategories: canManageCategories,
                            canManageItems: canManageItems,
                            canEditItems: canEditItems,
                            canToggle: canToggle,
                            busy: admin.mutating,
                            onToggleExpanded: () {
                              setState(() {
                                if (expanded) {
                                  _collapsed.add(category.id);
                                } else {
                                  _collapsed.remove(category.id);
                                }
                              });
                            },
                            onToggleCategory: () =>
                                admin.toggleMenuCategory(category.id),
                            onEditCategory: () => _editCategory(
                              context,
                              admin,
                              category: category,
                            ),
                            onDeleteCategory: () async {
                              final ok = await showPosConfirmDialog(
                                context,
                                title: context.posText(
                                  'adminDeleteCategory',
                                  'Delete category?',
                                ),
                                message: category.name,
                                destructive: true,
                              );
                              if (!ok) return;
                              await admin.deleteMenuCategory(category.id);
                            },
                            onToggleItem: (item) =>
                                admin.toggleMenuItem(item.id),
                            onEditItem: (item) => _editItem(
                              context,
                              admin,
                              item: item,
                              categoryId: category.id,
                            ),
                            onDeleteItem: (item) async {
                              final ok = await showPosConfirmDialog(
                                context,
                                title: context.posText(
                                  'adminDeleteItem',
                                  'Delete item?',
                                ),
                                message: item.name,
                                destructive: true,
                              );
                              if (!ok) return;
                              await admin.deleteMenuItem(item.id);
                            },
                            onAddItem: () => _editItem(
                              context,
                              admin,
                              categoryId: category.id,
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    PosAdminController admin, {
    AdminMenuCategory? category,
  }) async {
    final canSlots =
        admin.canManageMenuTimeSlots || admin.canManageMenu;
    final result = await showAdminMenuCategoryEditDialog(
      context,
      category: category,
      timeSlots: admin.timeSlots,
      canManageSlots: canSlots,
    );
    if (result == null) return;

    final body = <String, dynamic>{
      'name': result.name,
      'description':
          result.description.isEmpty ? null : result.description,
      if (canSlots) 'time_slot_ids': result.timeSlotIds,
    };

    if (category == null) {
      await admin.createMenuCategory(body, imageFile: result.imageFile);
    } else {
      await admin.updateMenuCategory(
        category.id,
        body,
        imageFile: result.imageFile,
      );
    }
  }

  Future<void> _editItem(
    BuildContext context,
    PosAdminController admin, {
    AdminMenuItem? item,
    int? categoryId,
  }) async {
    final canSlots =
        admin.canManageMenuTimeSlots || admin.canManageMenu;
    final canMods =
        admin.canManageMenuModifiers || admin.canManageMenu;
    final result = await showAdminMenuItemEditDialog(
      context,
      item: item,
      categories: admin.categories,
      initialCategoryId: categoryId,
      timeSlots: admin.timeSlots,
      modifiers: admin.modifiers,
      canManageSlots: canSlots,
      canManageModifiers: canMods,
    );
    if (result == null) return;

    if (item == null) {
      if (result.categoryId == null) return;
      await admin.createMenuItem(
        {
          'menu_category_id': result.categoryId,
          'name': result.name,
          'price': result.price,
          'description':
              result.description.isEmpty ? null : result.description,
          if (canSlots) 'time_slot_ids': result.timeSlotIds,
          if (canMods) 'modifier_ids': result.modifierIds,
        },
        imageFile: result.imageFile,
      );
    } else {
      await admin.updateMenuItem(
        item.id,
        {
          'name': result.name,
          'price': result.price,
          'description':
              result.description.isEmpty ? null : result.description,
          if (canSlots) 'time_slot_ids': result.timeSlotIds,
          if (canMods) 'modifier_ids': result.modifierIds,
        },
        imageFile: result.imageFile,
      );
    }
  }
}

class _MenuSummaryBar extends StatelessWidget {
  const _MenuSummaryBar({
    required this.categoryCount,
    required this.itemCount,
    required this.unavailableItemCount,
    required this.inactiveCategoryCount,
    required this.filtered,
    required this.filteredCategoryCount,
    required this.filteredItemCount,
  });

  final int categoryCount;
  final int itemCount;
  final int unavailableItemCount;
  final int inactiveCategoryCount;
  final bool filtered;
  final int filteredCategoryCount;
  final int filteredItemCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (filtered) {
      parts.add(
        context.posText(
          'adminMenuShowing',
          'Showing {cats} categories · {items} items',
          {
            'cats': '$filteredCategoryCount',
            'items': '$filteredItemCount',
          },
        ),
      );
    } else {
      parts.add(
        context.posText(
          'adminMenuCategoryCount',
          '{n} categories',
          {'n': '$categoryCount'},
        ),
      );
      parts.add(
        context.posText(
          'adminMenuItemCount',
          '{n} items',
          {'n': '$itemCount'},
        ),
      );
      if (unavailableItemCount > 0) {
        parts.add(
          context.posText(
            'adminMenuUnavailableCount',
            '{n} unavailable',
            {'n': '$unavailableItemCount'},
          ),
        );
      }
      if (inactiveCategoryCount > 0) {
        parts.add(
          context.posText(
            'adminMenuInactiveCount',
            '{n} inactive',
            {'n': '$inactiveCategoryCount'},
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
          parts.join('  ·  '),
          maxLines: 1,
          style: TextStyle(
            color: PosTheme.inkMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.currency,
    required this.expanded,
    required this.canManageCategories,
    required this.canManageItems,
    required this.canEditItems,
    required this.canToggle,
    required this.busy,
    required this.onToggleExpanded,
    required this.onToggleCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onToggleItem,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onAddItem,
  });

  final AdminMenuCategory category;
  final String currency;
  final bool expanded;
  final bool canManageCategories;
  final bool canManageItems;
  final bool canEditItems;
  final bool canToggle;
  final bool busy;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleCategory;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;
  final ValueChanged<AdminMenuItem> onToggleItem;
  final ValueChanged<AdminMenuItem> onEditItem;
  final ValueChanged<AdminMenuItem> onDeleteItem;
  final VoidCallback onAddItem;

  String _subtitle(BuildContext context) {
    final parts = <String>[
      context.posText(
        'adminMenuItemCount',
        '{n} items',
        {'n': '${category.items.length}'},
      ),
    ];
    if (!category.isActive) {
      parts.add(context.posText('adminInactive', 'Inactive'));
    }
    if (category.timeSlotIds.isNotEmpty) {
      parts.add(
        context.posText(
          'adminSlotCount',
          '{n} slots',
          {'n': '${category.timeSlotIds.length}'},
        ),
      );
    }
    final desc = category.description?.trim();
    if (desc != null && desc.isNotEmpty) {
      parts.add(desc);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(PosTheme.radiusMd),
          border: Border.all(color: PosTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  AdminMenuThumb(
                    imageUrl: category.imageUrl,
                    icon: Icons.category_outlined,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
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
                            fontSize: MediaQuery.sizeOf(context).width < 600 ? 14 : 16,
                            color: category.isActive
                                ? PosTheme.ink
                                : PosTheme.inkMuted,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subtitle(context),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PosTheme.inkMuted,
                            fontSize: 12.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canToggle)
                    Switch(
                      value: category.isActive,
                      onChanged: busy ? null : (_) => onToggleCategory(),
                    ),
                  if (canManageCategories)
                    IconButton(
                      tooltip: context.posText('adminEdit', 'Edit'),
                      onPressed: busy ? null : onEditCategory,
                      icon: Icon(Icons.edit_outlined, color: accent, size: 20),
                    ),
                  if (canManageCategories)
                    PopupMenuButton<String>(
                      tooltip: context.posText('adminActions', 'Actions'),
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: PosTheme.inkFaint,
                      ),
                      onSelected: (v) {
                        if (v == 'add') onAddItem();
                        if (v == 'delete') onDeleteCategory();
                      },
                      itemBuilder: (_) => [
                        if (canManageItems)
                          PopupMenuItem(
                            value: 'add',
                            child: Text(
                              context.posText('adminNewItem', 'Add item'),
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            context.posText('adminDelete', 'Delete'),
                          ),
                        ),
                      ],
                    ),
                  IconButton(
                    tooltip: expanded
                        ? context.posText('adminCollapse', 'Collapse')
                        : context.posText('adminExpand', 'Expand'),
                    onPressed: onToggleExpanded,
                    icon: Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              Divider(height: 1, thickness: 1, color: PosTheme.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  children: [
                    if (category.items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: PosTheme.surfaceMuted.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          context.posText(
                            'adminNoItemsInCategory',
                            'No items yet.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: PosTheme.inkMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      for (final item in category.items)
                        _ItemRow(
                          item: item,
                          currency: currency,
                          canManageItems: canManageItems,
                          canEditItems: canEditItems,
                          canToggle: canToggle,
                          busy: busy,
                          accent: accent,
                          onToggle: () => onToggleItem(item),
                          onEdit: () => onEditItem(item),
                          onDelete: () => onDeleteItem(item),
                        ),
                    if (canManageItems) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: busy ? null : onAddItem,
                          icon: Icon(Icons.add_rounded, size: 18, color: accent),
                          label: Text(
                            context.posText('adminNewItem', 'Add item'),
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: accent.withValues(alpha: 0.28),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.currency,
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
    final desc = item.description?.trim();
    final meta = <String>[formatMoney(item.price, currency)];
    if (item.modifierIds.isNotEmpty) {
      meta.add(
        context.posText(
          'adminModCount',
          '{n} modifiers',
          {'n': '${item.modifierIds.length}'},
        ),
      );
    }
    if (item.timeSlotIds.isNotEmpty) {
      meta.add(
        context.posText(
          'adminSlotCount',
          '{n} slots',
          {'n': '${item.timeSlotIds.length}'},
        ),
      );
    }
    if (!item.isAvailable) {
      meta.add(context.posText('adminUnavailable', 'Unavailable'));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: PosTheme.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: canEditItems && !busy ? onEdit : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                AdminMenuThumb(imageUrl: item.imageUrl,
                  size: MediaQuery.sizeOf(context).width < 600 ? 36 : 44),
                const SizedBox(width: 10),
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
                          fontSize: MediaQuery.sizeOf(context).width < 600 ? 12.5 : 14,
                          color: item.isAvailable
                              ? PosTheme.ink
                              : PosTheme.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (desc != null && desc.isNotEmpty) desc,
                          ...meta,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PosTheme.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
                if (canEditItems)
                  IconButton(
                    tooltip: context.posText('adminEdit', 'Edit'),
                    onPressed: busy ? null : onEdit,
                    icon: Icon(Icons.edit_outlined, color: accent, size: 20),
                  ),
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
