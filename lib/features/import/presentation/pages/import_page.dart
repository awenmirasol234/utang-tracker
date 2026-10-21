import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/app/coordination.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/widgets/app_button.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/features/import/domain/entities/import_file.dart';
import 'package:utang_tracker/features/import/domain/entities/import_issue.dart';
import 'package:utang_tracker/features/import/domain/entities/import_summary.dart';
import 'package:utang_tracker/features/import/presentation/providers/import_providers.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  List<ImportFile> _files = [];
  ImportSummary? _summary;
  bool _busy = false;

  Future<void> _pickFiles() async {
    setState(() => _busy = true);
    try {
      final files = await ref.read(csvFilePickerProvider).pickCsvFiles();
      if (!mounted) {
        return;
      }
      if (files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final summary = await ref.read(importDataUseCaseProvider).validate(files);
      if (!mounted) {
        return;
      }
      setState(() {
        _files = files;
        _summary = summary;
        _busy = false;
      });
    } on AppException catch (appException) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      AppSnackBar.error(context, appException.message);
    } catch (caughtError) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      AppSnackBar.error(context, caughtError.toString());
    }
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      final summary = await ref.read(importDataUseCaseProvider).apply(_files);
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _busy = false;
      });
      if (summary.hasIssues) {
        AppSnackBar.error(
          context,
          'Nothing was imported. Fix the errors and pick the file again.',
        );
        return;
      }
      invalidateBusinessData(ref);
      AppSnackBar.success(context, 'Imported ${summary.records} records');
      context.pop();
    } on AppException catch (appException) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      AppSnackBar.error(context, appException.message);
    } catch (caughtError) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      AppSnackBar.error(context, caughtError.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(title: const Text('Import data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            color: AppColors.surfaceRaised,
            borderColor: AppColors.outline,
            child: Text(
              'Pick the CSV files you exported from this app. Every row is '
              'checked first, and nothing is saved unless all rows are valid.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Choose CSV files',
            icon: Icons.upload_file_outlined,
            isLoading: _busy,
            onPressed: _pickFiles,
          ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _FilesCard(files: _files),
          ],
          if (summary != null) ...[
            const SizedBox(height: AppSpacing.lg),
            if (summary.hasIssues)
              _IssuesCard(issues: summary.issues)
            else
              _ReadyCard(summary: summary),
          ],
          if (summary != null && !summary.hasIssues) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Import',
              icon: Icons.download_done_outlined,
              isLoading: _busy,
              onPressed: _apply,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilesCard extends StatelessWidget {
  const _FilesCard({required this.files});

  final List<ImportFile> files;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceCard,
      borderColor: AppColors.outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Picked files', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final file in files)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      file.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IssuesCard extends StatelessWidget {
  const _IssuesCard({required this.issues});

  final List<ImportIssue> issues;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.unpaidBg,
      borderColor: AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nothing was imported',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Fix these rows in the CSV file and pick it again.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${issue.fileName} - row ${issue.rowNumber}: ${issue.message}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.summary});

  final ImportSummary summary;

  @override
  Widget build(BuildContext context) {
    final skipped = summary.skipped;
    return AppCard(
      color: AppColors.paidBg,
      borderColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready to import',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.success),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${summary.customers} customers, ${summary.debts} debts and '
            '${summary.payments} payments.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (skipped > 0)
            Text(
              '$skipped rows skipped because the record already exists.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
