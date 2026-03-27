import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/auth/models/auth_state.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/shared/widgets/loading_overlay.dart';
import 'package:dairy_ai/shared/widgets/error_dialog.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  Timer? _resendTimer;
  int _secondsLeft = AppConstants.otpResendSeconds;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      next.maybeWhen(
        authenticated: (_) {
          // Router redirect will handle navigation based on role.
          context.go('/home');
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 48),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/login'),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Header ---
                Icon(
                  Icons.sms_outlined,
                  size: 64,
                  color: DairyTheme.primaryGreen.withOpacity(0.7),
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

                const SizedBox(height: 40),

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
    );
  }
}
