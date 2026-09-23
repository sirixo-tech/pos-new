import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../providers/pos_controller.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/new_order_alert_banner.dart';
import 'waiter_alerts_screen.dart';
import 'waiter_order_screen.dart';
import 'waiter_orders_screen.dart';
import 'waiter_profile_screen.dart';
import 'waiter_tables_screen.dart';

/// Phone-first captain / waiter shell with bottom navigation.
class WaiterShell extends StatefulWidget {
  const WaiterShell({super.key});

  @override
  State<WaiterShell> createState() => _WaiterShellState();
}

class _WaiterShellState extends State<WaiterShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _ordering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PosController>().refreshAlertsOnResume();
    }
  }

  void openOrderEntry() {
    setState(() {
      _ordering = true;
      _tab = 0;
    });
  }

  void closeOrderEntry() {
    setState(() => _ordering = false);
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final l10n = context.l10n;
    final unreadAlerts =
        context.select((PosController p) => p.waiterUnreadAlertCount);
    // Floor / captain tickets — not register Held drafts.
    final orderCount =
        context.select((PosController p) => p.waiterRecentOrders.length);

    if (_ordering) {
      return WaiterOrderScreen(onClose: closeOrderEntry);
    }

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: [
              WaiterTablesScreen(onOpenOrder: openOrderEntry),
              WaiterOrdersScreen(onAddMore: openOrderEntry),
              const WaiterAlertsScreen(),
              WaiterProfileScreen(
                onSwitchToRegister: () async {
                  final pos = context.read<PosController>();
                  await pos.switchWorkMode(PosWorkMode.register);
                },
              ),
            ],
          ),
          const NewOrderAlertBannerHost(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        labelBehavior: MediaQuery.sizeOf(context).width < 420
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.table_restaurant_outlined),
            selectedIcon: const Icon(Icons.table_restaurant_rounded),
            label: l10n.waiterNavTables,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: orderCount > 0,
              label: Text('$orderCount'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: orderCount > 0,
              label: Text('$orderCount'),
              child: const Icon(Icons.receipt_long_rounded),
            ),
            label: l10n.waiterNavOrders,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadAlerts > 0,
              label: Text('$unreadAlerts'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadAlerts > 0,
              label: Text('$unreadAlerts'),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: l10n.waiterNavAlerts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.waiterNavProfile,
          ),
        ],
      ),
    );
  }
}
