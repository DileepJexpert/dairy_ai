import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../app/shopping_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/auth/models/auth_state.dart';
import 'package:dairy_ai/features/auth/models/user_model.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/shared/widgets/loading_overlay.dart';
import 'package:dairy_ai/shared/widgets/error_dialog.dart';

const _demoUiEnabled = bool.fromEnvironment('ENABLE_DEMO_UI', defaultValue: false);

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String? nextPath;

  const OtpScreen({super.key, required this.phone, this.nextPath});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  Timer? _resendTimer;
  int _secondsLeft = AppConstants.otpResendSeconds;
  bool _canResend = false;

  bool get _isDemoPhone {
    return kDebugMode && _demoUiEnabled && (widget.phone.startsWith('99999') ||
        widget.phone.startsWith('98765') ||
        widget.phone.startsWith('98201') ||
        widget.phone.startsWith('97654') ||
        widget.phone.startsWith('94481') ||
        widget.phone.startsWith('99351') ||
        widget.phone.startsWith('98290'));
  }

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    if (_isDemoPhone) {
      _otpController.text = '123456';
    }
  }

  void _startResendTimer() {
    _secondsLeft = AppConstants.otpResendSeconds;
    _canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _onVerify() async {
    final otp = _otpController.text.trim();
    if (!otp.isValidOtp) {
      showErrorDialog(context, message: 'Please enter a valid 6-digit OTP');
      return;
    }
    await ref.read(authProvider.notifier).verifyOtp(widget.phone, otp);
  }

  Future<void> _onResend() async {
    if (!_canResend) return;
    await ref.read(authProvider.notifier).sendOtp(widget.phone);
    _startResendTimer();
  }

  Future<void> _completeAuthentication(UserModel user) async {
    final destination = shoppingReturnPath(widget.nextPath);
    final role = user.role.toLowerCase();
    final isAdmin = role == 'admin' || role == 'super_admin';
    final isSeller = isAdmin || role == 'vendor' || role == 'seller';
    final requiresAdmin = destination == '/admin/ecommerce' ||
        destination == '/admin-dashboard' ||
        destination == '/admin-farmers' ||
        destination == '/admin-vets' ||
        destination.startsWith('/admin/commerce');
    final requiresSeller = destination == '/seller/dashboard' ||
        destination == '/vendor-dashboard' ||
        destination == '/vendor-orders' ||
        destination == '/vendor-profile' ||
        destination == '/vendor/products';

    if ((requiresAdmin && !isAdmin) || (requiresSeller && !isSeller)) {
      // A successful OTP proves phone ownership, not that this account has the
      // requested workspace role. Clear the newly-created session rather than
      // silently falling back to the customer storefront.
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      final loginPath = requiresAdmin ? '/admin/login' : '/seller/login';
      showErrorDialog(
        context,
        message: requiresAdmin
            ? 'This mobile number is not assigned to an administrator account.'
            : 'This mobile number is not assigned to an approved seller account.',
      );
      context.go(
        Uri(path: loginPath, queryParameters: {'next': destination}).toString(),
      );
      return;
    }

    if (mounted) context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      next.maybeWhen(
        authenticated: (user) {
          unawaited(_completeAuthentication(user));
        },
        error: (message) => showErrorDialog(context, message: message),
        orElse: () {},
      );
    });

    final isLoading = authState == const AuthState.loading();

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading,
        message: 'Verifying...',
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                const SizedBox(height: 48),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      final next = (widget.nextPath ?? '').toLowerCase();
                      if (next.contains('admin')) {
                        context.go(Uri(
                          path: '/admin/login',
                          queryParameters: widget.nextPath != null
                              ? {'next': widget.nextPath!}
                              : null,
                        ).toString());
                      } else if (next.contains('seller')) {
                        context.go(Uri(
                          path: '/seller/login',
                          queryParameters: widget.nextPath != null
                              ? {'next': widget.nextPath!}
                              : null,
                        ).toString());
                      } else {
                        context.go('/login');
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // --- Header ---
                Icon(
                  Icons.sms_outlined,
                  size: 64,
                  color: DairyTheme.primaryGreen.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify OTP',
                  style: context.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to\n+91 ${widget.phone}',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: DairyTheme.subtleGrey,
                  ),
                ),

                if (_isDemoPhone) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xfffef3c7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xfff59e0b)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.key, size: 16, color: Color(0xffb45309)),
                        const SizedBox(width: 8),
                        const Text(
                          'Dev OTP: 123456 (Pre-filled)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff92400e),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            _otpController.text = '123456';
                            Clipboard.setData(
                                const ClipboardData(text: '123456'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Copied & autofilled OTP: 123456'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(Icons.copy,
                              size: 15, color: Color(0xffb45309)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // --- PIN fields ---
                PinCodeTextField(
                  appContext: context,
                  length: AppConstants.otpLength,
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(10),
                    fieldHeight: 54,
                    fieldWidth: 46,
                    activeColor: DairyTheme.primaryGreen,
                    selectedColor: DairyTheme.accentOrange,
                    inactiveColor: const Color(0xFFE0E0E0),
                    activeFillColor: Colors.white,
                    selectedFillColor: Colors.white,
                    inactiveFillColor: Colors.white,
                  ),
                  enableActiveFill: true,
                  onCompleted: (_) => _onVerify(),
                  onChanged: (_) {},
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: isLoading ? null : _onVerify,
                  child: const Text('Verify'),
                ),

                const SizedBox(height: 24),

                // --- Resend ---
                _canResend
                    ? TextButton(
                        onPressed: _onResend,
                        child: const Text('Resend OTP'),
                      )
                    : Text(
                        'Resend OTP in $_secondsLeft s',
                        style: context.textTheme.bodySmall,
                      ),
              ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
