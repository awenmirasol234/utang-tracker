import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/domain/audit_action.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/empty_state.dart';
import 'package:utang_tracker/core/widgets/error_view.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
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
              title: 'Walay audit log',
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
              itemBuilder: (context, index) {
                final entry = entries[index];
                return AppCard(
                  child: Row(
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              context.smartTimestamp(entry.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.action});

  final AuditAction action;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final Color backgroundColor;
    switch (action) {
      case AuditAction.customerCreated:
        icon = Icons.person_add_alt_rounded;
        color = AppColors.primaryDark;
        backgroundColor = AppColors.primaryLight;
      case AuditAction.customerUpdated:
        icon = Icons.edit_note_rounded;
        color = AppColors.primaryDark;
        backgroundColor = AppColors.primaryLight;
      case AuditAction.customerDeleted:
        icon = Icons.person_remove_rounded;
        color = AppColors.danger;
        backgroundColor = AppColors.unpaidBg;
      case AuditAction.debtCreated:
        icon = Icons.receipt_long_rounded;
        color = AppColors.partial;
        backgroundColor = AppColors.partialBg;
      case AuditAction.debtUpdated:
        icon = Icons.edit_note_rounded;
        color = AppColors.partial;
        backgroundColor = AppColors.partialBg;
      case AuditAction.debtItemsAdded:
        icon = Icons.add_shopping_cart_rounded;
        color = AppColors.partial;
        backgroundColor = AppColors.partialBg;
      case AuditAction.paymentRecorded:
        icon = Icons.payments_rounded;
        color = AppColors.paid;
        backgroundColor = AppColors.paidBg;
      case AuditAction.unknown:
        icon = Icons.help_outline_rounded;
        color = AppColors.textSecondary;
        backgroundColor = AppColors.primaryLight;
    }

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
