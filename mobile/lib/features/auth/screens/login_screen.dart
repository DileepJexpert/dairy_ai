import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/extensions.dart';
import '../../../shared/widgets/error_dialog.dart';
import '../../marketplace/widgets/store_design.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

/// Customers use phone and password so pre-launch demand capture has no SMS
/// cost. Development admin/vendor accounts retain their role-checked OTP flow.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.initialTab = 0,
    this.nextPath,
    this.heading = 'Sign in or create an account',
    this.description =
        'Use your mobile number and password. No SMS or paid OTP is required.',
    this.initialPhone,
  });

  // `/register` starts in customer account-creation mode.
  final int initialTab;
  final String? nextPath;
  final String heading;
  final String description;
  final String? initialPhone;

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

  bool get _usesOtp {
    final heading = widget.heading.toLowerCase();
    final next = (widget.nextPath ?? '').toLowerCase();
    return heading.contains('admin') ||
        heading.contains('seller') ||
        heading.contains('vendor') ||
        next.contains('admin') ||
        next.contains('seller') ||
        next.contains('vendor');
  }

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
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
      final resetUrl = data['reset_url']?.toString();
      final emailSent = data['email_sent'] == true;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Password reset requested'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emailSent
                  ? 'A reset link was sent to the email saved on this account.'
                  : resetUrl != null
                      ? 'Local development mode generated this reset link. No email service is configured.'
                      : 'If the account exists, reset instructions will be sent to its saved email.'),
              if (resetUrl != null) ...[
                const SizedBox(height: 12),
                SelectableText(resetUrl,
                    style: const TextStyle(fontSize: 11, color: storeGreen)),
              ],
            ],
          ),
          actions: [
            if (resetUrl != null)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: resetUrl));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy local reset link'),
              ),
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
        onTap: () {
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
              content: Text('Autofilled $label ($phone / $password)'),
              backgroundColor: color,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
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
              const SizedBox(width: 4),
              Icon(Icons.touch_app_outlined, size: 14, color: color),
            ],
          ),
        ),
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
          final routeNext = widget.nextPath ??
              GoRouterState.of(context).uri.queryParameters['next'];
          if (routeNext != null && routeNext.isNotEmpty) {
            context.go(routeNext);
          } else {
            final role = user.role.toLowerCase();
            if (role == 'admin' || role == 'super_admin') {
              context.go('/admin/ecommerce');
            } else if (role == 'vendor' || role == 'seller') {
              context.go('/vendor-dashboard');
            } else {
              context.go('/shop');
            }
          }
        },
        error: (message) => showErrorDialog(context, message: message),
        orElse: () {},
      );
    });

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
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
                            // Quick 1-Click Demo Credentials for Testing
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xfff8fafc),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xffe2e8f0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.bolt,
                                          size: 18, color: storeDarkGreenNav),
                                      SizedBox(width: 6),
                                      Text(
                                        'Quick Demo Accounts (1-Click Autofill)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: storeDarkGreenNav,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Click any role to autofill phone & password for instant testing:',
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
                                        label: '🛡️ Admin',
                                        phone: '9999900000',
                                        password: 'Password@123',
                                        color: const Color(0xff047857),
                                        bgColor: const Color(0xffecfdf5),
                                        borderColor: const Color(0xffa7f3d0),
                                      ),
                                      _buildDemoChip(
                                        label: '👤 Customer',
                                        phone: '9820112345',
                                        password: 'Password@123',
                                        color: const Color(0xff1d4ed8),
                                        bgColor: const Color(0xffeff6ff),
                                        borderColor: const Color(0xffbfdbfe),
                                      ),
                                      _buildDemoChip(
                                        label: '🏪 Seller',
                                        phone: '9999900090',
                                        password: 'Password@123',
                                        color: const Color(0xffb45309),
                                        bgColor: const Color(0xfffffbeb),
                                        borderColor: const Color(0xfffde68a),
                                      ),
                                      _buildDemoChip(
                                        label: '🚜 Farmer',
                                        phone: '9876500001',
                                        password: 'Password@123',
                                        color: const Color(0xff4338ca),
                                        bgColor: const Color(0xffeef2ff),
                                        borderColor: const Color(0xffc7d2fe),
                                      ),
                                    ],
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
                                decoration: const InputDecoration(
                                  labelText: 'Email for password recovery',
                                  hintText: 'you@gmail.com',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
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
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                        () => _showPassword = !_showPassword),
                                    icon: Icon(_showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
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
                              if (!_createAccount)
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
                              const Text(
                                'Your phone identifies the account; email is used only for recovery and launch follow-up. No SMS is sent.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(fontSize: 12, color: storeMuted),
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
