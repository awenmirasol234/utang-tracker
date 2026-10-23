import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/widgets/app_button.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/core/widgets/confirmation_dialog.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';
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
          _BackupHealth(status: state.status),
          const SizedBox(height: AppSpacing.lg),
          _BackupIntervalPicker(state: state),
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
          const SizedBox(height: AppSpacing.lg),
          _BackupHistory(state: state),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Restore selected backup',
            variant: AppButtonVariant.secondary,
            icon: Icons.cloud_download_outlined,
            isLoading: state.operation == BackupOperation.restoring,
            onPressed: _enabledAction(
              state.isBusy || state.selectedBackup == null,
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
    final selectedBackup = ref.read(cloudBackupNotifierProvider).selectedBackup;
    if (selectedBackup == null) return;
    final shouldRestore = await showConfirmationDialog(
      context: context,
      title: 'Restore backup?',
      message:
          'This will replace the data currently on this device. This action cannot be undone.',
      confirmLabel: 'Restore',
      isDestructive: true,
    );
    if (!shouldRestore || !context.mounted) return;

    final success = await ref
        .read(cloudBackupNotifierProvider.notifier)
        .restore();
    if (!success || !context.mounted) return;
    AppSnackBar.success(context, 'Backup restored');
  }

  VoidCallback? _enabledAction(bool disabled, VoidCallback action) {
    if (disabled) return null;
    return action;
  }
}

class _BackupHealth extends StatelessWidget {
  const _BackupHealth({required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    final latestBackup = _latestBackup(status);
    final lastBackupText = _lastBackupText(context, status.lastBackupAt);
    final sizeText = _formatSize(latestBackup?.sizeBytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Backup health', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Last successful backup: $lastBackupText',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Latest backup size: $sizeText',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Backups stored: ${status.backups.length} of ${BackupStatus.maxBackups}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (status.lastBackupError != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Last backup failed: ${status.lastBackupError}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }

  BackupRecord? _latestBackup(BackupStatus status) {
    if (status.backups.isEmpty) return null;
    return status.backups.first;
  }

  String _lastBackupText(BuildContext context, DateTime? value) {
    if (value == null) return 'None yet';
    return context.smartTimestamp(value);
  }
}

class _BackupIntervalPicker extends ConsumerWidget {
  const _BackupIntervalPicker({required this.state});

  final CloudBackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Automatic backup interval'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BackupInterval>(
          value: state.status.interval,
          isExpanded: true,
          items: BackupInterval.values
              .map(
                (interval) => DropdownMenuItem<BackupInterval>(
                  value: interval,
                  child: Text(interval.label),
                ),
              )
              .toList(),
          onChanged: _intervalChanged(ref),
        ),
      ),
    );
  }

  ValueChanged<BackupInterval?>? _intervalChanged(WidgetRef ref) {
    if (state.isBusy) return null;
    return (interval) {
      if (interval == null) return;
      ref.read(cloudBackupNotifierProvider.notifier).setInterval(interval);
    };
  }
}

class _BackupHistory extends ConsumerWidget {
  const _BackupHistory({required this.state});

  final CloudBackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.status.backups.isEmpty) {
      return Text(
        'No backup created yet',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      );
    }

    final selectedBackup = state.selectedBackup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Backup history', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        ...state.status.backups.asMap().entries.map((entry) {
          final index = entry.key;
          final backup = entry.value;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            selected: selectedBackup?.id == backup.id,
            leading: Icon(_selectionIcon(selectedBackup?.id == backup.id)),
            onTap: _backupChanged(ref, backup.id),
            title: Text(_backupTitle(index)),
            subtitle: Text(_backupDetails(context, backup)),
          );
        }),
      ],
    );
  }

  String _backupTitle(int index) {
    if (index == 0) return 'Latest backup';
    return 'Backup ${index + 1}';
  }

  String _backupDetails(BuildContext context, BackupRecord backup) {
    final parts = <String>[];
    final modifiedAt = backup.modifiedAt;
    if (modifiedAt != null) {
      parts.add(context.smartTimestamp(modifiedAt));
    } else {
      parts.add('Date unavailable');
    }
    final sizeBytes = backup.sizeBytes;
    if (sizeBytes != null) {
      parts.add(_formatSize(sizeBytes));
    }
    return parts.join(' · ');
  }

  IconData _selectionIcon(bool selected) {
    if (selected) return Icons.radio_button_checked;
    return Icons.radio_button_unchecked;
  }

  VoidCallback? _backupChanged(WidgetRef ref, String backupId) {
    if (state.isBusy) return null;
    return () {
      ref.read(cloudBackupNotifierProvider.notifier).selectBackup(backupId);
    };
  }
}

String _formatSize(int? sizeBytes) {
  if (sizeBytes == null) return 'Unavailable';
  if (sizeBytes < 1024 * 1024) {
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
