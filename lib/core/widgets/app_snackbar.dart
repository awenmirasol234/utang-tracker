import 'package:flutter/material.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';

enum AppSnackBarKind { success, error, info }

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    AppSnackBarKind kind = AppSnackBarKind.info,
  }) {
    final (background, foreground) = switch (kind) {
      AppSnackBarKind.success => (AppColors.success, AppColors.textOnPrimary),
      AppSnackBarKind.error => (AppColors.danger, AppColors.textOnPrimary),
      AppSnackBarKind.info => (AppColors.primaryDark, AppColors.textOnPrimary),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: Theme.of(
              context,
            ).snackBarTheme.contentTextStyle?.copyWith(color: foreground),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static void success(BuildContext context, String message) {
    show(context, message, kind: AppSnackBarKind.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message, kind: AppSnackBarKind.error);
  }

  static void info(BuildContext context, String message) {
    show(context, message, kind: AppSnackBarKind.info);
  }
}
