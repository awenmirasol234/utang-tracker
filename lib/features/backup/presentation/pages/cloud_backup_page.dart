import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/widgets/app_button.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/core/widgets/app_text_field.dart';
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
            Row(
              children: [
                const Icon(Icons.cloud_off_outlined),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Not connected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Choose your Google account, then allow Drive access for backups.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Connect Google Drive',
              leading: SvgPicture.asset(
                'assets/images/google-drive-logo.svg',
                width: 20,
                height: 20,
                semanticsLabel: 'Google',
              ),
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
          Row(
            children: [
              SvgPicture.asset(
                'assets/images/google-drive-connected-logo.svg',
                width: 24,
                height: 24,
                semanticsLabel: 'Google Drive',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Drive connected',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      state.status.email ?? 'Google account',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _LastBackupSummary(status: state.status),
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
          if (state.status.backups.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _BackupHistory(
              state: state,
              onRestore: () => _confirmRestore(context, ref),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Sign out',
              variant: AppButtonVariant.secondary,
              icon: Icons.logout_rounded,
              expanded: false,
              isLoading: state.operation == BackupOperation.signingOut,
              onPressed: _enabledAction(state.isBusy, () async {
                final success = await ref
                    .read(cloudBackupNotifierProvider.notifier)
                    .signOut();
                if (!success || !context.mounted) return;
                AppSnackBar.info(context, 'Google Drive disconnected');
              }),
            ),
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

class _LastBackupSummary extends StatelessWidget {
  const _LastBackupSummary({required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    final lastBackupText = _lastBackupText(context, status.lastBackupAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Last backup', style: Theme.of(context).textTheme.titleSmall),
            Text(lastBackupText, style: Theme.of(context).textTheme.bodySmall),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField.buildLabel(context, 'Automatic backup interval'),
        const SizedBox(height: AppSpacing.sm),
        InputDecorator(
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BackupInterval>(
              value: state.status.interval,
              isExpanded: true,
              isDense: true,
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
        ),
      ],
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
  const _BackupHistory({required this.state, required this.onRestore});

  final CloudBackupState state;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBackup = state.selectedBackup;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('Backup history'),
      subtitle: Text(
        '${state.status.backups.length} of ${BackupStatus.maxBackups} backups',
      ),
      children: [
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
        AppButton(
          label: 'Restore selected backup',
          variant: AppButtonVariant.secondary,
          icon: Icons.cloud_download_outlined,
          isLoading: state.operation == BackupOperation.restoring,
          onPressed: _enabledAction(
            state.isBusy || selectedBackup == null,
            onRestore,
          ),
        ),
      ],
    );
  }

  String _backupTitle(int index) {
    if (index == 0) return 'Latest backup';
    return 'Backup ${index + 1}';
  }

  String _backupDetails(BuildContext context, BackupRecord backup) {
    final modifiedAt = backup.modifiedAt;
    if (modifiedAt == null) return 'Date unavailable';
    return context.smartTimestamp(modifiedAt);
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

  VoidCallback? _enabledAction(bool disabled, VoidCallback action) {
    if (disabled) return null;
    return action;
  }
}
