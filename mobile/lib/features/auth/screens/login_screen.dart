import '../../../app/shopping_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/extensions.dart';
import '../../../shared/widgets/error_dialog.dart';
import '../../marketplace/widgets/store_design.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

const _demoUiEnabled =
    bool.fromEnvironment('ENABLE_DEMO_UI', defaultValue: false);

/// Customers use password login; staff OTP login requires real SMS in production.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.initialTab = 0,
    this.nextPath,
    this.heading = 'Sign in or create an account',
    this.description =
        'Use your mobile number and password. No SMS or paid OTP is required.',
    this.initialPhone,
    this.initialPassword,
    this.showAdminQuickChip = false,
  });

  // `/register` starts in customer account-creation mode.
  final int initialTab;
  final String? nextPath;
  final String heading;
  final String description;
  final String? initialPhone;
  final String? initialPassword;
  final bool showAdminQuickChip;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _submitted = false;
  bool _showPassword = false;
  late bool _createAccount;

  bool get _isStaffRoute {
    final heading = widget.heading.toLowerCase();
    final next = (widget.nextPath ?? '').toLowerCase();
    return heading.contains('admin') ||
        heading.contains('seller') ||
        heading.contains('vendor') ||
        next.contains('admin') ||
        next.contains('seller') ||
        next.contains('vendor');
  }

  bool get _usesOtp => _isStaffRoute && !AppConstants.separateCustomerAuth;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    if (widget.initialPassword != null) {
      _passwordController.text = widget.initialPassword!;
    }
    _createAccount = widget.initialTab == 1;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = _phoneController.text.trim();
    if (_usesOtp) {
      await ref.read(authProvider.notifier).sendOtp(phone);
    } else if (_createAccount) {
      await ref.read(authProvider.notifier).registerWithPassword(
            phone,
            _passwordController.text,
            username: _usernameController.text,
            email: _emailController.text,
            displayName: _nameController.text,
          );
    } else {
      await ref
          .read(authProvider.notifier)
          .loginWithPassword(phone, _passwordController.text);
    }
  }

  Future<void> _forgotPassword() async {
    final identifier = _phoneController.text.trim();
    if (identifier.isEmpty) {
      showErrorDialog(context,
          message: 'Enter your phone, username, or email first.');
      return;
    }
    try {
      final data = await ref
          .read(authProvider.notifier)
          .requestPasswordReset(identifier);
      if (!mounted) return;
      final token = data['reset_token'] as String?;
      if (token != null && token.isNotEmpty) {
        context.go(
            Uri(path: '/reset-password', queryParameters: {'token': token})
                .toString());
        return;
      }
      final emailSent = data['email_sent'] == true;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Password reset requested'),
          content: Text(emailSent
              ? 'A reset link was sent to the email saved on this account.'
              : 'If the account exists, reset instructions will be sent to its saved email.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showErrorDialog(context, message: 'Could not request reset: $error');
      }
    }
  }

  void _quickLogin({
    required String phone,
    required String password,
    required String label,
  }) {
    setState(() {
      _phoneController.text = phone;
      _passwordController.text = password;
      _createAccount = false;
      _submitted = false;
    });
    Clipboard.setData(ClipboardData(text: '$phone | $password'));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚡ Instant login as $label ($phone)...'),
        backgroundColor: storeDarkGreenNav,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _submit();
    });
  }

  Widget _buildDemoChip({
    required String label,
    required String phone,
    required String password,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _quickLogin(
          phone: phone,
          password: password,
          label: label,
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.bolt, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmerHeader(BuildContext context) {
    return Container(
      color: storeDarkGreenNav,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go('/home'),
            child: const Row(
              children: [
                Icon(Icons.grass, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Milterra Farmers',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'DairyAI • Smart Cattle & Veterinary Network',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined, color: Colors.white, size: 18),
            label:
                const Text('Farm Home', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final loading = authState == const AuthState.loading();

    ref.listen<AuthState>(authProvider, (previous, next) {
      next.maybeWhen(
        otpSent: (phone) {
          final routeNext = widget.nextPath ??
              GoRouterState.of(context).uri.queryParameters['next'];
          final query = <String, String>{'phone': phone};
          if (routeNext != null && routeNext.isNotEmpty) {
            query['next'] = routeNext;
          }
          context.go(
            Uri(path: '/otp-verify', queryParameters: query).toString(),
          );
        },
        authenticated: (user) {
          final role = user.role.trim().toLowerCase();
          final isAdmin = role == 'admin' || role == 'super_admin';
          final isSeller = isAdmin || role == 'vendor' || role == 'seller';

          final routeNext = widget.nextPath ??
              GoRouterState.of(context).uri.queryParameters['next'];

          if (routeNext != null && routeNext.isNotEmpty) {
            context.go(shoppingReturnPath(routeNext));
            return;
          }

          if (isAdmin) {
            context.go('/admin/commerce/orders');
            return;
          }
          if (isSeller) {
            context.go('/seller/portal');
            return;
          }
          if (role == 'vet' || role == 'veterinarian') {
            context.go('/vet-dashboard');
            return;
          }
          final isFarmerPortal = kIsWeb &&
              (Uri.base.host.toLowerCase().startsWith('farmers.') ||
                  Uri.base.host.toLowerCase().startsWith('farmer.'));
          if (role == 'farmer' || isFarmerPortal) {
            context.go('/home');
            return;
          }

          if (AppConstants.separateCustomerAuth) {
            context.go('/account');
            return;
          }
          context.go('/shop');
        },
        error: (message) {
          final isAlreadyRegistered =
              message.contains('already uses these details') ||
                  message.contains('Sign in instead');
          if (isAlreadyRegistered) {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.account_circle, color: storeGreen),
                    SizedBox(width: 8),
                    Text('Account Already Exists'),
                  ],
                ),
                content: const Text(
                  'An account is already registered with this mobile number or email.\n\nTap "Sign In Instead" to switch to sign-in.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _createAccount = false;
                        _submitted = false;
                        if (_phoneController.text.trim().isEmpty) {
                          if (_usernameController.text.trim().isNotEmpty) {
                            _phoneController.text =
                                _usernameController.text.trim();
                          } else if (_emailController.text
                              .trim()
                              .isNotEmpty) {
                            _phoneController.text =
                                _emailController.text.trim();
                          }
                        }
                      });
                    },
                    child: const Text('Sign In Instead'),
                  ),
                ],
              ),
            );
          } else {
            showErrorDialog(context, message: message);
          }
        },
        orElse: () {},
      );
    });

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          if (kIsWeb &&
              (Uri.base.host.toLowerCase().startsWith('farmers.') ||
                  Uri.base.host.toLowerCase().startsWith('farmer.')))
            _buildFarmerHeader(context)
          else
            const StoreHeader(currentCategory: 'All', search: SizedBox.shrink()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    color: storeWhite,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(StoreLayout.radius),
                      side: const BorderSide(color: storeBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.lock_outline,
                                color: storeGreen, size: 42),
                            const SizedBox(height: 16),
                            if (kIsWeb &&
                                (Uri.base.host.toLowerCase().startsWith('farmers.') ||
                                    Uri.base.host.toLowerCase().startsWith('farmer.'))) ...[
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: storeGreen.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: storeGreen.withValues(alpha: 0.25)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.grass,
                                          color: storeGreen, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Farmer & Veterinary Portal',
                                        style: TextStyle(
                                          color: storeGreen,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              widget.heading,
                              textAlign: TextAlign.center,
                              style: StoreType.heading,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.description,
                              textAlign: TextAlign.center,
                              style: StoreType.body,
                            ),
                            const SizedBox(height: 16),
                            // 1-Click Quick Demo & Multi-Tenant Test Accounts
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xfff8fafc),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xffcbd5e1), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.bolt,
                                          size: 20, color: storeDarkGreenNav),
                                      SizedBox(width: 6),
                                      Text(
                                        '1-Click Instant Login (Test Accounts)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: storeDarkGreenNav,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tap any farmer or role to log in with 1 click:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: storeMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildDemoChip(
                                        label: '🚜 Ramesh (Farm 1)',
                                        phone: '9876510001',
                                        password: 'Password@123',
                                        color: const Color(0xff047857),
                                        bgColor: const Color(0xffecfdf5),
                                        borderColor: const Color(0xffa7f3d0),
                                      ),
                                      _buildDemoChip(
                                        label: '🐄 Suresh (Farm 2)',
                                        phone: '9876510002',
                                        password: 'Password@123',
                                        color: const Color(0xff1d4ed8),
                                        bgColor: const Color(0xffeff6ff),
                                        borderColor: const Color(0xffbfdbfe),
                                      ),
                                      _buildDemoChip(
                                        label: '🌱 Priya (New Farm)',
                                        phone: '9876510003',
                                        password: 'Password@123',
                                        color: const Color(0xff7c3aed),
                                        bgColor: const Color(0xfff5f3ff),
                                        borderColor: const Color(0xffddd6fe),
                                      ),
                                      _buildDemoChip(
                                        label: '👤 Dileep (9839769808)',
                                        phone: '9839769808',
                                        password: 'Password@123',
                                        color: const Color(0xff0369a1),
                                        bgColor: const Color(0xfff0f9ff),
                                        borderColor: const Color(0xffbae6fd),
                                      ),
                                      _buildDemoChip(
                                        label: '🛡️ Admin',
                                        phone: '9999900000',
                                        password: 'Password@123',
                                        color: const Color(0xffb45309),
                                        bgColor: const Color(0xfffffbeb),
                                        borderColor: const Color(0xfffde68a),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.pin_outlined,
                                          size: 14, color: storeMuted),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Default PIN / Password: ',
                                        style: TextStyle(
                                            fontSize: 11, color: storeMuted),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xfff1f5f9),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: const Color(0xffcbd5e1)),
                                        ),
                                        child: const Text(
                                          'Password@123',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xff0f172a),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (widget.showAdminQuickChip)
                              Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xfffffbeb),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xfffcd34d), width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.admin_panel_settings,
                                            size: 20, color: Color(0xffb45309)),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Quick Admin Login (1-Tap Autofill)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xff92400e),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Tap the chip below to autofill testing admin credentials:',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xff78350f),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildDemoChip(
                                      label: '🛡️ Test Admin (9876543210)',
                                      phone: '9876543210',
                                      password: 'TestAdmin@2026',
                                      color: const Color(0xffb45309),
                                      bgColor: const Color(0xfffef3c7),
                                      borderColor: const Color(0xfff59e0b),
                                    ),
                                  ],
                                ),
                              ),
                            if (!_usesOtp && _createAccount) ...[
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Your name',
                                  hintText: 'Dileep Kumar',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().length < 2) {
                                    return 'Enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _usernameController,
                                textCapitalization: TextCapitalization.none,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  hintText: 'dileep.customer',
                                  prefixIcon:
                                      Icon(Icons.alternate_email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final username = value?.trim() ?? '';
                                  if (!RegExp(r'^[A-Za-z0-9._]{3,30}$')
                                      .hasMatch(username)) {
                                    return 'Use 3–30 letters, numbers, dots, or underscores';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                  labelText: AppConstants.separateCustomerAuth
                                      ? 'Email for sign-in'
                                      : 'Email for password recovery',
                                  hintText: 'you@gmail.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(email)) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: _usesOtp || _createAccount
                                  ? TextInputType.phone
                                  : TextInputType.text,
                              maxLength: _usesOtp || _createAccount
                                  ? AppConstants.phoneLength
                                  : null,
                              inputFormatters: _usesOtp || _createAccount
                                  ? [FilteringTextInputFormatter.digitsOnly]
                                  : null,
                              autovalidateMode: _submitted
                                  ? AutovalidateMode.onUserInteraction
                                  : AutovalidateMode.disabled,
                              decoration: InputDecoration(
                                labelText: _usesOtp || _createAccount
                                    ? 'Mobile number'
                                    : 'Phone, username, or email',
                                hintText: _usesOtp || _createAccount
                                    ? '9876543210'
                                    : '9876543210 or dileep.customer',
                                prefixText:
                                    _usesOtp || _createAccount ? '+91 ' : null,
                                counterText: '',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return _usesOtp || _createAccount
                                      ? 'Please enter your mobile number'
                                      : 'Enter your phone, username, or email';
                                }
                                if ((_usesOtp || _createAccount) &&
                                    !value.trim().isValidIndianPhone) {
                                  return 'Enter a valid 10-digit mobile number';
                                }
                                return null;
                              },
                            ),
                            if (!_usesOtp) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: _createAccount
                                    ? const [AutofillHints.newPassword]
                                    : const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: _createAccount
                                      ? 'Create password'
                                      : 'Password',
                                  helperText: _createAccount
                                      ? 'Use at least 8 characters.'
                                      : null,
                                  border: const OutlineInputBorder(),
                                  suffixIcon:
                                      ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _passwordController,
                                    builder: (context, value, _) => Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (value.text.isNotEmpty)
                                          IconButton(
                                            tooltip: 'Clear password',
                                            onPressed:
                                                _passwordController.clear,
                                            icon: const Icon(Icons.clear),
                                          ),
                                        IconButton(
                                          tooltip: _showPassword
                                              ? 'Hide password'
                                              : 'Show password',
                                          onPressed: () => setState(() =>
                                              _showPassword = !_showPassword),
                                          icon: Icon(_showPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (_usesOtp) return null;
                                  if (value == null || value.length < 8) {
                                    return 'Password must have at least 8 characters';
                                  }
                                  return null;
                                },
                              ),
                              if (!_createAccount &&
                                  !AppConstants.separateCustomerAuth)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: loading ? null : _forgotPassword,
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: loading ? null : _submit,
                              child: Text(
                                loading
                                    ? 'Please wait…'
                                    : _usesOtp
                                        ? 'Continue with OTP'
                                        : _createAccount
                                            ? 'Create account'
                                            : 'Sign in',
                              ),
                            ),
                            if (!_usesOtp) ...[
                              const SizedBox(height: 10),
                              if (!_isStaffRoute)
                                TextButton(
                                  onPressed: loading
                                      ? null
                                      : () => setState(() {
                                            _createAccount = !_createAccount;
                                            _submitted = false;
                                          }),
                                  child: Text(_createAccount
                                      ? 'Already have an account? Sign in'
                                      : 'New to Milterra? Create an account'),
                                ),
                              Text(
                                _isStaffRoute &&
                                        AppConstants.separateCustomerAuth
                                    ? 'Sign in with the password assigned to your staff account.'
                                    : AppConstants.separateCustomerAuth
                                        ? 'Use your phone, username or email to sign in. Phone and email are not verified. Password recovery is not available yet; keep your password safe.'
                                        : 'Your phone identifies the account; email is used only for recovery and launch follow-up. No SMS is sent.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: storeMuted),
                              ),
                            ] else ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Your role and access are verified by the server after OTP confirmation.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(fontSize: 12, color: storeMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
