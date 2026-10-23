import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/widgets/app_button.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';
import 'package:utang_tracker/features/backup/presentation/providers/cloud_backup_providers.dart';

class CloudBackupPage extends ConsumerStatefulWidget {
  const CloudBackupPage({super.key});

  @override
  ConsumerState<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends ConsumerState<CloudBackupPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(cloudBackupNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cloudBackupNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          0,
          AppSpacing.pagePadding,
          AppSpacing.xxl,
        ),
        children: [
          _BackupCard(state: state),
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackupCard extends ConsumerWidget {
  const _BackupCard({required this.state});

  final CloudBackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.status.isSignedIn) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Protect your ledger',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Connect Google Drive to back up and restore your database.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Sign in with Google',
              icon: Icons.account_circle_outlined,
              isLoading: state.operation == BackupOperation.signingIn,
              onPressed: _enabledAction(state.isBusy, () async {
                final success = await ref
                    .read(cloudBackupNotifierProvider.notifier)
                    .signIn();
                if (!success || !context.mounted) return;
                AppSnackBar.success(context, 'Google Drive connected');
              }),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Google Drive connected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.status.email ?? 'Google account',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _LastBackup(status: state.status),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Back up now',
            icon: Icons.cloud_upload_outlined,
            isLoading: state.operation == BackupOperation.backingUp,
            onPressed: _enabledAction(state.isBusy, () async {
              final success = await ref
                  .read(cloudBackupNotifierProvider.notifier)
                  .backup(interactive: true);
              if (!success || !context.mounted) return;
              AppSnackBar.success(context, 'Backup completed');
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Restore latest backup',
            variant: AppButtonVariant.secondary,
            icon: Icons.cloud_download_outlined,
            isLoading: state.operation == BackupOperation.restoring,
            onPressed: _enabledAction(
              state.isBusy,
              () => _confirmRestore(context, ref),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Sign out',
            variant: AppButtonVariant.secondary,
            icon: Icons.logout_rounded,
            isLoading: state.operation == BackupOperation.signingOut,
            onPressed: _enabledAction(state.isBusy, () async {
              final success = await ref
                  .read(cloudBackupNotifierProvider.notifier)
                  .signOut();
              if (!success || !context.mounted) return;
              AppSnackBar.info(context, 'Google Drive disconnected');
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref) async {
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore backup?'),
          content: const Text(
            'This will replace the data currently on this device. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
    if (shouldRestore != true || !context.mounted) return;

    final success = await ref
        .read(cloudBackupNotifierProvider.notifier)
        .restore();
    if (!success || !context.mounted) return;
    AppSnackBar.success(context, 'Backup restored');
  }

  VoidCallback? _enabledAction(bool busy, VoidCallback action) {
    if (busy) return null;
    return action;
  }
}

class _LastBackup extends StatelessWidget {
  const _LastBackup({required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.lastBackupAt == null) {
      return Text(
        'No backup created yet',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      );
    }
    return Text(
      'Last backup: ${context.smartTimestamp(status.lastBackupAt!)}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
