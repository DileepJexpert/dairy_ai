import 'package:flutter/material.dart';
import 'package:dairy_ai/app/theme.dart';

/// Shows a standardised error dialog.
Future<void> showErrorDialog(
  BuildContext context, {
  required String message,
  String title = 'Error',
  String buttonText = 'OK',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: DairyTheme.errorRed),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(buttonText),
        ),
      ],
    ),
  );
}
