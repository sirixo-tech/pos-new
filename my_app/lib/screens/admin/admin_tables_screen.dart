import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../providers/pos_admin_controller.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_ui.dart';
import 'admin_chrome.dart';

class AdminTablesScreen extends StatefulWidget {
  const AdminTablesScreen({super.key});

  @override
  State<AdminTablesScreen> createState() => _AdminTablesScreenState();
}

class _AdminTablesScreenState extends State<AdminTablesScreen> {
  static const _statuses = ['available', 'occupied', 'reserved', 'cleaning'];
  int? _selectedAreaId; // null = all / unassigned focus for floor save

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosAdminController>().loadTables();
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<PosAdminController>();
    final payload = admin.tablesPayload;
    final canManage = admin.canManageTables;

    if (admin.tablesLoading && payload == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (admin.error != null && payload == null) {
      return AdminErrorPane(
        message: admin.error!,
        onRetry: admin.loadTables,
      );
    }

    final areas = payload?.areas ?? const <AdminTableArea>[];
    final unassigned = payload?.tablesWithoutArea ?? const <AdminTable>[];
    final isEmpty = (payload?.tables.isEmpty ?? true) && areas.isEmpty;

    return Column(
      children: [
        AdminToolbar(
          children: [
            if (canManage) ...[
              FilledButton.tonalIcon(
                onPressed:
                    admin.mutating ? null : () => _editArea(context, admin),
                icon: const Icon(Icons.layers_outlined, size: 18),
                label: Text(context.posText('adminNewArea', 'Area')),
              ),
              FilledButton.icon(
                onPressed:
                    admin.mutating ? null : () => _editTable(context, admin),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.posText('adminNewTable', 'Table')),
              ),
            ],
            IconButton.filledTonal(
              tooltip: context.l10n.commonRefresh,
              onPressed: admin.tablesLoading ? null : admin.loadTables,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        if (admin.error != null)
          AdminInlineError(
            message: admin.error!,
            onDismiss: admin.clearError,
          ),
        if (areas.isNotEmpty)
          Material(
            color: PosTheme.surface,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: PosTheme.border)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(context.posText('adminAllAreas', 'All')),
                      selected: _selectedAreaId == null,
                      onSelected: (_) =>
                          setState(() => _selectedAreaId = null),
                    ),
                    const SizedBox(width: 8),
                    for (final area in areas) ...[
                      ChoiceChip(
                        label: Text(area.name),
                        selected: _selectedAreaId == area.id,
                        onSelected: (_) =>
                            setState(() => _selectedAreaId = area.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ChoiceChip(
                      label: Text(context.posText('adminNoArea', 'No area')),
                      selected: _selectedAreaId == -1,
                      onSelected: (_) => setState(() => _selectedAreaId = -1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: admin.loadTables,
            child: isEmpty
                ? AdminEmptyPane(
                    icon: Icons.table_restaurant_rounded,
                    title: context.posText(
                      'adminTablesEmpty',
                      'No tables yet.',
                    ),
                    subtitle: context.posText(
                      'adminTablesEmptyHint',
                      'Create an area and add tables for your floor.',
                    ),
                    action: canManage
                        ? FilledButton.icon(
                            onPressed: admin.mutating
                                ? null
                                : () => _editTable(context, admin),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              context.posText('adminNewTable', 'Table'),
                            ),
                          )
                        : null,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      if (_selectedAreaId == null || _selectedAreaId == -1)
                        if (unassigned.isNotEmpty || _selectedAreaId == -1)
                          _AreaSection(
                            title: context.posText('adminNoArea', 'No area'),
                            tables: unassigned,
                            canManage: canManage,
                            busy: admin.mutating,
                            onEditArea: null,
                            onDeleteArea: null,
                            onEditTable: (t) =>
                                _editTable(context, admin, table: t),
                            onDeleteTable: (t) =>
                                _deleteTable(context, admin, t),
                            onStatus: (t, s) =>
                                admin.updateTableStatus(t.id, s),
                            statuses: _statuses,
                          ),
                      for (final area in areas)
                        if (_selectedAreaId == null ||
                            _selectedAreaId == area.id)
                          _AreaSection(
                            title: area.name,
                            tables: area.tables,
                            canManage: canManage,
                            busy: admin.mutating,
                            onEditArea: () =>
                                _editArea(context, admin, area: area),
                            onDeleteArea: () =>
                                _deleteArea(context, admin, area),
                            onEditTable: (t) => _editTable(
                              context,
                              admin,
                              table: t,
                              areaId: area.id,
                            ),
                            onDeleteTable: (t) =>
                                _deleteTable(context, admin, t),
                            onStatus: (t, s) =>
                                admin.updateTableStatus(t.id, s),
                            statuses: _statuses,
                          ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _editArea(
    BuildContext context,
    PosAdminController admin, {
    AdminTableArea? area,
  }) async {
    final nameCtrl = TextEditingController(text: area?.name ?? '');
    final saved = await showAdminPanel<bool>(
      context: context,
      sidePanelWidth: 420,
      builder: (ctx) => PosDialogShell(
        title: area == null
            ? context.posText('adminNewArea', 'Area')
            : context.posText('adminEditArea', 'Edit area'),
        icon: Icons.grid_view_rounded,
        embedded: true,
        onClose: () => Navigator.pop(ctx, false),
        body: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: context.posText('adminName', 'Name'),
          ),
          autofocus: true,
        ),
        footer: posDialogActionFooter(
          context: ctx,
          confirmLabel: context.l10n.commonSave,
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (saved != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (area == null) {
      await admin.createTableArea({'name': name});
    } else {
      await admin.updateTableArea(area.id, {'name': name});
    }
  }

  Future<void> _deleteArea(
    BuildContext context,
    PosAdminController admin,
    AdminTableArea area,
  ) async {
    final ok = await showPosConfirmDialog(
      context,
      title: context.posText('adminDeleteArea', 'Delete area?'),
      message: area.name,
      destructive: true,
    );
    if (!ok) return;
    await admin.deleteTableArea(area.id);
  }

  Future<void> _editTable(
    BuildContext context,
    PosAdminController admin, {
    AdminTable? table,
    int? areaId,
  }) async {
    final nameCtrl = TextEditingController(text: table?.name ?? '');
    final capacityCtrl = TextEditingController(
      text: table?.capacity?.toString() ?? '',
    );
    var selectedAreaId = table?.tableAreaId ?? areaId;
    var status = table?.status ?? 'available';
    final areas = admin.tablesPayload?.areas ?? const <AdminTableArea>[];

    final saved = await showAdminPanel<bool>(
      context: context,
      sidePanelWidth: 440,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return PosDialogShell(
              title: table == null
                  ? context.posText('adminNewTable', 'Table')
                  : context.posText('adminEditTable', 'Edit table'),
              icon: Icons.table_restaurant_rounded,
              maxWidth: 420,
              embedded: true,
              onClose: () => Navigator.pop(ctx, false),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: context.posText('adminName', 'Name'),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityCtrl,
                    decoration: InputDecoration(
                      labelText: context.posText('adminCapacity', 'Capacity'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedAreaId,
                    decoration: InputDecoration(
                      labelText: context.posText('adminArea', 'Area'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          context.posText('adminNoArea', 'No area'),
                        ),
                      ),
                      for (final a in areas)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => selectedAreaId = v),
                  ),
                  if (table != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: InputDecoration(
                        labelText: context.posText('adminStatus', 'Status'),
                      ),
                      items: [
                        for (final s in _statuses)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => status = v);
                      },
                    ),
                  ],
                ],
              ),
              footer: posDialogActionFooter(
                context: ctx,
                confirmLabel: context.l10n.commonSave,
                onCancel: () => Navigator.pop(ctx, false),
                onConfirm: () => Navigator.pop(ctx, true),
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final capacity = int.tryParse(capacityCtrl.text.trim());

    if (table == null) {
      await admin.createTable({
        'name': name,
        if (capacity != null) 'capacity': capacity,
        if (selectedAreaId != null) 'table_area_id': selectedAreaId,
      });
    } else {
      await admin.updateTable(table.id, {
        'name': name,
        'capacity': capacity,
        'table_area_id': selectedAreaId,
        'status': status,
      });
    }
  }

  Future<void> _deleteTable(
    BuildContext context,
    PosAdminController admin,
    AdminTable table,
  ) async {
    final ok = await showPosConfirmDialog(
      context,
      title: context.posText('adminDeleteTable', 'Delete table?'),
      message: table.name,
      destructive: true,
    );
    if (!ok) return;
    await admin.deleteTable(table.id);
  }
}

class _AreaSection extends StatelessWidget {
  const _AreaSection({
    required this.title,
    required this.tables,
    required this.canManage,
    required this.busy,
    required this.onEditArea,
    required this.onDeleteArea,
    required this.onEditTable,
    required this.onDeleteTable,
    required this.onStatus,
    required this.statuses,
  });

  final String title;
  final List<AdminTable> tables;
  final bool canManage;
  final bool busy;
  final VoidCallback? onEditArea;
  final VoidCallback? onDeleteArea;
  final ValueChanged<AdminTable> onEditTable;
  final ValueChanged<AdminTable> onDeleteTable;
  final void Function(AdminTable, String) onStatus;
  final List<String> statuses;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: PosTheme.ink,
                  ),
                ),
              ),
              AdminCountBadge(tables.length),
              if (canManage && onEditArea != null) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEditArea!();
                    if (v == 'delete') onDeleteArea?.call();
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
            ],
          ),
          const SizedBox(height: 10),
          if (tables.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.posText(
                  'adminNoTablesInArea',
                  'No tables in this area.',
                ),
                style: TextStyle(color: PosTheme.inkMuted, fontSize: 13),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final table in tables)
                  _TableCard(
                    table: table,
                    canManage: canManage,
                    busy: busy,
                    statuses: statuses,
                    onEdit: () => onEditTable(table),
                    onDelete: () => onDeleteTable(table),
                    onStatus: (s) => onStatus(table, s),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.canManage,
    required this.busy,
    required this.statuses,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });

  final AdminTable table;
  final bool canManage;
  final bool busy;
  final List<String> statuses;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      width: 176,
      onTap: canManage && !busy ? onEdit : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  table.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: PosTheme.ink,
                  ),
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                    if (v.startsWith('status:')) {
                      onStatus(v.substring(7));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.posText('adminEdit', 'Edit')),
                    ),
                    const PopupMenuDivider(),
                    for (final s in statuses)
                      CheckedPopupMenuItem(
                        value: 'status:$s',
                        checked: table.status == s,
                        child: Text(s),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.posText('adminDelete', 'Delete')),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          PopupMenuButton<String>(
            enabled: canManage && !busy,
            tooltip: context.posText('adminStatus', 'Status'),
            onSelected: onStatus,
            itemBuilder: (_) => [
              for (final s in statuses)
                CheckedPopupMenuItem(
                  value: s,
                  checked: table.status == s,
                  child: Text(s),
                ),
            ],
            child: AdminChip.status(table.status),
          ),
          const SizedBox(height: 8),
          Text(
            table.capacity != null
                ? '${context.posText('adminCapacity', 'Capacity')}: ${table.capacity}'
                : context.posText('adminNoCapacity', 'No capacity set'),
            style: TextStyle(
              color: PosTheme.inkMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
