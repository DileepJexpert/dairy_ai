import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dairy_ai/features/auth/models/user_model.dart';

part 'auth_state.freezed.dart';

/// Represents the current authentication state of the app.
@freezed
class AuthState with _$AuthState {
  /// User is not logged in.
  const factory AuthState.unauthenticated() = _Unauthenticated;

  /// Authentication action in progress (OTP send, verify, refresh).
  const factory AuthState.loading() = _Loading;

  /// OTP has been sent; waiting for the user to enter it.
  const factory AuthState.otpSent({required String phone}) = _OtpSent;

  /// User is fully authenticated.
  const factory AuthState.authenticated({required UserModel user}) =
      _Authenticated;

  /// An error occurred during an auth operation.
  const factory AuthState.error({required String message}) = _Error;
}
