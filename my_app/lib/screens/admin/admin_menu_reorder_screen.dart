import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../providers/pos_admin_controller.dart';
import '../../providers/pos_controller.dart';
import '../../theme/pos_theme.dart';
import '../../utils/format.dart';

Future<void> openAdminMenuReorder(BuildContext context) async {
  final admin = context.read<PosAdminController>();
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
        value: admin,
        child: const AdminMenuReorderScreen(),
      ),
    ),
  );
}

class AdminMenuReorderScreen extends StatefulWidget {
  const AdminMenuReorderScreen({super.key});

  @override
  State<AdminMenuReorderScreen> createState() => _AdminMenuReorderScreenState();
}

class _AdminMenuReorderScreenState extends State<AdminMenuReorderScreen> {
  late List<AdminMenuCategory> _categories;
  int? _selectedCategoryId;
  List<AdminMenuItem> _items = [];
  var _categoriesDirty = false;
  var _itemsDirty = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final admin = context.read<PosAdminController>();
    _categories = List<AdminMenuCategory>.from(admin.categories);
    if (_categories.isNotEmpty) {
      _selectCategory(_categories.first.id);
    }
  }

  AdminMenuCategory? _categoryById(int? id) {
    if (id == null) return null;
    for (final cat in _categories) {
      if (cat.id == id) return cat;
    }
    return null;
  }

  void _selectCategory(int id) {
    final cat = _categoryById(id);
    setState(() {
      _selectedCategoryId = id;
      _items = List<AdminMenuItem>.from(cat?.items ?? const []);
      _itemsDirty = false;
    });
  }

  void _onReorderCategories(int oldIndex, int newIndex) {
    setState(() {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
      _categoriesDirty = true;
    });
  }

  void _onReorderItems(int oldIndex, int newIndex) {
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _itemsDirty = true;
    });
  }

  Future<void> _saveCategories() async {
    if (!_categoriesDirty || _saving) return;
    setState(() => _saving = true);
    final admin = context.read<PosAdminController>();
    final ok = await admin.reorderMenuCategories(
      _categories.map((c) => c.id).toList(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _categoriesDirty = false;
        _categories = List<AdminMenuCategory>.from(admin.categories);
        if (_selectedCategoryId != null) {
          _selectCategory(_selectedCategoryId!);
        }
      }
    });
  }

  Future<void> _saveItems() async {
    if (!_itemsDirty || _saving || _selectedCategoryId == null) return;
    setState(() => _saving = true);
    final admin = context.read<PosAdminController>();
    final categoryId = _selectedCategoryId!;
    final ok = await admin.reorderMenuItems(
      categoryId: categoryId,
      order: _items.map((i) => i.id).toList(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _itemsDirty = false;
        _categories = List<AdminMenuCategory>.from(admin.categories);
        _selectCategory(categoryId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<PosAdminController>();
    final currency = context.watch<PosController>().currency;
    final accent = Theme.of(context).colorScheme.primary;
    final canCategories =
        admin.canManageMenuCategories || admin.canManageMenu;
    final canItems = admin.canManageMenuItems || admin.canManageMenu;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          context.posText('adminMenuReorderTitle', 'Reorder menu'),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.commonClose,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: admin.categories.isEmpty
          ? Center(
              child: Text(
                context.posText(
                  'adminMenuReorderEmpty',
                  'Add categories first, then set their order.',
                ),
                style: TextStyle(color: PosTheme.inkMuted),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    context.posText(
                      'adminMenuReorderHint',
                      'Drag to change the order guests see on the menu. Save each list when you are done.',
                    ),
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                if (admin.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      admin.error!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _panel(
                                title: context.posText(
                                  'adminMenuReorderCategories',
                                  'Categories',
                                ),
                                subtitle: context.posText(
                                  'adminMenuReorderCategoriesHint',
                                  'Numbers show guest-facing order.',
                                ),
                                dirty: _categoriesDirty,
                                saving: _saving,
                                canSave: canCategories && _categoriesDirty,
                                onSave: _saveCategories,
                                child: ReorderableListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    16,
                                  ),
                                  buildDefaultDragHandles: false,
                                  itemCount: _categories.length,
                                  onReorderItem: canCategories
                                      ? _onReorderCategories
                                      : (_, _) {},
                                  itemBuilder: (context, index) {
                                    final cat = _categories[index];
                                    final selected =
                                        cat.id == _selectedCategoryId;
                                    return _ReorderTile(
                                      key: ValueKey('cat-${cat.id}'),
                                      index: index,
                                      selected: selected,
                                      enabled: canCategories,
                                      title: cat.name,
                                      subtitle: context.posText(
                                        'adminMenuItemCount',
                                        '{n} items',
                                        {'n': '${cat.items.length}'},
                                      ),
                                      accent: accent,
                                      onTap: () => _selectCategory(cat.id),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 3,
                              child: _itemsPanel(
                                canItems: canItems,
                                currency: currency,
                                accent: accent,
                              ),
                            ),
                          ],
                        )
                      : _mobileBody(
                          canCategories: canCategories,
                          canItems: canItems,
                          currency: currency,
                          accent: accent,
                        ),
                ),
              ],
            ),
    );
  }

  Widget _mobileBody({
    required bool canCategories,
    required bool canItems,
    required String currency,
    required Color accent,
  }) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(
                text: context.posText(
                  'adminMenuReorderCategories',
                  'Categories',
                ),
              ),
              Tab(
                text: context.posText('adminMenuReorderItems', 'Items'),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _panel(
                  title: context.posText(
                    'adminMenuReorderCategories',
                    'Categories',
                  ),
                  subtitle: context.posText(
                    'adminMenuReorderCategoriesHint',
                    'Numbers show guest-facing order.',
                  ),
                  dirty: _categoriesDirty,
                  saving: _saving,
                  canSave: canCategories && _categoriesDirty,
                  onSave: _saveCategories,
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    buildDefaultDragHandles: false,
                    itemCount: _categories.length,
                    onReorderItem:
                        canCategories ? _onReorderCategories : (_, _) {},
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      return _ReorderTile(
                        key: ValueKey('cat-${cat.id}'),
                        index: index,
                        selected: cat.id == _selectedCategoryId,
                        enabled: canCategories,
                        title: cat.name,
                        subtitle: context.posText(
                          'adminMenuItemCount',
                          '{n} items',
                          {'n': '${cat.items.length}'},
                        ),
                        accent: accent,
                        onTap: () => _selectCategory(cat.id),
                      );
                    },
                  ),
                ),
                _itemsPanel(
                  canItems: canItems,
                  currency: currency,
                  accent: accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsPanel({
    required bool canItems,
    required String currency,
    required Color accent,
  }) {
    final selected = _categoryById(_selectedCategoryId);
    final title = selected == null
        ? context.posText('adminMenuReorderItems', 'Items')
        : context.posText(
            'adminMenuReorderItemsIn',
            'Items in {name}',
            {'name': selected.name},
          );

    return _panel(
      title: title,
      subtitle: selected == null
          ? context.posText(
              'adminMenuReorderSelectCategory',
              'Select a category to reorder its items.',
            )
          : context.posText(
              'adminMenuReorderItemsHint',
              'Drag items to change their order in this category.',
            ),
      dirty: _itemsDirty,
      saving: _saving,
      canSave: canItems && _itemsDirty,
      onSave: _saveItems,
      child: selected == null
          ? Center(
              child: Text(
                context.posText(
                  'adminMenuReorderSelectCategory',
                  'Select a category to reorder its items.',
                ),
                style: TextStyle(color: PosTheme.inkMuted),
              ),
            )
          : _items.isEmpty
              ? Center(
                  child: Text(
                    context.posText(
                      'adminMenuReorderNoItems',
                      'No items in this category.',
                    ),
                    style: TextStyle(color: PosTheme.inkMuted),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  buildDefaultDragHandles: false,
                  itemCount: _items.length,
                  onReorderItem: canItems ? _onReorderItems : (_, _) {},
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _ReorderTile(
                      key: ValueKey('item-${item.id}'),
                      index: index,
                      selected: false,
                      enabled: canItems,
                      title: item.name,
                      subtitle: formatMoney(item.price, currency),
                      accent: accent,
                      dimmed: !item.isAvailable,
                    );
                  },
                ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required bool dirty,
    required bool saving,
    required bool canSave,
    required VoidCallback onSave,
    required Widget child,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: PosTheme.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (dirty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    context.posText('adminUnsaved', 'Unsaved'),
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: canSave && !saving ? onSave : null,
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.commonSave),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    super.key,
    required this.index,
    required this.selected,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.onTap,
    this.dimmed = false,
  });

  final int index;
  final bool selected;
  final bool enabled;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? soft.bg : PosTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? soft.fg.withValues(alpha: 0.35)
                    : PosTheme.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PosTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: dimmed ? PosTheme.inkFaint : PosTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PosTheme.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: PosTheme.inkFaint,
                      ),
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
