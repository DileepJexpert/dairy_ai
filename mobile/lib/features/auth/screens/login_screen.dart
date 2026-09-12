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

/// The backend uses phone/OTP authentication for every role. New phone
/// numbers are registered by the same verified OTP flow.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.initialTab = 0,
    this.nextPath,
    this.heading = 'Sign in or create an account',
    this.description =
        'Use your registered mobile number. We will send a secure one-time password.',
  });

  // Retained for route compatibility with /register. OTP is both sign-in and
  // first-time registration, so there is intentionally no separate tab.
  final int initialTab;
  final String? nextPath;
  final String heading;
  final String description;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authProvider.notifier).sendOtp(_phoneController.text.trim());
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
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: AppConstants.phoneLength,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              autovalidateMode: _submitted
                                  ? AutovalidateMode.onUserInteraction
                                  : AutovalidateMode.disabled,
                              decoration: const InputDecoration(
                                labelText: 'Mobile number',
                                hintText: '9876543210',
                                prefixText: '+91 ',
                                counterText: '',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your mobile number';
                                }
                                if (!value.trim().isValidIndianPhone) {
                                  return 'Enter a valid 10-digit mobile number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: loading ? null : _sendOtp,
                              child: Text(
                                loading ? 'Sending OTP…' : 'Continue with OTP',
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Your role and access are verified by the server after OTP confirmation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: storeMuted),
                            ),
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
