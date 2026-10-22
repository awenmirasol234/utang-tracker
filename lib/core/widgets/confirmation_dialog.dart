import 'package:flutter/material.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';

Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: _confirmationButtonStyle(isDestructive),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

ButtonStyle? _confirmationButtonStyle(bool isDestructive) {
  if (isDestructive) {
    return TextButton.styleFrom(foregroundColor: AppColors.danger);
  }
  return null;
}

Future<bool> confirmDiscardChanges(BuildContext context) {
  return showConfirmationDialog(
    context: context,
    title: 'Discard changes?',
    message: 'Discard unsaved changes?',
    confirmLabel: 'Discard',
    isDestructive: true,
  );
}
