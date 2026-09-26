import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/platform_config.dart';
import 'config/pos_app_info.dart';
import 'l10n/pos_l10n.dart';
import 'providers/cart_quick_pay_settings.dart';
import 'providers/pos_catalog_layout_settings.dart';
import 'providers/pos_category_bar_settings.dart';
import 'providers/kitchen_controller.dart';
import 'providers/kitchen_kot_filter_order.dart';
import 'providers/pos_controller.dart';
import 'providers/pos_idle_lock_controller.dart';
import 'providers/pos_locale_controller.dart';
import 'providers/pos_theme_controller.dart';
import 'screens/context_picker_screen.dart';
import 'screens/kitchen/kitchen_shell.dart';
import 'screens/lock_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mode_picker_screen.dart';
import 'screens/pair_device_screen.dart';
import 'screens/pos_billing_screen.dart';
import 'screens/pos_bootstrap_screen.dart';
import 'screens/pos_shell.dart';
import 'screens/setup_screen.dart';
import 'screens/terminal_picker_screen.dart';
import 'screens/waiter/waiter_shell.dart';
import 'services/offline/offline.dart';
import 'services/pos_api.dart';
import 'services/pos_cart_sound.dart';
import 'services/pos_display_mode.dart';
import 'services/printing/pos_channel_print_policy.dart';
import 'services/printing/print_job_coordinator.dart';
import 'services/printing/printer_status_service.dart';
import 'services/scanner_connection_service.dart';
import 'services/window_close/window_close_guard.dart';
import 'payments/payment_session_manager.dart';
import 'theme/pos_theme.dart';
import 'widgets/kot_print_failure_host.dart';
import 'widgets/pos_idle_lock_scope.dart';
import 'widgets/pos_language_switcher.dart';
import 'widgets/pos_navigator.dart';
import 'widgets/pos_ui.dart';

class ServeAiPosApp extends StatefulWidget {
  const ServeAiPosApp({super.key});

  @override
  State<ServeAiPosApp> createState() => _ServeAiPosAppState();
}

class _ServeAiPosAppState extends State<ServeAiPosApp>
    with WidgetsBindingObserver {
  late final PosController _posController;
  late final PosLocaleController _localeController;
  late final PosThemeController _themeController;
  late final PosIdleLockController _idleLockController;
  late final ConnectivityService _connectivity;
  late final OrderSyncService _syncService;
  late final PrinterStatusService _printerStatus;
  late final PrintJobCoordinator _printJobs;
  ScannerConnectionService? _scannerStatusOrNull;
  late final KitchenController _kitchenController;
  late final KitchenKotFilterOrder _kotFilterOrder;
  late final CartQuickPaySettings _quickPaySettings;
  late final PosCategoryBarSettings _categoryBarSettings;
  late final PosCatalogLayoutSettings _catalogLayoutSettings;
  late final PosApi _api;
  late final WindowCloseGuard _windowCloseGuard;

  ScannerConnectionService get _scannerStatus {
    final existing = _scannerStatusOrNull;
    if (existing != null) return existing;
    final created = ScannerConnectionService();
    _scannerStatusOrNull = created;
    created.start();
    return created;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = PosApi();
    _connectivity = ConnectivityService();
    _syncService = OrderSyncService(api: _api, connectivity: _connectivity);
    _printerStatus = PrinterStatusService();
    _printJobs = PrintJobCoordinator();
    _kitchenController = KitchenController(api: _api, printJobs: _printJobs);
    _kotFilterOrder = KitchenKotFilterOrder();
    unawaited(_kotFilterOrder.load());
    _quickPaySettings = CartQuickPaySettings();
    unawaited(_quickPaySettings.load());
    _categoryBarSettings = PosCategoryBarSettings();
    unawaited(_categoryBarSettings.load());
    _catalogLayoutSettings = PosCatalogLayoutSettings();
    unawaited(_catalogLayoutSettings.load());
    _localeController = PosLocaleController()..load();
    _themeController = PosThemeController()..load();
    _idleLockController = PosIdleLockController()..load();

    _posController = PosController(
      api: _api,
      connectivity: _connectivity,
      syncService: _syncService,
      printJobs: _printJobs,
      // Apply language catalogs as soon as bootstrap lands — do not rely only
      // on the overlay sync widget (avoids race with prefs cache load).
      onBootstrapChanged: (bootstrap) =>
          _localeController.syncFromBootstrap(bootstrap),
    );
    _printJobs.attach(
      session: () => _posController.session,
      serverUrl: () => _posController.serverUrl,
      printerStatus: _printerStatus,
    );
    PosChannelPrintPolicy.lookup =
        () => PosChannelPrintPolicy.fromBootstrap(_posController.bootstrap);
    _printerStatus.addListener(_onPrinterHealth);

    _connectivity.initialize();
    _posController.initialize();
    _printerStatus.start();
    _scannerStatus.start();
    unawaited(PosCartSound.instance.warmUp());
    _windowCloseGuard = WindowCloseGuard(onCloseRequest: _confirmWindowClose);
    unawaited(_windowCloseGuard.install());
  }

  void _onPrinterHealth() {
    _printJobs.onHealthChanged(_printerStatus.health);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity.dispose();
    _syncService.dispose();
    _printerStatus.removeListener(_onPrinterHealth);
    _printJobs.dispose();
    _printerStatus.dispose();
    _scannerStatusOrNull?.dispose();
    _kitchenController.dispose();
    _kotFilterOrder.dispose();
    _quickPaySettings.dispose();
    _categoryBarSettings.dispose();
    _catalogLayoutSettings.dispose();
    _posController.dispose();
    _localeController.dispose();
    _themeController.dispose();
    _idleLockController.dispose();
    _windowCloseGuard.dispose();
    super.dispose();
  }

  Future<bool> _confirmWindowClose() async {
    final dialogContext = posRootNavigatorKey.currentContext;
    if (!mounted || dialogContext == null) return false;

    final pos = _posController;
    final busyCart = pos.cart.isNotEmpty;
    final pendingQr = PaymentSessionManager.instance.activeSessions.isNotEmpty;
    final message = busyCart || pendingQr
        ? 'There is an open ticket or unpaid QR. Close the POS anyway?'
        : 'Are you sure you want to close the POS app?';

    return showPosConfirmDialog(
      dialogContext,
      title: 'Exit POS?',
      message: message,
      confirmLabel: 'Exit',
      icon: Icons.logout_rounded,
      destructive: busyCart || pendingQr,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PosDisplayMode.apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _api),
        ChangeNotifierProvider.value(value: _posController),
        ChangeNotifierProvider.value(value: _localeController),
        ChangeNotifierProvider.value(value: _themeController),
        ChangeNotifierProvider.value(value: _idleLockController),
        ChangeNotifierProvider.value(value: _connectivity),
        ChangeNotifierProvider.value(value: _syncService),
        ChangeNotifierProvider.value(value: _printerStatus),
        ChangeNotifierProvider.value(value: _printJobs),
        ChangeNotifierProvider.value(value: _scannerStatus),
        ChangeNotifierProvider.value(value: _kitchenController),
        ChangeNotifierProvider.value(value: _kotFilterOrder),
        ChangeNotifierProvider.value(value: _quickPaySettings),
        ChangeNotifierProvider.value(value: _categoryBarSettings),
        ChangeNotifierProvider.value(value: _catalogLayoutSettings),
      ],
      child: Consumer2<PosLocaleController, PosThemeController>(
        builder: (context, localeController, themeController, _) {
          return MaterialApp(
            title: PosAppInfo.displayName,
            navigatorKey: posRootNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: PosTheme.build(brightness: Brightness.light),
            darkTheme: PosTheme.build(brightness: Brightness.dark),
            themeMode: themeController.mode,
            locale: localeController.locale,
            supportedLocales: [
              ...{
                for (final locale in [
                  ...PosLocales.all,
                  ...localeController.availableLocales,
                ])
                  locale.languageCode: locale,
              }.values,
            ],
            localizationsDelegates: PosLocales.delegatesFor(
              localeController.catalogGeneration,
            ),
            localeResolutionCallback: PosLocales.resolve,
            builder: (context, child) {
              final brightness = Theme.of(context).brightness;
              PosTheme.applyBrightness(brightness);
              // Logo assets sit on a black plate — keep the window black while
              // connecting so the light app canvas doesn’t flash behind splash.
              final phase = context.select((PosController p) => p.phase);
              final locked = phase == PosAppPhase.locked;
              final canvas = phase == PosAppPhase.loading
                  ? Colors.black
                  : PosTheme.canvas;
              // Idle lock + PIN overlay sit above the navigator so Manage and
              // other pushed routes still count as activity and stay covered.
              return ColoredBox(
                color: canvas,
                child: PosThemeBrightness(
                  brightness: brightness,
                  child: PosIdleLockScope(
                    child: PosKeyboardDismiss(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TickerMode(
                            enabled: !locked,
                            child: IgnorePointer(
                              ignoring: locked,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  child ?? const SizedBox.shrink(),
                                  const PosLocaleBootstrapSync(),
                                ],
                              ),
                            ),
                          ),
                          if (locked) const LockScreen(),
                          const KotPrintFailureHost(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            home: const _RootRouter(),
          );
        },
      ),
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> with WidgetsBindingObserver {
  Timer? _mobileBackgroundLockTimer;

  /// Phone/tablet: lock after the app stays backgrounded briefly.
  /// Desktop: never lock from lifecycle — macOS fires `hidden`/`paused` during
  /// display scaling and resolution changes. Idle auto-lock covers walk-away.
  bool get _useLifecycleBackgroundLock {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _mobileBackgroundLockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || !_useLifecycleBackgroundLock) return;

    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive) {
      _mobileBackgroundLockTimer?.cancel();
      _mobileBackgroundLockTimer = null;
      return;
    }

    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }

    // Debounce: ignore brief OS transitions (display switch, image picker, etc.).
    _mobileBackgroundLockTimer?.cancel();
    _mobileBackgroundLockTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != AppLifecycleState.paused &&
          lifecycle != AppLifecycleState.hidden) {
        return;
      }
      final pos = context.read<PosController>();
      final autoLock = context.read<PosIdleLockController>().enabled;
      if (autoLock &&
          pos.phase == PosAppPhase.ready &&
          pos.session?.hasPosPin == true) {
        pos.lockSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PosController>(
      builder: (context, pos, _) {
        final signedIn = pos.phase == PosAppPhase.ready ||
            pos.phase == PosAppPhase.locked;
        return _KitchenWhileSignedIn(
          signedIn: signedIn,
          child: _signedInShell(context, pos),
        );
      },
    );
  }

  Widget _signedInShell(BuildContext context, PosController pos) {
        switch (pos.phase) {
          case PosAppPhase.loading:
            return const PosBootstrapScreen();
          case PosAppPhase.setup:
            return const SetupScreen();
          case PosAppPhase.pairDevice:
            return const PairDeviceScreen();
          case PosAppPhase.login:
            return const LoginScreen();
          case PosAppPhase.contextPicker:
            return const ContextPickerScreen();
          case PosAppPhase.modePicker:
            return const ModePickerScreen();
          case PosAppPhase.terminalPicker:
            return const TerminalPickerScreen();
          case PosAppPhase.locked:
          case PosAppPhase.ready:
            // Keep the shell mounted while locked (PIN overlay is in
            // MaterialApp.builder) so Manage routes survive unlock.
            return pos.workMode == PosWorkMode.waiter
                ? const WaiterShell()
                : pos.workMode == PosWorkMode.kitchen
                    ? const KitchenShell()
                    : const PosShell();
          case PosAppPhase.error:
            final accent = Theme.of(context).colorScheme.primary;
            final l10n = context.l10n;
            final subscriptionBlocked = pos.subscriptionBlocked;
            final title = subscriptionBlocked
                ? (pos.trialExpired
                      ? l10n.subscriptionTrialEndedTitle
                      : l10n.subscriptionEndedTitle)
                : l10n.commonSomethingWentWrong;
            final body = subscriptionBlocked && pos.canManageBilling
                ? (pos.trialExpired
                      ? l10n.billingUpgradeBody
                      : l10n.billingRenewBody)
                : (pos.errorMessage ??
                      (subscriptionBlocked
                          ? (pos.trialExpired
                                ? l10n.subscriptionTrialEndedBody
                                : l10n.subscriptionEndedBody)
                          : l10n.connUnableToReach));
            return PosAuthScaffold(
              accent: accent,
              statusIcon: subscriptionBlocked
                  ? Icons.workspace_premium_outlined
                  : Icons.error_outline_rounded,
              statusLabel: subscriptionBlocked
                  ? l10n.subscriptionEndedTitle
                  : l10n.connIssueTitle,
              headline: PosAppInfo.displayName,
              fallbackIcon: subscriptionBlocked
                  ? Icons.workspace_premium_outlined
                  : Icons.wifi_off_rounded,
              footerNote: subscriptionBlocked
                  ? (pos.canManageBilling
                        ? l10n.billingUpgradeFooter
                        : l10n.subscriptionEndedFooter)
                  : l10n.connIssueFooter,
              showClock: false,
              form: PosSurfaceCard(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      subscriptionBlocked
                          ? Icons.workspace_premium_outlined
                          : Icons.error_outline_rounded,
                      size: 48,
                      color: subscriptionBlocked
                          ? Colors.amber.shade800
                          : Colors.red.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(letterSpacing: -0.3),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    if (subscriptionBlocked) ...[
                      if (pos.canManageBilling) ...[
                        PosPrimaryButton(
                          label: l10n.billingUpgradePlan,
                          icon: Icons.workspace_premium_outlined,
                          color: accent,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PosBillingScreen(
                                  fromSubscriptionBlock: true,
                                ),
                              ),
                            );
                          },
                        ),
                        TextButton(
                          onPressed: () => pos.initialize(),
                          child: Text(l10n.commonRetry),
                        ),
                        TextButton(
                          onPressed: () => pos.logout(),
                          child: Text(l10n.commonSignOut),
                        ),
                      ] else ...[
                        PosPrimaryButton(
                          label: l10n.commonSignOut,
                          icon: Icons.logout_rounded,
                          color: accent,
                          onPressed: () => pos.logout(),
                        ),
                        TextButton(
                          onPressed: () => pos.initialize(),
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ] else ...[
                      PosPrimaryButton(
                        label: l10n.commonRetry,
                        icon: Icons.refresh_rounded,
                        color: accent,
                        onPressed: () => pos.initialize(),
                      ),
                      if (PlatformConfig.allowCustomServerUrl)
                        TextButton(
                          onPressed: () => pos.resetServer(),
                          child: Text(l10n.commonChangeServer),
                        ),
                    ],
                  ],
                ),
              ),
            );
        }
  }
}

class _KitchenWhileSignedIn extends StatefulWidget {
  const _KitchenWhileSignedIn({
    required this.signedIn,
    required this.child,
  });

  final bool signedIn;
  final Widget child;

  @override
  State<_KitchenWhileSignedIn> createState() => _KitchenWhileSignedInState();
}

class _KitchenWhileSignedInState extends State<_KitchenWhileSignedIn> {
  @override
  void didUpdateWidget(covariant _KitchenWhileSignedIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signedIn && !widget.signedIn) {
      context.read<KitchenController>().stop();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
