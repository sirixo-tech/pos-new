import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../providers/pos_admin_controller.dart';
import '../../providers/pos_controller.dart';
import '../../theme/pos_theme.dart';
import '../../utils/pos_layout.dart';
import '../../widgets/pos_ui.dart';
import 'admin_chrome.dart';
import 'admin_menu_browser.dart';
import 'admin_menu_edit_dialogs.dart';
import 'admin_menu_reorder_screen.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  final _searchCtrl = TextEditingController();
  final _categorySearchCtrl = TextEditingController();
  final _itemSearchCtrl = TextEditingController();
  String _query = '';
  String _categoryQuery = '';
  String _itemQuery = '';
  int? _selectedCategoryId;

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
    _categorySearchCtrl.dispose();
    _itemSearchCtrl.dispose();
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
    final handheld = usePosHandheldLayout(context);

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
        if (handheld)
        AdminToolbar(
          singleRowActions: true,
          leading: handheld
              ? ConstrainedBox(
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
          )
              : null,
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
        if (handheld && admin.categories.isNotEmpty)
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
                    : handheld
                        ? AdminMobileMenuBrowser(
                            categories: categories,
                            selectedCategoryId: _selectedCategoryId,
                            currency: currency,
                            canManageItems: canManageItems,
                            canEditItems: canEditItems,
                            canToggle: canToggle,
                            busy: admin.mutating,
                            onSelectCategory: (id) =>
                                setState(() => _selectedCategoryId = id),
                            onToggleItem: (id) => admin.toggleMenuItem(id),
                            onEditItem: (item, categoryId) => _editItem(
                              context,
                              admin,
                              item: item,
                              categoryId: categoryId,
                            ),
                            onDeleteItem: (item) =>
                                _confirmDeleteItem(context, admin, item),
                          )
                        : AdminDesktopMenuBrowser(
                            categories: _desktopCategories(admin.categories),
                            selected: _desktopSelection(admin.categories),
                            currency: currency,
                            timeSlots: admin.timeSlots,
                            categorySearch: _categorySearchCtrl,
                            itemSearch: _itemSearchCtrl,
                            canManageCategories: canManageCategories,
                            canManageItems: canManageItems,
                            canEditItems: canEditItems,
                            canToggle: canToggle,
                            busy: admin.mutating,
                            onCategoryQuery: (value) =>
                                setState(() => _categoryQuery = value),
                            onItemQuery: (value) =>
                                setState(() => _itemQuery = value),
                            onSelectCategory: (id) =>
                                setState(() => _selectedCategoryId = id),
                            onToggleCategory: (id) => admin.toggleMenuCategory(id),
                            onEditCategory: (category) => _editCategory(
                              context,
                              admin,
                              category: category,
                            ),
                            onDeleteCategory: (category) =>
                                _confirmDeleteCategory(context, admin, category),
                            onAddItem: (categoryId) => _editItem(
                              context,
                              admin,
                              categoryId: categoryId,
                            ),
                            onAddCategory: canManageCategories
                                ? () => _editCategory(context, admin)
                                : null,
                            onReorderCategories: canManageCategories &&
                                    _categoryQuery.isEmpty &&
                                    _itemQuery.isEmpty
                                ? (order) => _reorderCategories(admin, order)
                                : null,
                            onToggleItem: (id) => admin.toggleMenuItem(id),
                            onEditItem: (item, categoryId) => _editItem(
                              context,
                              admin,
                              item: item,
                              categoryId: categoryId,
                            ),
                            onDeleteItem: (item) =>
                                _confirmDeleteItem(context, admin, item),
                          ),
          ),
        ),
      ],
    );
  }

  List<AdminMenuCategory> _desktopCategories(List<AdminMenuCategory> categories) {
    final categoryQuery = _categoryQuery.trim().toLowerCase();
    final itemQuery = _itemQuery.trim().toLowerCase();
    return [
      for (final category in categories)
        if (_categoryVisible(category, categoryQuery, itemQuery)) category,
    ];
  }

  bool _categoryVisible(
    AdminMenuCategory category,
    String categoryQuery,
    String itemQuery,
  ) {
    final nameHit = categoryQuery.isEmpty ||
        category.name.toLowerCase().contains(categoryQuery) ||
        (category.description?.toLowerCase().contains(categoryQuery) ?? false);
    final itemHit = itemQuery.isEmpty ||
        category.items.any((item) => _itemVisible(item, itemQuery));
    return nameHit && itemHit;
  }

  bool _itemVisible(AdminMenuItem item, String query) {
    return item.name.toLowerCase().contains(query) ||
        (item.description?.toLowerCase().contains(query) ?? false);
  }

  AdminMenuCategory? _desktopSelection(List<AdminMenuCategory> categories) {
    final visible = _desktopCategories(categories);
    if (visible.isEmpty) return null;
    for (final category in visible) {
      if (category.id == _selectedCategoryId) return category;
    }
    return visible.first;
  }

  Future<void> _reorderCategories(
    PosAdminController admin,
    List<int> order,
  ) async {
    admin.stageCategoryOrder(order);
    await admin.reorderMenuCategories(order);
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    PosAdminController admin,
    AdminMenuCategory category,
  ) async {
    final ok = await showPosConfirmDialog(
      context,
      title: context.posText('adminDeleteCategory', 'Delete category?'),
      message: category.name,
      destructive: true,
    );
    if (!ok) return;
    await admin.deleteMenuCategory(category.id);
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    PosAdminController admin,
    AdminMenuItem item,
  ) async {
    final ok = await showPosConfirmDialog(
      context,
      title: context.posText('adminDeleteItem', 'Delete item?'),
      message: item.name,
      destructive: true,
    );
    if (!ok) return;
    await admin.deleteMenuItem(item.id);
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
