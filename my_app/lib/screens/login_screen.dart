import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/platform_config.dart';
import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../services/firebase_phone_auth.dart';
import '../services/pos_api.dart';
import '../utils/phone_e164.dart';
import '../utils/platform_info.dart';
import '../widgets/pos_ui.dart';

const _orange = Color(0xFFFF6200);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFE6E8EE);
const _page = Color(0xFFF4F5F7);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthPane { signIn, register }

enum _ContactMethod { phone, email }

enum _PhoneStep { number, code }

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _restaurantController = TextEditingController();
  final _cityController = TextEditingController();
  final _cuisineController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _keepSignedIn = true;
  _AuthPane _pane = _AuthPane.signIn;
  _ContactMethod _method = _ContactMethod.email;
  _PhoneStep _phoneStep = _PhoneStep.number;
  String _countryIso = 'IN';
  String? _phoneToken;
  String? _debugOtp;
  bool _firebaseSms = false;
  String? _banner;
  Map<String, String> _fields = const {};
  Timer? _loginCooldownTimer;
  Timer? _resendTimer;
  DateTime? _loginBlockedUntil;
  DateTime? _resendUntil;
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

  int get _resendSeconds {
    final until = _resendUntil;
    if (until == null) return 0;
    final seconds = until.difference(DateTime.now()).inSeconds + 1;
    return seconds < 0 ? 0 : seconds;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  @override
  void dispose() {
    _loginCooldownTimer?.cancel();
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _restaurantController.dispose();
    _cityController.dispose();
    _cuisineController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    if (!mounted) return;
    await context.read<PosController>().loadAuthOptions();
    if (!mounted) return;
    final options = context.read<PosController>().authOptions;
    setState(() {
      _countryIso = options.phoneDefaultCountry;
      if (!options.registrationEnabled) {
        _pane = _AuthPane.signIn;
      }
      if (!options.emailSignUp && _pane == _AuthPane.register) {
        _method = _ContactMethod.phone;
      }
      if (options.loginMethod == AuthLoginMethod.email) {
        _method = _ContactMethod.email;
      } else if (options.loginMethod == AuthLoginMethod.phone &&
          _pane == _AuthPane.signIn) {
        _method = _ContactMethod.phone;
      }
    });
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

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendUntil = DateTime.now().add(const Duration(seconds: 45)));
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 0) {
        timer.cancel();
        setState(() => _resendUntil = null);
        return;
      }
      setState(() {});
    });
  }

  void _applyFailure(PosController pos) {
    final rateLimited =
        pos.lastLoginStatusCode == 429 ||
        (pos.errorMessage ?? '').toLowerCase().contains('too many');
    if (rateLimited) {
      _startLoginCooldown(pos.lastLoginRetryAfter ?? const Duration(seconds: 61));
    } else if (_pane == _AuthPane.signIn && _method == _ContactMethod.email) {
      _failedLogins += 1;
      if (_failedLogins >= 5) {
        _failedLogins = 0;
        _startLoginCooldown(const Duration(seconds: 30));
      }
    }
    final tokenError = pos.authFieldErrors['phone_token'];
    final phoneError = pos.authFieldErrors['phone'];
    final fields = Map<String, String>.from(pos.authFieldErrors)
      ..remove('phone');
    setState(() {
      _fields = fields;
      // Phone messages are long. Keep them in the full-width note so a
      // narrow country-code row cannot clip them.
      _banner = phoneError ?? (fields.isEmpty ? pos.errorMessage : null);
      if (tokenError != null) {
        _phoneToken = null;
        _phoneStep = _PhoneStep.code;
        _banner = tokenError;
      }
    });
  }

  void _useEmailInstead() {
    setState(() {
      _method = _ContactMethod.email;
      _phoneStep = _PhoneStep.number;
      _fields = const {};
      _banner = null;
    });
  }

  String? _currentPhone() {
    final e164 = toE164(_countryIso, _phoneController.text);
    if (e164 == null) {
      setState(() => _fields = {'phone': 'Enter a valid mobile number.'});
      return null;
    }
    return e164;
  }

  Future<void> _submitEmail() async {
    if (_loginBlocked) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final local = <String, String>{};
    if (email.isEmpty || !email.contains('@')) {
      local['email'] = 'Enter a valid email address.';
    }
    if (password.isEmpty) local['password'] = 'Enter your password.';
    if (local.isNotEmpty) {
      setState(() => _fields = local);
      return;
    }
    setState(() {
      _loading = true;
      _fields = const {};
      _banner = null;
    });
    final pos = context.read<PosController>();
    try {
      await pos.login(email, password, keepSignedIn: _keepSignedIn);
      if (!mounted) return;
      if (pos.errorMessage != null) {
        _applyFailure(pos);
      } else {
        _failedLogins = 0;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode({required String purpose}) async {
    final phone = _currentPhone();
    if (phone == null) return;
    setState(() {
      _loading = true;
      _fields = const {};
      _banner = null;
      _debugOtp = null;
    });
    final pos = context.read<PosController>();
    try {
      final sent = await pos.sendPhoneCode(
        phone: phone,
        purpose: purpose,
        supportsFirebase: posCanUseFirebasePhoneAuth,
      );
      if (sent.usesFirebase) {
        final config = sent.firebaseConfig;
        if (config == null) {
          throw PosApiException(
            'Phone verification is not configured for this app.',
          );
        }
        await posFirebasePhoneAuth.sendCode(
          config: config,
          phone: phone,
          resend: _firebaseSms,
        );
      }
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _phoneStep = _PhoneStep.code;
        _debugOtp = sent.debugOtp;
        _firebaseSms = sent.usesFirebase;
      });
      _startResendCooldown();
    } on PosApiException catch (e) {
      if (!mounted) return;
      _captureApi(pos, e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _banner = 'Could not send the code. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _captureApi(PosController pos, PosApiException e) {
    pos.authFieldErrors = e.fieldErrors;
    pos.errorMessage = e.message;
    pos.lastLoginStatusCode = e.statusCode;
    pos.lastLoginRetryAfter = e.retryAfter;
    _applyFailure(pos);
  }

  Future<void> _verifySignInCode() async {
    final phone = _currentPhone();
    if (phone == null) return;
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _fields = {'code': 'Enter the 6-digit code.'});
      return;
    }
    setState(() {
      _loading = true;
      _fields = const {};
      _banner = null;
    });
    final pos = context.read<PosController>();
    try {
      final idToken = _firebaseSms
          ? await posFirebasePhoneAuth.idTokenForCode(code)
          : null;
      await pos.signInWithPhone(
        phone: phone,
        code: idToken == null ? code : null,
        idToken: idToken,
        keepSignedIn: _keepSignedIn,
      );
      if (!mounted) return;
      if (pos.errorMessage != null) _applyFailure(pos);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyRegisterCode() async {
    final phone = _currentPhone();
    if (phone == null) return;
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _fields = {'code': 'Enter the 6-digit code.'});
      return;
    }
    setState(() {
      _loading = true;
      _fields = const {};
      _banner = null;
    });
    final pos = context.read<PosController>();
    try {
      final idToken = _firebaseSms
          ? await posFirebasePhoneAuth.idTokenForCode(code)
          : null;
      final token = await pos.verifyPhoneForRegister(
        phone: phone,
        code: idToken == null ? code : null,
        idToken: idToken,
      );
      if (!mounted) return;
      setState(() => _phoneToken = token);
    } on PosApiException catch (e) {
      if (!mounted) return;
      _captureApi(pos, e);
    } catch (_) {
      if (!mounted) return;
      setState(() => _banner = 'Could not verify the code. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitRegister() async {
    final options = context.read<PosController>().authOptions;
    final local = <String, String>{};
    final name = _nameController.text.trim();
    final restaurant = _restaurantController.text.trim();
    if (name.isEmpty) local['name'] = 'Enter your name.';
    if (restaurant.isEmpty) {
      local['restaurant_name'] = 'Enter the restaurant name.';
    }
    String? email;
    String? password;
    if (_method == _ContactMethod.email || !options.phoneSignUp) {
      email = _emailController.text.trim().toLowerCase();
      password = _passwordController.text;
      if (email.isEmpty || !email.contains('@')) {
        local['email'] = 'Enter a valid email address.';
      }
      if (password.length < 8) {
        local['password'] = 'Use at least 8 characters.';
      }
    } else if (_phoneToken == null) {
      local['phone'] = 'Verify your mobile number first.';
    }
    if (local.isNotEmpty) {
      setState(() => _fields = local);
      return;
    }
    setState(() {
      _loading = true;
      _fields = const {};
      _banner = null;
    });
    final pos = context.read<PosController>();
    try {
      await pos.registerRestaurant(
        name: name,
        restaurantName: restaurant,
        email: email,
        password: password,
        phoneToken: _method == _ContactMethod.phone ? _phoneToken : null,
        restaurantCity: _cityController.text.trim(),
        restaurantCuisine: _cuisineController.text.trim(),
        keepSignedIn: _keepSignedIn,
      );
      if (!mounted) return;
      if (pos.errorMessage != null) _applyFailure(pos);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openRegister() {
    final options = context.read<PosController>().authOptions;
    if (!options.registrationEnabled) return;
    setState(() {
      _pane = _AuthPane.register;
      _phoneStep = _PhoneStep.number;
      _phoneToken = null;
      _firebaseSms = false;
      _fields = const {};
      _banner = null;
      _method = options.emailSignUp && options.loginMethod != AuthLoginMethod.phone
          ? _ContactMethod.email
          : _ContactMethod.phone;
    });
  }

  void _openSignIn({_ContactMethod? method}) {
    setState(() {
      _pane = _AuthPane.signIn;
      _phoneStep = _PhoneStep.number;
      _fields = const {};
      _banner = null;
      if (method != null) _method = method;
    });
  }

  Future<void> _forgotPassword(PosController pos) async {
    final base = PlatformConfig.normalizeServerUrl(
      pos.serverUrl ?? PlatformConfig.platformUrl,
    );
    final uri = Uri.parse('$base/forgot-password');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showPosSnackBar(context, 'Could not open password reset.', error: true);
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
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: context.l10n.setupServerUrl,
                    hintText: 'https://app.selfx.in',
                    errorText: localError,
                  ),
                  onSubmitted: (val) {
                    final normalized = PlatformConfig.normalizeServerUrl(val);
                    if (normalized.isEmpty) {
                      setDialogState(
                        () => localError = 'Please enter a valid server URL.',
                      );
                    } else {
                      Navigator.of(dialogContext).pop(normalized);
                    }
                  },
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
                    final normalized = PlatformConfig.normalizeServerUrl(
                      controller.text,
                    );
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
    await _loadOptions();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final options = pos.authOptions;
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final showCreate = options.registrationEnabled;
    final phoneTaken = (_fields['phone'] ?? _banner ?? '')
        .toLowerCase()
        .contains('already registered');

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopIconButton(
          icon: Icons.home_outlined,
          tooltip: 'Sign in',
          onPressed: _loading ? null : () => _openSignIn(),
        ),
        const SizedBox(width: 8),
        _TopIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: _loading ? null : _loadOptions,
        ),
      ],
    );

    if (!wide) {
      return Scaffold(
        backgroundColor: _page,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: _formCard(
            pos,
            options,
            phoneTaken,
            compact: true,
            toolbar: actions,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 56, 28, 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _BrandPanel(
                      showTrial: showCreate,
                      onTrial: _loading ? null : _openRegister,
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: _formCard(
                        pos,
                        options,
                        phoneTaken,
                        compact: compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(top: 12, right: 16, child: actions),
          ],
        ),
      ),
    );
  }

  Widget _formCard(
    PosController pos,
    AuthOptions options,
    bool phoneTaken, {
    required bool compact,
    Widget? toolbar,
  }) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 0,
        compact ? 8 : 0,
        compact ? 12 : 0,
        (compact ? 20 : 0) + bottomInset,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          children: [
            if (toolbar != null) ...[
              Align(alignment: Alignment.centerRight, child: toolbar),
              const SizedBox(height: 8),
            ],
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 28,
                compact ? 18 : 28,
                compact ? 16 : 28,
                compact ? 14 : 22,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(compact ? 22 : 28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 36,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: _pane == _AuthPane.signIn
                  ? _signInBody(pos, options, phoneTaken, compact: compact)
                  : _registerBody(pos, options, phoneTaken, compact: compact),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loading ? null : () => pos.startPairing(),
              icon: const Icon(Icons.tablet_mac_outlined, size: 18),
              label: Text(
                pos.deviceBinding != null
                    ? 'Change paired register'
                    : 'Pair this device with a code',
                textAlign: TextAlign.center,
              ),
            ),
            InkWell(
              onTap: _loading ? null : () => _changeServer(pos),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text(
                  '${pos.serverUrl ?? PlatformConfig.platformUrl} · Change server',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, height: 1.3, color: _muted),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Version ${PosAppInfo.versionLabel}',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signInBody(
    PosController pos,
    AuthOptions options,
    bool phoneTaken, {
    required bool compact,
  }) {
    final showPhone = options.phoneSignIn;
    final showToggle = showPhone && options.loginMethod != AuthLoginMethod.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WelcomeHeader(
          title: 'Welcome back',
          subtitle: 'Sign in to your restaurant dashboard.',
          compact: compact,
        ),
        if (pos.deviceBinding != null) ...[
          const SizedBox(height: 12),
          Text(
            'Paired to ${[
              pos.deviceBinding!.terminalName ?? pos.deviceBinding!.terminalCode,
              pos.deviceBinding!.branchName,
            ].whereType<String>().where((v) => v.isNotEmpty).join(' · ')}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _orange,
            ),
          ),
        ],
        if (showToggle) ...[
          SizedBox(height: compact ? 14 : 18),
          _MethodToggle(
            method: _method,
            onChanged: _loading
                ? null
                : (method) => setState(() {
                    _method = method;
                    _phoneStep = _PhoneStep.number;
                    _firebaseSms = false;
                    _fields = const {};
                    _banner = null;
                  }),
          ),
        ],
        SizedBox(height: compact ? 14 : 18),
        if (_method == _ContactMethod.email || !showPhone)
          ..._emailSignInFields(pos)
        else
          ..._phoneFields(purpose: 'sign_in'),
        ..._bannerNotes(options),
        if (phoneTaken)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openSignIn(method: _ContactMethod.phone),
              child: const Text('Sign in as owner'),
            ),
          ),
        const SizedBox(height: 8),
        _CheckRow(
          value: _keepSignedIn,
          label: 'Keep me signed in on this device',
          onChanged: _loading
              ? null
              : (value) => setState(() => _keepSignedIn = value),
        ),
        const SizedBox(height: 16),
        _OrangeButton(
          label: _loginBlocked
              ? 'Try again in $_loginCooldownSeconds s'
              : _method == _ContactMethod.phone &&
                    showPhone &&
                    _phoneStep == _PhoneStep.number
              ? 'Send code'
              : 'Sign in',
          loading: _loading,
          onPressed: _loading || _loginBlocked
              ? null
              : () {
                  if (_method == _ContactMethod.phone && showPhone) {
                    if (_phoneStep == _PhoneStep.number) {
                      _sendCode(purpose: 'sign_in');
                    } else {
                      _verifySignInCode();
                    }
                  } else {
                    _submitEmail();
                  }
                },
        ),
        if (options.registrationEnabled) ...[
          SizedBox(height: compact ? 12 : 16),
          _CreateRestaurantCard(
            compact: compact,
            onPressed: _loading ? null : _openRegister,
          ),
        ],
        SizedBox(height: compact ? 10 : 16),
        const _SecureNote(),
      ],
    );
  }

  List<Widget> _emailSignInFields(PosController pos) {
    return [
      _FieldLabel('Email address'),
      _AuthField(
        controller: _emailController,
        hint: 'Enter your email address',
        icon: Icons.alternate_email_rounded,
        keyboard: TextInputType.emailAddress,
        error: _fields['email'],
        onSubmit: (_) => _submitEmail(),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          const Expanded(child: _FieldLabel('Password')),
          TextButton(
            onPressed: _loading ? null : () => _forgotPassword(pos),
            style: TextButton.styleFrom(
              foregroundColor: _orange,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Forgot password?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
      _AuthField(
        controller: _passwordController,
        hint: 'Enter your password',
        icon: Icons.lock_outline_rounded,
        obscure: _obscure,
        error: _fields['password'],
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onSubmit: (_) => _submitEmail(),
      ),
    ];
  }

  List<Widget> _phoneFields({required String purpose}) {
    if (_phoneStep == _PhoneStep.code) {
      return [
        _FieldLabel('Mobile number'),
        Text(
          toE164(_countryIso, _phoneController.text) ?? _phoneController.text,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('6-digit code'),
        _AuthField(
          controller: _codeController,
          hint: 'Enter the code',
          icon: Icons.sms_outlined,
          keyboard: TextInputType.number,
          error: _fields['code'],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmit: (_) {
            if (purpose == 'sign_in') {
              _verifySignInCode();
            } else {
              _verifyRegisterCode();
            }
          },
        ),
        if (kDebugMode && _debugOtp != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Test code: $_debugOtp',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _phoneStep = _PhoneStep.number;
                      _fields = const {};
                    }),
              child: const Text('Change number'),
            ),
            const Spacer(),
            TextButton(
              onPressed: _loading || _resendSeconds > 0
                  ? null
                  : () => _sendCode(purpose: purpose),
              child: Text(
                _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend code',
              ),
            ),
          ],
        ),
      ];
    }
    final localPhoneError = _fields['phone'];
    return [
      const _FieldLabel('Mobile number'),
      _PhoneEntry(
        countryIso: _countryIso,
        controller: _phoneController,
        enabled: !_loading,
        onCountry: (value) => setState(() => _countryIso = value),
      ),
      if (localPhoneError != null) ...[
        const SizedBox(height: 8),
        _ErrorNote(localPhoneError),
      ],
    ];
  }

  List<Widget> _bannerNotes(AuthOptions options) {
    final banner = _banner;
    if (banner == null) return const [];
    final offerEmail =
        options.emailSignIn && banner.toLowerCase().contains('email');
    return [
      const SizedBox(height: 12),
      _ErrorNote(banner),
      if (offerEmail)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _loading ? null : _useEmailInstead,
            child: const Text('Use email instead'),
          ),
        ),
    ];
  }

  Widget _registerBody(
    PosController pos,
    AuthOptions options,
    bool phoneTaken, {
    required bool compact,
  }) {
    final showToggle = options.phoneSignUp && options.emailSignUp;
    final phoneMode = _method == _ContactMethod.phone && options.phoneSignUp;
    final verified = _phoneToken != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Create your restaurant',
                style: TextStyle(
                  fontSize: compact ? 22 : 24,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _ink,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Back to sign in',
              visualDensity: VisualDensity.compact,
              onPressed: _loading ? null : () => _openSignIn(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Free trial. No card needed. Set up in a few minutes.',
          style: TextStyle(fontSize: 13.5, height: 1.35, color: _muted),
        ),
        if (showToggle) ...[
          const SizedBox(height: 8),
          _MethodToggle(
            method: _method,
            phoneLabel: 'Mobile number',
            emailLabel: 'Email address',
            onChanged: _loading
                ? null
                : (method) => setState(() {
                    _method = method;
                    _phoneStep = _PhoneStep.number;
                    _phoneToken = null;
                    _firebaseSms = false;
                    _fields = const {};
                    _banner = null;
                  }),
          ),
        ],
        const SizedBox(height: 16),
        if (phoneMode && !verified) ..._phoneFields(purpose: 'register'),
        if (!phoneMode || verified) ...[
          if (phoneMode) ...[
            Text(
              'Verified ${toE164(_countryIso, _phoneController.text) ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 12),
          ],
          const _FieldLabel('Your name'),
          _AuthField(
            controller: _nameController,
            hint: 'Ravi Kumar',
            icon: Icons.person_outline_rounded,
            error: _fields['name'],
          ),
          const SizedBox(height: 12),
          const _FieldLabel('Restaurant name'),
          _AuthField(
            controller: _restaurantController,
            hint: 'Spice Garden',
            icon: Icons.storefront_outlined,
            error: _fields['restaurant_name'],
          ),
          const SizedBox(height: 12),
          const _FieldLabel('City (optional)'),
          _AuthField(
            controller: _cityController,
            hint: 'Pune',
            icon: Icons.location_city_outlined,
            error: _fields['restaurant_city'],
          ),
          const SizedBox(height: 12),
          const _FieldLabel('Cuisine (optional)'),
          _AuthField(
            controller: _cuisineController,
            hint: 'Indian',
            icon: Icons.restaurant_outlined,
            error: _fields['restaurant_cuisine'],
          ),
          if (!phoneMode) ...[
            const SizedBox(height: 12),
            const _FieldLabel('Email address'),
            _AuthField(
              controller: _emailController,
              hint: 'Enter your email address',
              icon: Icons.alternate_email_rounded,
              keyboard: TextInputType.emailAddress,
              error: _fields['email'],
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Password'),
            _AuthField(
              controller: _passwordController,
              hint: 'Create a password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              error: _fields['password'],
              onToggleObscure: () => setState(() => _obscure = !_obscure),
            ),
          ],
        ],
        ..._bannerNotes(options),
        if (phoneTaken)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openSignIn(method: _ContactMethod.phone),
              child: const Text('Sign in as owner'),
            ),
          ),
        const SizedBox(height: 16),
        _OrangeButton(
          label: phoneMode && !verified
              ? (_phoneStep == _PhoneStep.number ? 'Send code' : 'Verify code')
              : 'Create my restaurant',
          loading: _loading,
          onPressed: _loading
              ? null
              : () {
                  if (phoneMode && !verified) {
                    if (_phoneStep == _PhoneStep.number) {
                      _sendCode(purpose: 'register');
                    } else {
                      _verifyRegisterCode();
                    }
                  } else {
                    _submitRegister();
                  }
                },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading ? null : () => _openSignIn(),
          child: const Text('Already have an account? Sign in'),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.showTrial, required this.onTrial});

  final bool showTrial;
  final VoidCallback? onTrial;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Image.asset(
            'assets/images/selfx_wordmark.png',
            height: 42,
            alignment: Alignment.centerLeft,
            errorBuilder: (_, _, _) => const Text(
              'SELFX',
              style: TextStyle(
                color: _orange,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'MAKE YOUR BUSINESS STANDOUT',
            style: TextStyle(
              color: _orange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 48),
          const Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 40,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
                color: _ink,
              ),
              children: [
                TextSpan(text: 'Run your '),
                TextSpan(
                  text: 'restaurant',
                  style: TextStyle(color: _orange),
                ),
                TextSpan(text: '\nfrom one place'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Orders, kitchen and menu in one simple dashboard.',
            style: TextStyle(fontSize: 16, height: 1.4, color: _muted),
          ),
          const SizedBox(height: 28),
          const _Feature(icon: Icons.point_of_sale_outlined, label: 'POS, kiosk and online orders'),
          const SizedBox(height: 14),
          const _Feature(icon: Icons.soup_kitchen_outlined, label: 'Live kitchen display'),
          const SizedBox(height: 14),
          const _Feature(icon: Icons.auto_awesome_outlined, label: 'AI menu from a photo'),
          const SizedBox(height: 36),
          if (showTrial)
            TextButton(
              onPressed: onTrial,
              style: TextButton.styleFrom(
                foregroundColor: _ink,
                padding: EdgeInsets.zero,
              ),
              child: const Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 14, color: _muted),
                  children: [
                    TextSpan(text: 'New here? '),
                    TextSpan(
                      text: 'Start free trial  →',
                      style: TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF1E8),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: _orange),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

class _PhoneEntry extends StatelessWidget {
  const _PhoneEntry({
    required this.countryIso,
    required this.controller,
    required this.enabled,
    required this.onCountry,
  });

  final String countryIso;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onCountry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: phoneCountryByIso(countryIso).iso,
                isExpanded: true,
                padding: const EdgeInsets.only(left: 12, right: 4),
                borderRadius: BorderRadius.circular(12),
                selectedItemBuilder: (context) => [
                  for (final country in kPhoneCountries)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        country.dial,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                ],
                items: [
                  for (final country in kPhoneCountries)
                    DropdownMenuItem(
                      value: country.iso,
                      child: Text('${country.name}  ${country.dial}'),
                    ),
                ],
                onChanged: enabled
                    ? (value) {
                        if (value != null) onCountry(value);
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(
            height: 22,
            child: VerticalDivider(width: 1, thickness: 1, color: _line),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
              ],
              decoration: const InputDecoration(
                hintText: '98765 43210',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13.5, color: _muted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MethodToggle extends StatelessWidget {
  const _MethodToggle({
    required this.method,
    required this.onChanged,
    this.phoneLabel = 'Mobile number',
    this.emailLabel = 'Email address',
  });

  final _ContactMethod method;
  final ValueChanged<_ContactMethod>? onChanged;
  final String phoneLabel;
  final String emailLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tab(_ContactMethod.phone, Icons.smartphone_outlined, phoneLabel),
          _tab(_ContactMethod.email, Icons.alternate_email_rounded, emailLabel),
        ],
      ),
    );
  }

  Widget _tab(_ContactMethod value, IconData icon, String label) {
    final selected = method == value;
    return Expanded(
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        elevation: selected ? 0.5 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onChanged == null ? null : () => onChanged!(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? _orange : _muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? _orange : _muted,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({IconData? icon, String? hint, String? error}) {
  return InputDecoration(
    hintText: hint,
    errorText: error,
    prefixIcon: icon == null ? null : Icon(icon, size: 18, color: _muted),
    filled: true,
    fillColor: const Color(0xFFFAFBFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
    errorMaxLines: 4,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _orange, width: 1.4),
    ),
  );
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.obscure = false,
    this.error,
    this.onToggleObscure,
    this.onSubmit,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure;
  final String? error;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onSubmit;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmit,
      decoration: _inputDecoration(icon: icon, hint: hint, error: error).copyWith(
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: _muted,
                ),
              ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
              activeColor: _orange,
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13.5, color: _muted)),
          ),
        ],
      ),
    );
  }
}

class _OrangeButton extends StatelessWidget {
  const _OrangeButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _orange,
          disabledBackgroundColor: const Color(0xFFFFC7A3),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text('$label  →'),
      ),
    );
  }
}

class _CreateRestaurantCard extends StatelessWidget {
  const _CreateRestaurantCard({required this.onPressed, this.compact = false});

  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE1CC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New restaurant?',
              style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 2),
            const Text(
              'Free trial · No card · Ready in 5 minutes',
              style: TextStyle(fontSize: 12.5, height: 1.3, color: _muted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onPressed,
                child: const Text(
                  'Create my restaurant  →',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE1CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.store_mall_directory_outlined, size: 18, color: _orange),
              SizedBox(width: 8),
              Text(
                'New restaurant?',
                style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _Tick('Free trial'),
          const _Tick('No card needed'),
          const _Tick('Set up in 5 minutes'),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onPressed,
              child: const Text(
                'Create my restaurant  →',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 14, color: _muted),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Secure, encrypted connection',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: _muted),
          ),
        ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFF6B7280)),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
