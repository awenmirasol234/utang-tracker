import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/widgets/app_button.dart';
import 'package:utang_tracker/core/widgets/app_modal_bottom_sheet.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/presentation/providers/update_providers.dart';

Future<void> showUpdateBottomSheet(BuildContext context) {
  return showAppModalBottomSheet<void>(
    context: context,
    builder: (_) => const _UpdateSheet(),
  );
}

class _UpdateSheet extends ConsumerWidget {
  const _UpdateSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateNotifierProvider);
    final notifier = ref.read(updateNotifierProvider.notifier);

    return AppModalBottomSheet(
      title: 'App update',
      heightFactor: 0.85,
      child: switch (state) {
        UpdateChecking() => const LoadingIndicator(
          message: 'Checking for updates…',
        ),
        UpdateNotAvailable() => _UpToDate(onDone: () => Navigator.pop(context)),
        UpdateAvailable(:final release, :final asset, :final currentVersion) =>
          _UpdateAvailableBody(
            release: release,
            asset: asset,
            currentVersion: currentVersion,
            onUpdate: notifier.download,
            onLater: () {
              notifier.dismiss();
              Navigator.pop(context);
            },
          ),
        UpdateDownloading(:final progress, :final release) => _DownloadingBody(
          release: release,
          progress: progress,
          onCancel: () {
            notifier.reset();
            Navigator.pop(context);
          },
        ),
        UpdateDownloaded(:final release) => _DownloadedBody(
          release: release,
          onInstall: notifier.install,
          onCancel: () => Navigator.pop(context),
        ),
        UpdatePermissionRequired(:final release) => _PermissionRequiredBody(
          release: release,
          onOpenSettings: notifier.openInstallSettings,
          onInstall: notifier.install,
          onDismiss: () => Navigator.pop(context),
        ),
        UpdateInstalling() => const LoadingIndicator(
          message: 'Opening installer…',
        ),
        UpdateError(
          :final message,
          :final isNetworkError,
          :final isPermissionError,
        ) =>
          _ErrorBody(
            message: message,
            isNetworkError: isNetworkError,
            isPermissionError: isPermissionError,
            onRetry: () => notifier.checkForUpdates(),
            onOpenSettings: notifier.openInstallSettings,
            onDismiss: () => Navigator.pop(context),
          ),
        _ => const LoadingIndicator(message: 'Checking for updates…'),
      },
    );
  }
}

class _UpToDate extends StatelessWidget {
  const _UpToDate({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.paidBg,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 36,
              color: AppColors.paid,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'You\'re up to date',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The latest version is already installed.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}

class _UpdateAvailableBody extends StatelessWidget {
  const _UpdateAvailableBody({
    required this.release,
    required this.asset,
    required this.currentVersion,
    required this.onUpdate,
    required this.onLater,
  });

  final AppRelease release;
  final ReleaseAsset asset;
  final String currentVersion;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final sizeMb = (asset.sizeBytes / (1024 * 1024)).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.md,
              AppSpacing.pagePadding,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VersionRow(
                  currentVersion: currentVersion,
                  latestVersion: release.version,
                ),
                const SizedBox(height: AppSpacing.lg),
                _InfoChip(icon: Icons.download_outlined, label: '$sizeMb MB'),
                const SizedBox(height: AppSpacing.lg),
                if (release.releaseNotes.isNotEmpty) ...[
                  Text(
                    "What's new",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: _ReleaseNotesBody(body: release.releaseNotes),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.sm,
              AppSpacing.pagePadding,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: 'Update now',
                  icon: Icons.download_rounded,
                  onPressed: onUpdate,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Later',
                  variant: AppButtonVariant.secondary,
                  onPressed: onLater,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReleaseNotesBody extends StatelessWidget {
  const _ReleaseNotesBody({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final sections = _parseReleaseNotes(body);
    if (sections.isEmpty) {
      return Text(
        body,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.md),
          Text(
            sections[index].label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final note in sections[index].notes) _ReleaseNoteBullet(note),
        ],
      ],
    );
  }
}

class _ReleaseNoteBullet extends StatelessWidget {
  const _ReleaseNoteBullet(this.note);

  final String note;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      height: 1.6,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•  ', style: style),
        Expanded(child: Text(note, style: style)),
      ],
    );
  }
}

List<({String label, List<String> notes})> _parseReleaseNotes(String body) {
  final sections = <({String label, List<String> notes})>[];
  String? label;
  final notes = <String>[];

  void flush() {
    if (label != null && notes.isNotEmpty) {
      sections.add((label: label, notes: List.of(notes)));
    }
    notes.clear();
  }

  for (final line in body.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('## ')) {
      flush();
      label = trimmed.substring(3).trim();
    } else if (trimmed.startsWith('- ') && label != null) {
      notes.add(trimmed.substring(2).trim());
    }
  }
  flush();

  return sections;
}

class _DownloadingBody extends StatelessWidget {
  const _DownloadingBody({
    required this.release,
    required this.progress,
    required this.onCancel,
  });

  final AppRelease release;
  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Icon(
            Icons.downloading_rounded,
            size: 48,
            color: AppColors.primaryDark,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Downloading v${release.version}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.primaryLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryDark),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$pct%',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _DownloadedBody extends StatelessWidget {
  const _DownloadedBody({
    required this.release,
    required this.onInstall,
    required this.onCancel,
  });

  final AppRelease release;
  final VoidCallback onInstall;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.install_mobile_rounded,
              size: 36,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'v${release.version} ready to install',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap Install to open the Android package installer.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Install now',
            icon: Icons.install_mobile_rounded,
            onPressed: onInstall,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Later',
            variant: AppButtonVariant.secondary,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.isNetworkError,
    required this.isPermissionError,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final String message;
  final bool isNetworkError;
  final bool isPermissionError;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    if (isPermissionError) {
      icon = Icons.security_rounded;
    } else if (isNetworkError) {
      icon = Icons.wifi_off_rounded;
    } else {
      icon = Icons.error_outline_rounded;
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Icon(icon, size: 48, color: AppColors.danger),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (isPermissionError) ...[
            AppButton(
              label: 'Open Settings',
              icon: Icons.settings_rounded,
              onPressed: onOpenSettings,
            ),
          ] else ...[
            AppButton(label: 'Try again', onPressed: onRetry),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Dismiss',
            variant: AppButtonVariant.secondary,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _PermissionRequiredBody extends StatelessWidget {
  const _PermissionRequiredBody({
    required this.release,
    required this.onOpenSettings,
    required this.onInstall,
    required this.onDismiss,
  });

  final AppRelease release;
  final VoidCallback onOpenSettings;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.security_rounded,
              size: 36,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Enable installation from unknown sources',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'v${release.version} has been downloaded. To install it, '
            'allow the app to install from unknown sources in your device settings.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Open Settings',
            icon: Icons.settings_rounded,
            onPressed: onOpenSettings,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Install now',
            icon: Icons.install_mobile_rounded,
            onPressed: onInstall,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Dismiss',
            variant: AppButtonVariant.secondary,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.currentVersion,
    required this.latestVersion,
  });

  final String currentVersion;
  final String latestVersion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VersionBadge(
            label: 'Installed',
            version: 'v$currentVersion',
            color: AppColors.surfaceRaised,
            textColor: AppColors.textSecondary,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
        ),
        Expanded(
          child: _VersionBadge(
            label: 'Latest',
            version: 'v$latestVersion',
            color: AppColors.primaryLight,
            textColor: AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({
    required this.label,
    required this.version,
    required this.color,
    required this.textColor,
  });

  final String label;
  final String version;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            version,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
