import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/features/export/presentation/providers/export_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          0,
          AppSpacing.pagePadding,
          AppSpacing.xxl,
        ),
        children: [
          _MenuItem(
            icon: Icons.file_download_outlined,
            title: 'Export data',
            subtitle: 'Save customers, debts and payments as CSV',
            onTap: () => _export(context, ref),
          ),
          _MenuItem(
            icon: Icons.file_upload_outlined,
            title: 'Import data',
            subtitle: 'Restore customers, debts and payments from CSV',
            onTap: () => context.push('/import'),
          ),
          _MenuItem(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'App version and updates',
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(exportDataUseCaseProvider)();
      if (!context.mounted) {
        return;
      }
      AppSnackBar.success(context, 'Data exported');
    } on AppException catch (appException) {
      if (!context.mounted) {
        return;
      }
      AppSnackBar.error(context, appException.message);
    } catch (caughtError) {
      if (!context.mounted) {
        return;
      }
      AppSnackBar.error(context, caughtError.toString());
    }
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryDark, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
