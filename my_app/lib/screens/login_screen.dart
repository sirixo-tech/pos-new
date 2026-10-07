import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/platform_config.dart';
import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/media_url.dart';
import '../utils/pos_animations.dart';
import '../widgets/pos_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _obscure = true;
  Timer? _clockTimer;
  Timer? _loginCooldownTimer;
  DateTime _now = DateTime.now();
  DateTime? _loginBlockedUntil;
  int _failedLogins = 0;

  bool get _loginBlocked {
    final until = _loginBlockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  int get _loginCooldownSeconds {
    final until = _loginBlockedUntil;
    if (until == null) return 0;
    final seconds = until.difference(DateTime.now()).inSeconds + 1;
    return seconds < 0 ? 0 : seconds;
  }

  void _startLoginCooldown(Duration duration) {
    _loginCooldownTimer?.cancel();
    setState(() => _loginBlockedUntil = DateTime.now().add(duration));
    _loginCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_loginBlocked) {
        timer.cancel();
        setState(() => _loginBlockedUntil = null);
        return;
      }
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _loginCooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loginBlocked) {
      showPosSnackBar(
        context,
        'Too many login attempts. Try again in $_loginCooldownSeconds seconds.',
        error: true,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final pos = context.read<PosController>();
      await pos.login(
            _emailController.text,
            _passwordController.text,
          );
      if (!mounted) return;
      final error = pos.errorMessage;
      if (error != null) {
        final rateLimited = pos.lastLoginStatusCode == 429 ||
            error.toLowerCase().contains('too many');
        if (rateLimited) {
          _startLoginCooldown(
            pos.lastLoginRetryAfter ?? const Duration(seconds: 61),
          );
        } else {
          _failedLogins += 1;
          if (_failedLogins >= 5) {
            _failedLogins = 0;
            _startLoginCooldown(const Duration(seconds: 30));
          }
        }
        showPosSnackBar(context, error, error: true);
      } else {
        _failedLogins = 0;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeServer(PosController pos) async {
    final currentServer = pos.serverUrl ?? PlatformConfig.platformUrl;
    final controller = TextEditingController(text: currentServer);
    String? localError;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.l10n.commonChangeServer),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enter the server address. Changing servers signs out this device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: context.l10n.setupServerUrl,
                        hintText: 'https://app.selfx.in',
                        prefixIcon: const Icon(Icons.dns_outlined),
                        errorText: localError,
                      ),
                      onSubmitted: (val) {
                        final normalized =
                            PlatformConfig.normalizeServerUrl(val);
                        if (normalized.isEmpty) {
                          setDialogState(
                            () => localError = 'Please enter a valid server URL.',
                          );
                        } else {
                          Navigator.of(dialogContext).pop(normalized);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(PosAppInfo.defaultServerUrl),
                  child: const Text('Use Default'),
                ),
                FilledButton(
                  onPressed: () {
                    final normalized =
                        PlatformConfig.normalizeServerUrl(controller.text);
                    if (normalized.isEmpty) {
                      setDialogState(
                        () => localError = 'Please enter a valid server URL.',
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(normalized);
                  },
                  child: Text(context.l10n.commonSave),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (result == null || result.trim().isEmpty || !mounted) return;

    await pos.saveServerUrl(result.trim());
    if (!mounted) return;
    showPosSnackBar(context, 'Server set to ${pos.serverUrl}');
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final binding = pos.deviceBinding;
    final platform = pos.bootstrap?.platform ?? const PosPlatformBranding();
    final platformName = platform.name.trim().isNotEmpty
        ? platform.name.trim()
        : PosAppInfo.displayName;
    final serverUrl = pos.serverUrl ?? PlatformConfig.platformUrl;
    final restaurant = pos.bootstrap?.restaurant;
    final restaurantName =
        restaurant?.name.trim().isNotEmpty == true
            ? restaurant!.name.trim()
            : binding?.restaurantName?.trim();
    final branchName = binding?.branchName?.trim() ??
        pos.bootstrap?.branch.name.trim();
    final terminalLabel = binding?.terminalName?.trim().isNotEmpty == true
        ? binding!.terminalName!.trim()
        : binding?.terminalCode;
    final logoUrl = resolveMediaUrl(
      restaurant?.logoUrl,
      serverUrl: serverUrl,
    );
    final location = [
      if (branchName != null && branchName.isNotEmpty) branchName,
      if (terminalLabel != null && terminalLabel.isNotEmpty) terminalLabel,
    ].join(' · ');
    final headline = restaurantName?.isNotEmpty == true
        ? restaurantName!
        : PosAppInfo.displayName;

    final form = PosSlideFade(
      child: PosSurfaceCard(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.authStaffSignIn,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              binding != null
                  ? l10n.authSignInOnce
                  : l10n.authUseStaffEmail,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (binding != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tablet_mac_rounded, color: soft.fg, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              binding.terminalName ?? binding.terminalCode,
                              binding.branchName,
                            ].whereType<String>().join(' · '),
                            style: TextStyle(
                              fontSize: 13,
                              color: soft.fg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.authThisRegisterPaired,
                            style: TextStyle(
                              fontSize: 11,
                              color: soft.fg.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              focusNode: _emailFocus,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              enableInteractiveSelection: true,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(
                labelText: l10n.authEmail,
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              enableInteractiveSelection: true,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: l10n.authPassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_loginBlocked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_clock_rounded,
                      size: 18,
                      color: Color(0xFFB91C1C),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Too many login attempts. Try again in $_loginCooldownSeconds seconds.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            PosPrimaryButton(
              label: _loginBlocked
                  ? 'Try again in $_loginCooldownSeconds s'
                  : l10n.authSignIn,
              icon: Icons.login_rounded,
              loading: _loading,
              color: accent,
              onPressed: _loginBlocked ? null : _submit,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => pos.startPairing(),
              icon: const Icon(Icons.tablet_mac_outlined),
              label: Text(
                binding != null
                    ? l10n.authChangePairedRegister
                    : l10n.authPairDeviceFirst,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                onTap: _loading ? null : () => _changeServer(pos),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        size: 14,
                        color: PosTheme.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          serverUrl,
                          style: TextStyle(
                            fontSize: 12,
                            color: PosTheme.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${l10n.commonChangeServer}',
                        style: TextStyle(
                          fontSize: 12,
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return PosAuthScaffold(
      accent: accent,
      platform: platform,
      serverUrl: serverUrl,
      statusIcon: Icons.point_of_sale_rounded,
      statusLabel:
          binding != null ? l10n.authRegisterPaired : l10n.authStaffPos,
      logoUrl: logoUrl,
      headline: headline,
      locationLine: location.isNotEmpty ? location : null,
      personLabel: binding != null
          ? l10n.authReadyForCashier
          : l10n.authPairThenSignIn,
      personInitial: 'S',
      now: _now,
      fallbackInitials: (restaurantName ?? platformName)
          .substring(0, 1)
          .toUpperCase(),
      footerNote: platform.tagline?.trim().isNotEmpty == true
          ? platform.tagline!.trim()
          : l10n.authStaffOrderingFooter(platformName),
      form: form,
    );
  }
}
