import 'package:flutter/material.dart';

/// Convenience extensions on BuildContext for quick access to theme and
/// navigator without verbose boilerplate.
extension BuildContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get viewPadding => MediaQuery.of(this).viewPadding;

  NavigatorState get navigator => Navigator.of(this);

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Extension on String for common validations.
extension StringExtensions on String {
  bool get isValidIndianPhone => RegExp(r'^[6-9]\d{9}$').hasMatch(this);
  bool get isValidOtp => RegExp(r'^\d{6}$').hasMatch(this);
  String get masked => length > 4
      ? '${'*' * (length - 4)}${substring(length - 4)}'
      : this;
}
