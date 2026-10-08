import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../services/pos_pin_prompt_storage.dart';
import '../theme/pos_theme.dart';
import '../utils/pos_animations.dart';
import '../widgets/pos_ui.dart';

/// Set or change the staff POS PIN (requires account password).
class SetPosPinScreen extends StatefulWidget {
  const SetPosPinScreen({super.key});

  static Future<bool?> open(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SetPosPinScreen()),
    );
  }

  @override
  State<SetPosPinScreen> createState() => _SetPosPinScreenState();
}

class _SetPosPinScreenState extends State<SetPosPinScreen> {
  static const _pinLen = 6;

  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(() => setState(() => _inlineError = null));
    _confirmController.addListener(() => setState(() => _inlineError = null));
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _passwordController.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    final password = _passwordController.text;

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _inlineError = l10n.pinMustBeSix);
      _pinFocus.requestFocus();
      return;
    }
    if (pin != confirm) {
      setState(() {
        _inlineError = l10n.pinMismatch;
        _confirmController.clear();
      });
      _confirmFocus.requestFocus();
      return;
    }
    if (password.isEmpty) {
      setState(() => _inlineError = l10n.pinNeedPassword);
      _passwordFocus.requestFocus();
      return;
    }

    setState(() {
      _loading = true;
      _inlineError = null;
    });
    try {
      final ok = await context.read<PosController>().savePosPin(
            pin: pin,
            currentPassword: password,
          );
      if (!mounted) return;
      if (ok) {
        showPosSnackBar(context, context.l10n.pinSaved);
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _inlineError =
              context.read<PosController>().errorMessage ?? context.l10n.pinSaveFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final changing = pos.session?.hasPosPin == true;
    final title = changing ? l10n.pinChangeTitle : l10n.pinSetTitle;

    final form = PosSlideFade(
      child: SizedBox(
        width: double.infinity,
        child: PosSurfaceCard(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: soft.bg,
                shape: BoxShape.circle,
                boxShadow: PosTheme.cardShadow(accent),
              ),
              child: Icon(
                changing ? Icons.password_rounded : Icons.pin_rounded,
                color: soft.fg,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Text(
                l10n.pinCreateSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Text(
                l10n.pinNew,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PosTheme.ink,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _OtpPinInput(
              controller: _pinController,
              focusNode: _pinFocus,
              length: _pinLen,
              accent: accent,
              enabled: !_loading,
              autofocus: true,
              onCompleted: (_) => _confirmFocus.requestFocus(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: Text(
                l10n.pinConfirm,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PosTheme.ink,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _OtpPinInput(
              controller: _confirmController,
              focusNode: _confirmFocus,
              length: _pinLen,
              accent: accent,
              enabled: !_loading,
              onCompleted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: TextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscurePassword,
                enabled: !_loading,
                textAlign: TextAlign.center,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: l10n.pinAccountPassword,
                  helperText: l10n.pinPasswordHelper,
                  helperStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Text(
                  _inlineError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: PosPrimaryButton(
                label: changing ? l10n.pinUpdate : l10n.pinSave,
                icon: Icons.check_rounded,
                loading: _loading,
                color: accent,
                onPressed: _submit,
              ),
            ),
          ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: context.l10n.commonClose,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Scroll views pin their child to the start (left). Use a full-width
            // min constraint + Center so the card stays horizontally centered.
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                  minWidth: constraints.maxWidth,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: form,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Six-box OTP-style PIN entry (keyboard only — no dialer).
class _OtpPinInput extends StatefulWidget {
  const _OtpPinInput({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.accent,
    required this.enabled,
    this.autofocus = false,
    this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final Color accent;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;

  @override
  State<_OtpPinInput> createState() => _OtpPinInputState();
}

class _OtpPinInputState extends State<_OtpPinInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    final value = widget.controller.text;
    if (value.length == widget.length) {
      widget.onCompleted?.call(value);
    }
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(widget.accent);
    final text = widget.controller.text;
    final focused = widget.focusNode.hasFocus;

    const gap = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final boxSize = ((available - (widget.length - 1) * gap) /
                widget.length)
            .clamp(34.0, 48.0);
        return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled
            ? () {
                widget.focusNode.requestFocus();
                SystemChannels.textInput.invokeMethod('TextInput.show');
              }
            : null,
        child: SizedBox(
          width: widget.length * boxSize + (widget.length - 1) * gap,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Invisible field captures keyboard / hardware input.
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: widget.length,
                  obscureText: true,
                  enableInteractiveSelection: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.length, (index) {
                  final filled = index < text.length;
                  final isCaret = focused && index == text.length;
                  return Container(
                    width: boxSize,
                    height: 52,
                    margin: EdgeInsets.only(
                      right: index < widget.length - 1 ? gap : 0,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filled || isCaret
                          ? soft.bg
                          : PosTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCaret
                            ? widget.accent
                            : filled
                                ? widget.accent.withValues(alpha: 0.35)
                                : PosTheme.border,
                        width: isCaret ? 2 : 1,
                      ),
                    ),
                    child: filled
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.accent,
                            ),
                          )
                        : isCaret
                            ? Container(
                                width: 2,
                                height: 22,
                                color: widget.accent,
                              )
                            : null,
                  );
                }),
              ),
            ],
          ),
        ),
      );
      },
    );
  }
}

/// Dismissible banner shown when staff has no POS PIN configured.
class PosPinSetupBanner extends StatefulWidget {
  const PosPinSetupBanner({super.key});

  @override
  State<PosPinSetupBanner> createState() => _PosPinSetupBannerState();
}

class _PosPinSetupBannerState extends State<PosPinSetupBanner> {
  bool _visible = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pos = context.read<PosController>();
    if (pos.session?.hasPosPin == true) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    final userId = pos.profile?.user.id;
    if (userId == null || userId <= 0) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    final dismissed = await PosPinPromptStorage.isDismissed(userId);
    if (mounted) {
      setState(() {
        _checking = false;
        _visible = !dismissed;
      });
    }
  }

  Future<void> _dismiss() async {
    final pos = context.read<PosController>();
    final userId = pos.profile?.user.id;
    if (userId != null && userId > 0) {
      await PosPinPromptStorage.dismiss(userId);
    }
    if (mounted) setState(() => _visible = false);
  }

  Future<void> _openSetPin() async {
    final saved = await SetPosPinScreen.open(context);
    if (saved == true && mounted) {
      setState(() => _visible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    if (_checking || !_visible || pos.session?.hasPosPin == true) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: soft.bg,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusMd),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PosTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.pin_rounded, color: soft.fg, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pinBannerTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: soft.fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.pinBannerBody,
                      style: TextStyle(
                        fontSize: 12,
                        color: PosTheme.inkMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _openSetPin,
                          style: TextButton.styleFrom(
                            foregroundColor: soft.fg,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(l10n.pinPromptSetNow),
                        ),
                        TextButton(
                          onPressed: _dismiss,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(l10n.pinPromptNotNow),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: l10n.commonDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
