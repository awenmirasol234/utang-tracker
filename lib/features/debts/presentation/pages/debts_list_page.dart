import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_filter_chip.dart';
import 'package:utang_tracker/core/widgets/empty_state.dart';
import 'package:utang_tracker/core/widgets/error_view.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/core/widgets/money_text.dart';
import 'package:utang_tracker/core/widgets/status_badge.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_sort_order.dart';
import 'package:utang_tracker/features/debts/presentation/providers/debt_providers.dart';

class DebtsListPage extends ConsumerWidget {
  const DebtsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(debtStatusFilterProvider);
    final sort = ref.watch(debtSortOrderProvider);
    final debtsAsync = ref.watch(debtsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Debts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/debts/new'),
        tooltip: 'New debt',
        icon: const Icon(Icons.add),
        label: const Text('New debt'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppFilterChip(
                          label: 'All',
                          selected: filter == DebtListFilter.all,
                          onSelected: () => ref
                              .read(debtStatusFilterProvider.notifier)
                              .setFilter(DebtListFilter.all),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ...DebtListFilter.values
                            .skip(1)
                            .map(
                              (filterValue) => Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.sm,
                                ),
                                child: AppFilterChip(
                                  label: filterValue.label,
                                  selected: filter == filterValue,
                                  onSelected: () => ref
                                      .read(debtStatusFilterProvider.notifier)
                                      .setFilter(filterValue),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PopupMenuButton<DebtSortOrder>(
                  tooltip: 'Sort debts',
                  initialValue: sort,
                  onSelected: (order) {
                    ref.read(debtSortOrderProvider.notifier).setSort(order);
                  },
                  itemBuilder: (context) {
                    return DebtSortOrder.values.map((order) {
                      Widget? checkIcon;
                      if (sort == order) {
                        checkIcon = const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.primaryDark,
                        );
                      }
                      return PopupMenuItem<DebtSortOrder>(
                        value: order,
                        child: Row(
                          children: [
                            SizedBox(width: 28, child: checkIcon),
                            Expanded(child: Text(order.label)),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    width: AppSpacing.minTapTarget,
                    height: AppSpacing.minTapTarget,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: debtsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, stackTrace) => ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(debtsListProvider),
              ),
              data: (debts) {
                if (debts.isEmpty) {
                  String emptyMessage;
                  if (filter == DebtListFilter.all) {
                    emptyMessage = 'Tap + New debt to add.';
                  } else {
                    emptyMessage = 'No ${filter.label.toLowerCase()} debts.';
                  }
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No debts yet',
                    message: emptyMessage,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(debtsListProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.xs,
                      AppSpacing.pagePadding,
                      104,
                    ),
                    itemCount: debts.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final debt = debts[index];
                      return AppCard(
                        onTap: () => context.push('/debts/${debt.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    debt.customerName ?? 'Customer',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                StatusBadge(status: debt.status),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    context.smartTimestamp(
                                      debt.transactionDate,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                                MoneyText(debt.balance),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
