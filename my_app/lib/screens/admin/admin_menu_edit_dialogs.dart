import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../providers/pos_controller.dart';
import '../../services/pos_api.dart';
import '../../theme/pos_theme.dart';
import '../../utils/pos_user_facing_error.dart';
import '../../widgets/pos_overlay.dart';
import '../../widgets/pos_ui.dart';
import 'admin_chrome.dart';
import 'admin_menu_image_picker.dart';
import 'admin_menu_option_picker.dart';

class AdminMenuCategoryEditResult {
  const AdminMenuCategoryEditResult({
    required this.name,
    required this.description,
    required this.timeSlotIds,
    this.imageFile,
  });

  final String name;
  final String description;
  final List<int> timeSlotIds;
  final XFile? imageFile;
}

class AdminMenuItemEditResult {
  const AdminMenuItemEditResult({
    required this.name,
    required this.price,
    required this.description,
    required this.timeSlotIds,
    required this.modifierIds,
    this.categoryId,
    this.imageFile,
  });

  final String name;
  final double price;
  final String description;
  final List<int> timeSlotIds;
  final List<int> modifierIds;
  final int? categoryId;
  final XFile? imageFile;
}

Future<AdminMenuCategoryEditResult?> showAdminMenuCategoryEditDialog(
  BuildContext context, {
  AdminMenuCategory? category,
  List<AdminMenuTimeSlot> timeSlots = const [],
  bool canManageSlots = false,
}) {
  return showAdminPanel<AdminMenuCategoryEditResult>(
    context: context,
    sidePanelWidth: 480,
    builder: (ctx) => _CategoryEditDialog(
      category: category,
      timeSlots: timeSlots,
      canManageSlots: canManageSlots,
    ),
  );
}

Future<AdminMenuItemEditResult?> showAdminMenuItemEditDialog(
  BuildContext context, {
  AdminMenuItem? item,
  List<AdminMenuCategory> categories = const [],
  int? initialCategoryId,
  List<AdminMenuTimeSlot> timeSlots = const [],
  List<AdminMenuModifier> modifiers = const [],
  bool canManageSlots = false,
  bool canManageModifiers = false,
}) {
  return showAdminPanel<AdminMenuItemEditResult>(
    context: context,
    sidePanelWidth: 520,
    builder: (ctx) => _ItemEditDialog(
      item: item,
      categories: categories,
      initialCategoryId: initialCategoryId,
      timeSlots: timeSlots,
      modifiers: modifiers,
      canManageSlots: canManageSlots,
      canManageModifiers: canManageModifiers,
    ),
  );
}

class _CategoryEditDialog extends StatefulWidget {
  const _CategoryEditDialog({
    this.category,
    required this.timeSlots,
    required this.canManageSlots,
  });

  final AdminMenuCategory? category;
  final List<AdminMenuTimeSlot> timeSlots;
  final bool canManageSlots;

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late List<int> _slotIds;
  XFile? _pickedImage;
  bool _pickingImage = false;

  bool get _isCreate => widget.category == null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameCtrl = TextEditingController(text: category?.name ?? '');
    _descCtrl = TextEditingController(text: category?.description ?? '');
    _slotIds = [...(category?.timeSlotIds ?? const <int>[])];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final picked = await AdminMenuImagePickerSection.pickFromGallery();
      if (!mounted || picked == null) return;
      setState(() => _pickedImage = picked);
    } catch (_) {
      if (!mounted) return;
      showPosSnackBar(
        context,
        context.posText(
          'adminPhotoPickerUnavailable',
          'Photo picker needs a full app restart.',
        ),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showPosSnackBar(
        context,
        context.posText('adminEnterName', 'Enter a name'),
        error: true,
      );
      return;
    }
    Navigator.pop(
      context,
      AdminMenuCategoryEditResult(
        name: name,
        description: _descCtrl.text.trim(),
        timeSlotIds: _slotIds,
        imageFile: _pickedImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PosDialogShell(
      title: _isCreate
          ? context.posText('adminNewCategory', 'New category')
          : context.posText('adminEditCategory', 'Edit category'),
      subtitle: context.posText(
        'adminCategoryEditHint',
        'Name, photo, and optional schedule windows.',
      ),
      icon: Icons.category_rounded,
      maxWidth: 480,
      embedded: true,
      onClose: () => Navigator.pop(context),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminMenuImagePickerSection(
            label: context.posText('adminCategoryImage', 'Category image'),
            imageUrl: widget.category?.imageUrl,
            pickedImage: _pickedImage,
            picking: _pickingImage,
            onPick: _pickImage,
            placeholderIcon: Icons.category_rounded,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: context.posText('adminName', 'Name'),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(
              labelText: context.posText('adminDescription', 'Description'),
            ),
            maxLines: 2,
          ),
          if (widget.canManageSlots) ...[
            const SizedBox(height: 16),
            AdminMenuOptionPicker(
              title: context.posText('adminTimeSlots', 'Time slots'),
              helpText: context.posText(
                'adminCategorySlotsHelp',
                'Schedule windows for items in this category unless an item overrides them.',
              ),
              emptyText: context.posText(
                'adminNoTimeSlotsYet',
                'No time slots yet. Create them under Manage → Time slots.',
              ),
              options: [
                for (final slot in widget.timeSlots)
                  AdminMenuPickerOption.fromTimeSlot(slot),
              ],
              selectedIds: _slotIds,
              onChanged: (ids) => setState(() => _slotIds = ids),
            ),
          ],
        ],
      ),
      footer: posDialogActionFooter(
        context: context,
        confirmLabel: _isCreate
            ? context.posText('adminCreate', 'Create')
            : context.l10n.commonSave,
        onCancel: () => Navigator.pop(context),
        onConfirm: _save,
      ),
    );
  }
}

class _ItemEditDialog extends StatefulWidget {
  const _ItemEditDialog({
    this.item,
    required this.categories,
    this.initialCategoryId,
    required this.timeSlots,
    required this.modifiers,
    required this.canManageSlots,
    required this.canManageModifiers,
  });

  final AdminMenuItem? item;
  final List<AdminMenuCategory> categories;
  final int? initialCategoryId;
  final List<AdminMenuTimeSlot> timeSlots;
  final List<AdminMenuModifier> modifiers;
  final bool canManageSlots;
  final bool canManageModifiers;

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late int? _categoryId;
  late List<int> _slotIds;
  late List<int> _modifierIds;
  XFile? _pickedImage;
  bool _pickingImage = false;

  bool get _isCreate => widget.item == null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _descCtrl = TextEditingController(text: item?.description ?? '');
    _priceCtrl = TextEditingController(
      text: item != null ? item.price.toStringAsFixed(2) : '',
    );
    _categoryId = widget.initialCategoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    if (item != null) {
      for (final cat in widget.categories) {
        if (cat.items.any((i) => i.id == item.id)) {
          _categoryId = cat.id;
          break;
        }
      }
    }
    _slotIds = [...(item?.timeSlotIds ?? const <int>[])];
    _modifierIds = [...(item?.modifierIds ?? const <int>[])];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateImage() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showPosSnackBar(
        context,
        context.posText('adminEnterName', 'Enter a name'),
        error: true,
      );
      return;
    }
    final choice = await showModalBottomSheet<_AiImageChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PosKeyboardSheetHost(
        child: _AiImageStyleSheet(itemName: name),
      ),
    );
    if (!mounted || choice == null) return;
    final session = context.read<PosController>().session;
    if (session == null) return;
    setState(() => _pickingImage = true);
    try {
      final categoryName = widget.categories
          .where((cat) => cat.id == _categoryId)
          .map((cat) => cat.name)
          .firstOrNull;
      final file = await context.read<PosApi>().generateMenuItemImage(
        session,
        name: name,
        description: _descCtrl.text.trim(),
        style: choice.style,
        keywords: choice.keywords,
        itemType: widget.item?.itemType,
        categoryName: categoryName,
      );
      if (!mounted) return;
      setState(() => _pickedImage = file);
    } catch (error) {
      if (!mounted) return;
      showPosSnackBar(context, posUserFacingError(error), error: true);
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final picked = await AdminMenuImagePickerSection.pickFromGallery();
      if (!mounted || picked == null) return;
      setState(() => _pickedImage = picked);
    } catch (_) {
      if (!mounted) return;
      showPosSnackBar(
        context,
        context.posText(
          'adminPhotoPickerUnavailable',
          'Photo picker needs a full app restart.',
        ),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    if (name.isEmpty) {
      showPosSnackBar(
        context,
        context.posText('adminEnterName', 'Enter a name'),
        error: true,
      );
      return;
    }
    if (price == null) {
      showPosSnackBar(
        context,
        context.posText('adminEnterValidPrice', 'Enter a valid price'),
        error: true,
      );
      return;
    }
    if (_isCreate && _categoryId == null) {
      showPosSnackBar(
        context,
        context.posText('adminSelectCategory', 'Select a category'),
        error: true,
      );
      return;
    }
    Navigator.pop(
      context,
      AdminMenuItemEditResult(
        name: name,
        price: price,
        description: _descCtrl.text.trim(),
        timeSlotIds: _slotIds,
        modifierIds: _modifierIds,
        categoryId: _categoryId,
        imageFile: _pickedImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PosDialogShell(
      title: _isCreate
          ? context.posText('adminNewItem', 'New item')
          : context.posText('adminEditItem', 'Edit item'),
      subtitle: context.posText(
        'adminItemEditHint',
        'Photo, price, modifiers, and schedule.',
      ),
      icon: Icons.restaurant_menu_rounded,
      maxWidth: 480,
      embedded: true,
      onClose: () => Navigator.pop(context),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminMenuImagePickerSection(
            label: context.posText('adminProductImage', 'Product image'),
            imageUrl: widget.item?.imageUrl,
            pickedImage: _pickedImage,
            picking: _pickingImage,
            onPick: _pickImage,
            onGenerate: _generateImage,
          ),
          const SizedBox(height: 16),
          if (_isCreate) ...[
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: InputDecoration(
                labelText: context.posText('adminCategory', 'Category'),
              ),
              items: [
                for (final cat in widget.categories)
                  DropdownMenuItem(value: cat.id, child: Text(cat.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: context.posText('adminName', 'Name'),
            ),
            autofocus: !_isCreate,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            decoration: InputDecoration(
              labelText: context.posText('adminPrice', 'Price'),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(
              labelText: context.posText('adminDescription', 'Description'),
            ),
            maxLines: 2,
          ),
          if (widget.canManageSlots) ...[
            const SizedBox(height: 16),
            AdminMenuOptionPicker(
              title: context.posText('adminTimeSlots', 'Time slots'),
              helpText: context.posText(
                'adminItemSlotsHelp',
                'Leave empty to follow the category schedule. Select slots to override.',
              ),
              emptyText: context.posText(
                'adminNoTimeSlotsYet',
                'No time slots yet. Create them under Manage → Time slots.',
              ),
              options: [
                for (final slot in widget.timeSlots)
                  AdminMenuPickerOption.fromTimeSlot(slot),
              ],
              selectedIds: _slotIds,
              onChanged: (ids) => setState(() => _slotIds = ids),
            ),
          ],
          if (widget.canManageModifiers) ...[
            const SizedBox(height: 16),
            AdminMenuOptionPicker(
              title: context.posText('adminModifiers', 'Modifiers'),
              helpText: context.posText(
                'adminItemModifiersHelp',
                'Attach option groups guests can choose when ordering this item.',
              ),
              emptyText: context.posText(
                'adminNoModifiersYet',
                'No modifiers yet. Create them under Manage → Modifiers.',
              ),
              options: [
                for (final mod in widget.modifiers)
                  AdminMenuPickerOption.fromModifier(mod),
              ],
              selectedIds: _modifierIds,
              onChanged: (ids) => setState(() => _modifierIds = ids),
            ),
          ],
        ],
      ),
      footer: posDialogActionFooter(
        context: context,
        confirmLabel: _isCreate
            ? context.posText('adminCreate', 'Create')
            : context.l10n.commonSave,
        onCancel: () => Navigator.pop(context),
        onConfirm: _save,
      ),
    );
  }
}

class _AiImageChoice {
  const _AiImageChoice({required this.style, this.keywords = ''});

  final String style;
  final String keywords;
}

class _AiImageStyleSheet extends StatefulWidget {
  const _AiImageStyleSheet({required this.itemName});

  final String itemName;

  @override
  State<_AiImageStyleSheet> createState() => _AiImageStyleSheetState();
}

class _AiImageStyleSheetState extends State<_AiImageStyleSheet> {
  static const _styles = <(String, String)>[
    ('catalog', 'Catalog'),
    ('hero', 'Hero'),
    ('bright', 'Bright'),
    ('flatlay', 'Flat lay'),
    ('indian_thali', 'Thali'),
    ('tandoor', 'Tandoor'),
    ('street_chaat', 'Street'),
    ('spice_kadhai', 'Kadhai'),
    ('fresh_juice', 'Juice'),
    ('custom', 'Custom'),
  ];

  String _style = 'catalog';
  final _keywords = TextEditingController();

  @override
  void dispose() {
    _keywords.dispose();
    super.dispose();
  }

  void _use() {
    final keywords = _keywords.text.trim();
    if (_style == 'custom' && keywords.isEmpty) {
      showPosSnackBar(context, 'Add a few words for a custom image.', error: true);
      return;
    }
    Navigator.pop(context, _AiImageChoice(style: _style, keywords: keywords));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: posMobileSheetHeight(context), maxWidth: 520),
        child: Material(
          color: PosTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Generate an image',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(widget.itemName, style: TextStyle(color: PosTheme.inkMuted, fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final style in _styles)
                      ChoiceChip(
                        label: Text(style.$2),
                        selected: _style == style.$1,
                        selectedColor: accent.withValues(alpha: 0.16),
                        onSelected: (_) => setState(() => _style = style.$1),
                      ),
                  ],
                ),
                if (_style == 'custom') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keywords,
                    decoration: const InputDecoration(
                      labelText: 'Describe the photo',
                      hintText: 'Gold bowl, steam, dark wood',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(onPressed: _use, child: const Text('Generate')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
