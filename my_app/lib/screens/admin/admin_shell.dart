import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../providers/pos_admin_controller.dart';
import '../../providers/pos_controller.dart';
import '../../providers/pos_locale_controller.dart';
import '../../services/pos_api.dart';
import '../../services/printing/pos_receipt_printer.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/day_end_reports_sheet.dart';
import '../../widgets/pos_overlay.dart';
import '../../widgets/pos_ui.dart';
import '../pos_billing_screen.dart';
import 'admin_chrome.dart';
import 'admin_menu_screen.dart';
import 'admin_menu_import_screen.dart';
import 'admin_modifiers_screen.dart';
import 'admin_opening_hours_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_tables_screen.dart';
import 'admin_time_slots_screen.dart';

enum AdminShellSection { hub, menu, tables, orders }

Future<void> openPosAdminShell(
  BuildContext context, {
  AdminShellSection initialSection = AdminShellSection.hub,
}) async {
  final pos = context.read<PosController>();
  final api = context.read<PosApi>();
  try {
    await pos.refreshBootstrap();
  } on PosApiException catch (e) {
    if (e.isSubscriptionBlocked) rethrow;
  } catch (_) {}
  if (!context.mounted) return;
  if (pos.staffAdminCapabilities.canAccessAdmin != true) return;
  if (initialSection == AdminShellSection.menu && !pos.canViewStaffMenu) return;
  if (initialSection == AdminShellSection.orders && !pos.canViewStaffOrders) {
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => PosAdminController(api: api, pos: pos),
        child: AdminShell(initialSection: initialSection),
      ),
    ),
  );
  if (context.mounted) {
    await pos.refreshBootstrap();
  }
}

/// Menu manager in the same overlay style as the table picker.
Future<void> openPosAdminMenuSheet(BuildContext context) async {
  final pos = context.read<PosController>();
  final api = context.read<PosApi>();
  if (!pos.canViewStaffMenu) return;

  final accent = Theme.of(context).colorScheme.primary;
  final screenWidth = MediaQuery.sizeOf(context).width;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    // Material caps bottom sheets at 640. The menu needs the window width.
    constraints: BoxConstraints(maxWidth: screenWidth),
    builder: (sheetContext) {
      return ChangeNotifierProvider(
        create: (_) => PosAdminController(api: api, pos: pos),
        child: PosKeyboardSheetHost(
          child: _AdminMenuPickerSheet(accent: accent),
        ),
      );
    },
  );
  if (context.mounted) {
    await pos.refreshBootstrap();
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.initialSection = AdminShellSection.hub});

  final AdminShellSection initialSection;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late AdminShellSection _section = widget.initialSection;

  Future<void> _openReports() async {
    if (!PosReceiptPrinter.isSupported) {
      showPosSnackBar(
        context,
        PosReceiptPrinter.unsupportedMessage,
        error: true,
      );
      return;
    }

    await DayEndReportsSheet.open(context, onPrint: _printThermalReport);
  }

  Future<void> _printThermalReport(String type) async {
    final pos = context.read<PosController>();
    final session = pos.session;
    final serverUrl = pos.serverUrl;
    if (session == null || serverUrl == null) {
      if (mounted) {
        showPosSnackBar(context, context.l10n.authNotSignedIn, error: true);
      }
      throw StateError(context.l10n.authNotSignedIn);
    }

    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      await PosReceiptPrinter.printThermalReport(
        session: session,
        serverUrl: serverUrl,
        type: type,
        dateFrom: today,
        dateTo: today,
      );
      if (!mounted) return;
      showPosSnackBar(context, context.l10n.reportsSentToPrinter);
    } catch (e) {
      if (mounted) {
        showPosErrorSnackBar(context, e);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final admin = context.watch<PosAdminController>();
    final pos = context.watch<PosController>();
    // Rebuild when remote catalogs refresh (posText / l10n both depend on this).
    context.watch<PosLocaleController>().catalogGeneration;
    final caps = admin.capabilities;
    final showMenu =
        caps.canViewMenu ||
        caps.canManageMenu ||
        caps.canManageMenuCategories ||
        caps.canManageMenuItems ||
        caps.canToggleMenuAvailability ||
        caps.canManageMenuModifiers ||
        caps.canManageMenuTimeSlots;
    final showTables = caps.canViewTables || caps.canManageTables;
    final showOrders = caps.canViewOrders || caps.canManageOrders;
    final showHours = caps.canManageSettings;
    final showReports = context.watch<PosController>().canViewStaffReports;
    final showBilling = caps.canManageBilling;
    if (!caps.canAccessAdmin) {
      return const Scaffold(body: Center(child: Text('Access denied')));
    }
    if ((_section == AdminShellSection.menu && !showMenu) ||
        (_section == AdminShellSection.tables && !showTables) ||
        (_section == AdminShellSection.orders && !showOrders)) {
      _section = AdminShellSection.hub;
    }

    final l10n = context.l10n;
    final title = switch (_section) {
      AdminShellSection.hub => l10n.adminManage,
      AdminShellSection.menu => l10n.adminMenu,
      AdminShellSection.tables => l10n.adminTables,
      AdminShellSection.orders => l10n.adminOrders,
    };

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (_section == AdminShellSection.hub && pos.bootstrap != null)
              Text(
                '${pos.bootstrap!.restaurant.name} · ${pos.bootstrap!.branch.name}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: PosTheme.inkMuted,
                ),
              ),
          ],
        ),
        leading:
            _section == AdminShellSection.hub ||
                _section == widget.initialSection
            ? null
            : IconButton(
                tooltip: context.posText('commonBack', 'Back'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () =>
                    setState(() => _section = AdminShellSection.hub),
              ),
        actions: [
          IconButton(
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: switch (_section) {
        AdminShellSection.hub => _AdminHub(
          showMenu: showMenu,
          showTables: showTables,
          showOrders: showOrders,
          showHours: showHours,
          showReports: showReports,
          showBilling: showBilling,
          canImportMenu: caps.canManageMenu || caps.canManageMenuItems,
          canManageModifiers: caps.canManageMenuModifiers || caps.canManageMenu,
          canManageTimeSlots: caps.canManageMenuTimeSlots || caps.canManageMenu,
          onOpen: (section) => setState(() => _section = section),
          onOpenModifiers: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider.value(
                  value: admin,
                  child: const AdminModifiersScreen(),
                ),
              ),
            );
          },
          onOpenTimeSlots: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider.value(
                  value: admin,
                  child: const AdminTimeSlotsScreen(),
                ),
              ),
            );
          },
          onOpenHours: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminOpeningHoursScreen(),
              ),
            );
          },
          onOpenBilling: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PosBillingScreen()),
            );
          },
          onOpenReports: _openReports,
        ),
        AdminShellSection.menu => const AdminMenuScreen(),
        AdminShellSection.tables => const AdminTablesScreen(),
        AdminShellSection.orders => const AdminOrdersScreen(),
      },
    );
  }
}

class _AdminHub extends StatelessWidget {
  const _AdminHub({
    required this.showMenu,
    required this.showTables,
    required this.showOrders,
    required this.showHours,
    required this.showReports,
    required this.showBilling,
    required this.canImportMenu,
    required this.canManageModifiers,
    required this.canManageTimeSlots,
    required this.onOpen,
    required this.onOpenModifiers,
    required this.onOpenTimeSlots,
    required this.onOpenHours,
    required this.onOpenBilling,
    required this.onOpenReports,
  });

  final bool showMenu;
  final bool showTables;
  final bool showOrders;
  final bool showHours;
  final bool showReports;
  final bool showBilling;
  final bool canImportMenu;
  final bool canManageModifiers;
  final bool canManageTimeSlots;
  final ValueChanged<AdminShellSection> onOpen;
  final VoidCallback onOpenModifiers;
  final VoidCallback onOpenTimeSlots;
  final VoidCallback onOpenHours;
  final VoidCallback onOpenBilling;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    context.watch<PosLocaleController>().catalogGeneration;
    final tiles = <_HubItem>[
      if (canImportMenu)
        _HubItem(
          icon: Icons.auto_awesome_rounded,
          title: context.posText('adminAiMenuUpload', 'AI Menu Upload'),
          subtitle: context.posText(
            'adminAiMenuUploadSubtitle',
            'Upload, review, and import your menu',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'ai-menu'),
              builder: (_) => const AdminMenuImportScreen(),
            ),
          ),
        ),
      if (showHours)
        _HubItem(
          icon: Icons.storefront_rounded,
          title: l10n.adminHours,
          subtitle: l10n.adminHoursSubtitle,
          onTap: onOpenHours,
        ),
      if (showBilling)
        _HubItem(
          icon: Icons.workspace_premium_outlined,
          title: l10n.billingTitle,
          subtitle: l10n.billingManageSubtitle,
          onTap: onOpenBilling,
        ),
      if (showMenu)
        _HubItem(
          icon: Icons.restaurant_menu_rounded,
          title: l10n.adminMenu,
          subtitle: context.posText(
            'adminMenuSubtitle',
            'Categories, items, and availability',
          ),
          onTap: () => onOpen(AdminShellSection.menu),
        ),
      if (canManageModifiers)
        _HubItem(
          icon: Icons.tune_rounded,
          title: l10n.adminModifiers,
          subtitle: context.posText(
            'adminModifiersSubtitle',
            'Option groups for menu items',
          ),
          onTap: onOpenModifiers,
        ),
      if (canManageTimeSlots)
        _HubItem(
          icon: Icons.schedule_rounded,
          title: l10n.adminTimeSlots,
          subtitle: context.posText(
            'adminTimeSlotsSubtitle',
            'Breakfast, lunch, dinner windows',
          ),
          onTap: onOpenTimeSlots,
        ),
      if (showTables)
        _HubItem(
          icon: Icons.table_restaurant_rounded,
          title: l10n.adminTables,
          subtitle: context.posText(
            'adminTablesSubtitle',
            'Areas, tables, and status',
          ),
          onTap: () => onOpen(AdminShellSection.tables),
        ),
      if (showOrders)
        _HubItem(
          icon: Icons.receipt_long_rounded,
          title: l10n.adminOrders,
          subtitle: context.posText(
            'adminOrdersSubtitle',
            'Search, status, and payments',
          ),
          onTap: () => onOpen(AdminShellSection.orders),
        ),
      if (showReports)
        _HubItem(
          icon: Icons.summarize_rounded,
          title: l10n.shellReports,
          subtitle: l10n.reportsSubtitle,
          onTap: onOpenReports,
        ),
    ];

    if (tiles.isEmpty) {
      return AdminEmptyPane(
        icon: Icons.lock_outline_rounded,
        title: context.posText(
          'adminNoSections',
          'No manage sections available.',
        ),
        subtitle: context.posText(
          'adminNoSectionsHint',
          'Ask an owner to grant menu, tables, or orders permissions.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final crossAxisCount = wide ? 2 : 1;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminManage,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.posText(
                        'adminHubHint',
                        'Manage restaurant settings available to your role.',
                      ),
                      style: TextStyle(
                        color: PosTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 108,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = tiles[index];
                  return AdminEntityCard(
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    onTap: item.onTap,
                  );
                }, childCount: tiles.length),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HubItem {
  const _HubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _AdminMenuPickerSheet extends StatelessWidget {
  const _AdminMenuPickerSheet({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    final size = MediaQuery.sizeOf(context);
    final maxHeight = posMobileSheetHeight(context);
    final available = size.width - (size.width >= 1100 ? 48 : 24);
    final sheetMaxWidth = available > 1280 ? 1280.0 : available;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: sheetMaxWidth,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: PosTheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PosTheme.radiusXl),
            ),
            border: size.width >= 900
                ? Border.all(color: PosTheme.border)
                : null,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: soft.bg,
                        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: soft.fg,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.adminMenu,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.2,
                              color: PosTheme.ink,
                            ),
                          ),
                          Text(
                            context.posText(
                              'adminMenuSubtitle',
                              'Categories, items, and availability',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: PosTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: PosTheme.border),
              const Expanded(child: AdminMenuScreen()),
            ],
          ),
        ),
      ),
    );
  }
}
