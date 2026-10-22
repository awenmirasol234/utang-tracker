import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/domain/audit_action.dart';
import 'package:utang_tracker/core/domain/audit_change_detail.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/empty_state.dart';
import 'package:utang_tracker/core/widgets/error_view.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/features/audit/domain/entities/audit_log_entry.dart';
import 'package:utang_tracker/features/audit/presentation/providers/audit_log_providers.dart';

class AuditLogPage extends ConsumerWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditLogEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (error, stackTrace) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(auditLogEntriesProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'No audit log',
              message: 'No recorded changes yet.',
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(auditLogEntriesProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.sm,
                AppSpacing.pagePadding,
                AppSpacing.xxl,
              ),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _AuditLogTile(entry: entries[index]),
            ),
          );
        },
      ),
    );
  }
}

class _AuditLogTile extends StatefulWidget {
  const _AuditLogTile({required this.entry});

  final AuditLogEntry entry;

  @override
  State<_AuditLogTile> createState() => _AuditLogTileState();
}

class _AuditLogTileState extends State<_AuditLogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasDetails = entry.details.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActionIcon(action: entry.action),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.action.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      entry.summary,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.smartTimestamp(entry.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasDetails) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _expanded ? 'Hide details' : 'Show details',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'What changed',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...entry.details.map((detail) => _buildChange(context, detail)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildChange(BuildContext context, AuditChangeDetail detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _friendlyFieldLabels[detail.field] ?? detail.field,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          _buildChangeValue(context, detail),
        ],
      ),
    );
  }

  Widget _buildChangeValue(BuildContext context, AuditChangeDetail detail) {
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary);
    final beforeStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    if (detail.before == null) {
      return Text(
        _displayValue(context, detail.field, detail.after ?? ''),
        style: valueStyle,
      );
    }
    if (detail.after == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              _displayValue(context, detail.field, detail.before!),
              style: beforeStyle,
            ),
          ),
          Text(' (removed)', style: beforeStyle),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            _displayValue(context, detail.field, detail.before!),
            style: beforeStyle,
          ),
        ),
        const Text(' \u2192 '),
        Flexible(
          child: Text(
            _displayValue(context, detail.field, detail.after!),
            style: valueStyle,
          ),
        ),
      ],
    );
  }

  /// Renders a stored value the way the rest of the app shows it.
  String _displayValue(BuildContext context, String field, String value) {
    if (!_dateFields.contains(field)) {
      return value;
    }
    return DateFormatters.friendlyDayKey(
      value,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
  }
}

/// Field names as they are stored, mapped to the wording used on the forms.
const _friendlyFieldLabels = <String, String>{
  'Transaction date': 'Date',
  'Payment date': 'Date',
  'Method': 'Payment method',
  'Items added': 'Items',
};

/// Fields whose stored value is a `yyyy-MM-dd` day key.
const _dateFields = <String>{
  'Transaction date',
  'Due date',
  'Payment date',
};

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.action});

  final AuditAction action;

  @override
  Widget build(BuildContext context) {
    final (icon, color, backgroundColor) = switch (action) {
      AuditAction.customerCreated => (
        Icons.person_add_alt_rounded,
        AppColors.primaryDark,
        AppColors.primaryLight,
      ),
      AuditAction.customerUpdated => (
        Icons.edit_note_rounded,
        AppColors.primaryDark,
        AppColors.primaryLight,
      ),
      AuditAction.customerDeleted => (
        Icons.person_remove_rounded,
        AppColors.danger,
        AppColors.unpaidBg,
      ),
      AuditAction.debtCreated => (
        Icons.receipt_long_rounded,
        AppColors.partial,
        AppColors.partialBg,
      ),
      AuditAction.debtUpdated => (
        Icons.edit_note_rounded,
        AppColors.partial,
        AppColors.partialBg,
      ),
      AuditAction.debtItemsAdded => (
        Icons.add_shopping_cart_rounded,
        AppColors.partial,
        AppColors.partialBg,
      ),
      AuditAction.paymentRecorded => (
        Icons.payments_rounded,
        AppColors.paid,
        AppColors.paidBg,
      ),
      AuditAction.unknown => (
        Icons.help_outline_rounded,
        AppColors.textSecondary,
        AppColors.primaryLight,
      ),
    };

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
