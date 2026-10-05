import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/pos_controller.dart';
import '../../models/pos_models.dart';
import '../../services/pos_api.dart';
import '../../utils/pos_user_facing_error.dart';
import '../../utils/menu_import_file_types.dart';
import '../../utils/menu_import_retry.dart';
import 'menu_import_view.dart';
import 'admin_shell.dart';
import '../../services/menu_spreadsheet_export.dart';
import '../../services/menu_export_download.dart';

class AdminMenuImportScreen extends StatefulWidget {
  const AdminMenuImportScreen({super.key});

  @override
  State<AdminMenuImportScreen> createState() => _AdminMenuImportScreenState();
}

class _AdminMenuImportScreenState extends State<AdminMenuImportScreen> {
  Map<String, dynamic>? _caps;
  Map<String, dynamic>? _import;
  List<Map<String, dynamic>> _rows = [];
  Timer? _timer;
  bool _busy = false;
  bool _polling = false;
  int _pollFailures = 0;
  bool _ai = true;
  String? _error;
  String? _errors;
  XFile? _selectedFile;
  int _selectedBytes = 0;
  PosSession? _adminSession;
  PosSession get _session {
    final current = _pos.session;
    final admin = _adminSession;
    if (current == null ||
        admin == null ||
        current.serverUrl != admin.serverUrl ||
        current.restaurantId != admin.restaurantId ||
        current.branchId != admin.branchId ||
        current.userId != admin.userId) {
      throw PosApiException(
        'Reopen menu upload to refresh your admin session.',
      );
    }
    return admin;
  }

  PosApi get _api => context.read<PosApi>();
  PosController get _pos => context.read<PosController>();
  int? get _id => int.tryParse('${_import?['id']}');
  String get _status => '${_import?['status'] ?? ''}'.toLowerCase();
  bool get _review =>
      _rows.isNotEmpty &&
      !_terminal &&
      !{
        'pending',
        'queued',
        'processing',
        'importing',
        'confirmed',
      }.contains(_status);
  bool get _terminal => {
    'completed',
    'complete',
    'failed',
    'cancelled',
    'canceled',
  }.contains(_status);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = posUserFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _accept(Map<String, dynamic> value) {
    if (!mounted) return;
    setState(() {
      _import = value;
      _rows = (value['draft_rows'] is List ? value['draft_rows'] as List : [])
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    });
    _timer?.cancel();
    if (!_terminal && !_review) {
      _timer = Timer(const Duration(seconds: 3), _poll);
    }
  }

  Future<void> _load() => _run(() async {
    final current = _pos.session;
    if (current == null) throw PosApiException('Not signed in.');
    final admin = await _api.createMenuImportSession(current);
    if (!mounted) return;
    _adminSession = admin;
    final data = await _api.menuImportGet(_session);
    if (!mounted) return;
    setState(() {
      _caps = Map<String, dynamic>.from(data['capabilities'] as Map? ?? {});
      _ai = _caps?['ai_assist_available'] == true;
    });
    if (data['active_import'] is Map) {
      _accept(Map<String, dynamic>.from(data['active_import'] as Map));
    }
  });

  Future<void> _poll() async {
    _timer?.cancel();
    if (!mounted || _terminal || _review) return;
    if (_id == null || _polling || _busy) {
      if (mounted && _id != null) {
        _timer = Timer(const Duration(seconds: 3), _poll);
      }
      return;
    }
    _polling = true;
    final importId = _id;
    try {
      final data = await _api.menuImportGet(_session, importId);
      if (!mounted || _id != importId || _terminal) return;
      _pollFailures = 0;
      setState(() => _error = null);
      _accept(data);
      if ({'completed', 'complete'}.contains(_status)) {
        await _pos.refreshBootstrap();
      }
    } catch (e) {
      if (!mounted || _id != importId || _terminal) return;
      final delay = menuImportRetryDelay(e, ++_pollFailures);
      setState(
        () => _error = delay == null
            ? posUserFacingError(e)
            : e is TimeoutException
            ? 'The status check took too long. Your menu is uploaded. Checking again automatically.'
            : 'Unable to refresh import progress. Your menu is uploaded. Checking again automatically.',
      );
      if (delay != null) _timer = Timer(delay, _poll);
    } finally {
      _polling = false;
    }
  }

  Future<void> _pick({bool camera = false}) => _run(() async {
    final file = camera
        ? await ImagePicker().pickImage(source: ImageSource.camera)
        : await openFile();
    if (file == null) return;
    final maxKb = num.tryParse('${_caps?['max_upload_kb']}') ?? 20480;
    if (await file.length() > maxKb * 1024) {
      throw PosApiException('Choose a file smaller than ${maxKb / 1024} MB.');
    }
    final ext = file.name.split('.').last.toLowerCase();
    final accepted = (_caps?['accepted_mimes'] as List? ?? [])
        .map((e) => '$e')
        .toList();
    if (!acceptsMenuImportFile(file.name, accepted)) {
      throw PosApiException(
        'This file type is not accepted. Supported types: ${accepted.join(', ')}',
      );
    }
    if (ext == 'pdf' &&
        {
          'false',
          '0',
          'unavailable',
          'disabled',
        }.contains('${_caps?['pdf_import_available']}')) {
      throw PosApiException('PDF import is unavailable.');
    }
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext) &&
        _caps?['image_import_available'] != true) {
      throw PosApiException('Image import is unavailable.');
    }
    final bytes = await file.length();
    if (!mounted) return;
    setState(() {
      _selectedFile = file;
      _selectedBytes = bytes;
      _ai =
          !['csv', 'xlsx'].contains(ext) &&
          _caps?['ai_assist_available'] == true;
    });
  });

  Future<void> _upload() => _run(() async {
    final file = _selectedFile;
    if (file == null) return;
    final data = await _api.menuImportUpload(
      _session,
      file: file,
      aiAssist: _ai,
    );
    final id = int.tryParse('${data['import_id']}');
    if (id == null) {
      throw PosApiException('The server did not return an import ID.');
    }
    if (!mounted) return;
    _accept({'id': id, 'status': 'queued', 'filename': file.name});
    _pollFailures = 0;
  });

  Future<void> _save({bool confirm = false}) => _run(() async {
    final id = _id!;
    for (final row in _rows.where(
      (r) => r['_delete'] != true && r['deleted'] != true,
    )) {
      if ('${row['item_name'] ?? ''}'.trim().isEmpty ||
          '${row['category_name'] ?? ''}'.trim().isEmpty ||
          (num.tryParse('${row['price']}') ?? -1) < 0) {
        throw PosApiException(
          'Each item needs a category, name, and valid non-negative price.',
        );
      }
    }
    final data = await _api.menuImportAction(
      _session,
      id,
      'draft',
      rows: _rows,
    );
    if (!mounted) return;
    _accept(data);
    if (confirm) {
      await _api.menuImportAction(_session, id, 'confirm');
      if (!mounted) return;
      _accept({...data, 'status': 'importing'});
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft edits saved')));
    }
  });

  Future<void> _edit(int index) async {
    final row = Map<String, dynamic>.from(_rows[index]);
    const fields = [
      'category_name',
      'item_name',
      'price',
      'item_type',
      'is_available',
      'item_description',
      'variant_name',
      'variant_price',
      'modifier_name',
      'modifier_type',
      'modifier_is_required',
      'modifier_min_selections',
      'modifier_max_selections',
      'option_name',
      'option_price_adjustment',
      'image_url',
    ];
    final controllers = {
      for (final key in fields)
        key: TextEditingController(text: '${row[key] ?? ''}'),
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review menu item'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fields
                  .map(
                    (key) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: controllers[key],
                        decoration: InputDecoration(
                          labelText: key.replaceAll('_', ' '),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        for (final key in fields) {
          row[key] = controllers[key]!.text.trim();
        }
        _rows[index] = row;
      });
    }
    // Dialog route animations may still use its controllers briefly.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  Future<void> _image(int index) => _run(() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Images',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        ),
      ],
    );
    if (file == null) return;
    await _api.menuImportAction(_session, _id!, 'draft', rows: _rows);
    final data = await _api.menuImportUpload(
      _session,
      file: file,
      id: _id,
      rowIndex: index,
    );
    if (mounted) _accept({..._import!, 'draft_rows': data['draft_rows']});
  });

  Future<void> _cancel() => _run(() async {
    await _api.menuImportAction(_session, _id!, 'cancel');
    if (mounted) _accept({..._import!, 'status': 'cancelled'});
  });

  Future<void> _export(
    String format,
    MenuExportOptions options, {
    bool template = false,
  }) => _run(() async {
    final rows = template
        ? <Map<String, dynamic>>[]
        : MenuSpreadsheetExport.rows(
            await _api.fetchMenuExportData(_session),
            options,
          );
    final isExcel = format == 'xlsx';
    final bytes = isExcel
        ? MenuSpreadsheetExport.excel(rows)
        : MenuSpreadsheetExport.csv(rows);
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final bootstrap = _pos.bootstrap;
    String slug(String value) => value
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final filename = template
        ? 'menu-import-template.$format'
        : 'menu-export-${slug(bootstrap?.restaurant.name ?? 'restaurant')}-${slug(bootstrap?.branch.name ?? 'branch')}-$date.$format';
    final saved = await saveMenuExport(
      bytes,
      filename,
      isExcel
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'text/csv',
    );
    if (mounted && saved != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved $filename')));
    }
  });

  @override
  Widget build(BuildContext context) => MenuImportView(
    capabilities: _caps,
    import: _import,
    rows: _rows,
    review: _review,
    terminal: _terminal,
    busy: _busy,
    ai: _ai,
    error: _error,
    errors: _errors,
    selectedFile: _selectedFile,
    selectedBytes: _selectedBytes,
    onPick: () => _pick(),
    onCamera: () => _pick(camera: true),
    onUpload: _upload,
    onClear: () => setState(() {
      _selectedFile = null;
      _selectedBytes = 0;
    }),
    onAiChanged: (value) => setState(() => _ai = value),
    onRetry: () => _id == null ? _load() : _poll(),
    onSave: () => _save(),
    onConfirm: () => _save(confirm: true),
    onCancel: _cancel,
    onEdit: _edit,
    onImage: _image,
    onRowChanged: (index, key, value) =>
        setState(() => _rows[index][key] = value),
    onDelete: (index) => setState(() {
      final row = _rows[index];
      final deleted = row['_delete'] == true || row['deleted'] == true;
      row['_delete'] = !deleted;
      row['deleted'] = !deleted;
    }),
    onErrors: () => _run(() async {
      final value = await _api.menuImportErrors(_session, _id!);
      if (mounted) setState(() => _errors = value);
    }),
    onExport: (format, options) => _export(format, options),
    onTemplate: () => _export('xlsx', MenuExportOptions(), template: true),
    onViewMenu: () =>
        openPosAdminShell(context, initialSection: AdminShellSection.menu),
    onOpenPos: () => Navigator.of(context).popUntil((route) => route.isFirst),
    onAnother: () => setState(() {
      _timer?.cancel();
      _import = null;
      _rows = [];
      _selectedFile = null;
      _selectedBytes = 0;
      _error = null;
      _errors = null;
    }),
  );
}
