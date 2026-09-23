import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/platform_config.dart';
import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/pos_animations.dart';
import '../widgets/pos_ui.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final current = context.read<PosController>().serverUrl;
    _controller = TextEditingController(
      text: current != null && current.isNotEmpty
          ? current
          : PlatformConfig.platformUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = PlatformConfig.normalizeServerUrl(_controller.text.trim());
    if (url.isEmpty) {
      setState(
        () => _localError =
            context.l10n.setupEnterUrl(PosAppInfo.displayName),
      );
      return;
    }

    setState(() {
      _loading = true;
      _localError = null;
    });
    try {
      await context.read<PosController>().saveServerUrl(url);
    } catch (e) {
      if (mounted) setState(() => _localError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final l10n = context.l10n;

    final form = PosSlideFade(
      child: PosSurfaceCard(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Text(
                  l10n.setupStep1,
                  style: TextStyle(
                    color: soft.fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.setupServerTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.setupConnectRegister(PosAppInfo.displayName),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.setupServerUrl,
                hintText: 'https://app.selfx.in',
                prefixIcon: const Icon(Icons.link_rounded),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_localError != null) ...[
              const SizedBox(height: 12),
              Text(
                _localError!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 22),
            PosPrimaryButton(
              label: l10n.commonContinue,
              icon: Icons.arrow_forward_rounded,
              loading: _loading,
              color: accent,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );

    return PosAuthScaffold(
      accent: accent,
      statusIcon: Icons.dns_rounded,
      statusLabel: l10n.setupServerTitle,
      headline: PosAppInfo.displayName,
      fallbackIcon: Icons.dns_rounded,
      footerNote: l10n.setupConnectRegister(PosAppInfo.displayName),
      showClock: false,
      form: form,
    );
  }
}
