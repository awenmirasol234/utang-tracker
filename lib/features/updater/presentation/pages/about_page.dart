import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_logo.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/core/widgets/release_note_bullet.dart';
import 'package:utang_tracker/features/updater/presentation/providers/update_providers.dart';
import 'package:utang_tracker/features/updater/presentation/widgets/update_bottom_sheet.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  String? _version;
  _ReleaseNotesData? _releaseNotes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(updateRepositoryProvider);
    final version = await repo.getCurrentVersion();
    final jsonStr = await repo.loadReleaseNotes().catchError((_) => '{}');
    if (mounted) {
      setState(() {
        _version = version;
        _releaseNotes = _ReleaseNotesData.tryParse(jsonStr);
      });
    }
  }

  Future<void> _checkForUpdates() async {
    await ref.read(updateNotifierProvider.notifier).checkForUpdates();
    if (!mounted) return;

    final state = ref.read(updateNotifierProvider);
    if (state is UpdateAvailable || state is UpdateDownloaded) {
      await showUpdateBottomSheet(context);
      return;
    }

    if (state is UpdateError) {
      AppSnackBar.error(context, state.message);
    } else {
      AppSnackBar.info(context, 'No new updates available.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateNotifierProvider);
    final isChecking = updateState is UpdateChecking;
    VoidCallback? updateHandler;
    if (!isChecking) {
      updateHandler = _checkForUpdates;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.lg,
        ),
        children: [
          _AppHeader(version: _version),
          const SizedBox(height: AppSpacing.xxl),
          _SectionLabel('Updates'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _CheckForUpdatesRow(
                  isChecking: isChecking,
                  onTap: updateHandler,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel("What's new"),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (_releaseNotes case final releaseNotes?)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormatters.fullDate(
                            releaseNotes.date,
                            locale: Localizations.localeOf(context).toString(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (
                          var index = 0;
                          index < releaseNotes.sections.length;
                          index++
                        ) ...[
                          if (index > 0)
                            const SizedBox(height: AppSpacing.md),
                          Text(
                            releaseNotes.sections[index].label,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          for (
                            final note in releaseNotes.sections[index].notes
                          )
                            ReleaseNoteBullet(note),
                        ],
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Release notes unavailable.'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _ReleaseNotesData {
  const _ReleaseNotesData({required this.date, required this.sections});

  final DateTime date;
  final List<_ReleaseNotesSection> sections;

  static _ReleaseNotesData? tryParse(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return null;
      final dateValue = decoded['date'];
      final notesValue = decoded['notes'];
      if (dateValue is! String || notesValue is! Map<String, dynamic>) {
        return null;
      }
      final date = DateTime.tryParse(dateValue);
      if (date == null || dateValue != DateFormatters.dayKey(date)) {
        return null;
      }

      const labels = {'added': 'Added', 'changed': 'Changed', 'fixed': 'Fixed'};
      final sections = <_ReleaseNotesSection>[];
      for (final entry in labels.entries) {
        final value = notesValue[entry.key];
        if (value is! List || value.any((item) => item is! String)) return null;
        final notes = value.cast<String>();
        if (notes.isNotEmpty) {
          sections.add(_ReleaseNotesSection(label: entry.value, notes: notes));
        }
      }
      if (sections.isEmpty) return null;
      return _ReleaseNotesData(date: date, sections: sections);
    } on FormatException {
      return null;
    }
  }
}

class _ReleaseNotesSection {
  const _ReleaseNotesSection({required this.label, required this.notes});

  final String label;
  final List<String> notes;
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.version});

  final String? version;

  @override
  Widget build(BuildContext context) {
    String versionLabel;
    if (version != null) {
      versionLabel = 'v$version';
    } else {
      versionLabel = '—';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const AppLogo(size: 72, borderRadius: 18),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          versionLabel,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _CheckForUpdatesRow extends StatelessWidget {
  const _CheckForUpdatesRow({required this.isChecking, required this.onTap});

  final bool isChecking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Check for updates',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isChecking)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryDark,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryDark,
              ),
          ],
        ),
      ),
    );
  }
}
