import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/auth/models/auth_state.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/shared/widgets/loading_overlay.dart';
import 'package:dairy_ai/shared/widgets/error_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

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

  Future<void> _onSendOtp() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    await ref.read(authProvider.notifier).sendOtp(phone);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // React to state changes.
    ref.listen<AuthState>(authProvider, (prev, next) {
      next.maybeWhen(
        otpSent: (phone) => context.go('/otp-verify?phone=$phone'),
        error: (message) => showErrorDialog(context, message: message),
        orElse: () {},
      );
    });

    final isLoading = authState is AsyncLoading ||
        authState == const AuthState.loading();

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading,
        message: 'Sending OTP...',
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 64),

                // --- Logo / Branding ---
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: DairyTheme.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 56,
                    color: DairyTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName,
                  style: context.textTheme.headlineLarge?.copyWith(
                    color: DairyTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConstants.appTagline,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: DairyTheme.subtleGrey,
                  ),
                ),

                const SizedBox(height: 48),

                // --- Phone Number ---
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Login with your phone',
                    style: context.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'We will send you a one-time password',
                    style: context.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: AppConstants.phoneLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autovalidateMode: _submitted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '9876543210',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 16, top: 14, bottom: 14),
                        child: Text(
                          '+91  ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (!value.trim().isValidIndianPhone) {
                        return 'Enter a valid 10-digit mobile number';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: isLoading ? null : _onSendOtp,
                  child: const Text('Send OTP'),
                ),

                const SizedBox(height: 24),

                Text(
                  'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
