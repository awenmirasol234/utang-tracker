import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_search_bar.dart';
import 'package:utang_tracker/core/widgets/empty_state.dart';
import 'package:utang_tracker/core/widgets/error_view.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/features/customers/presentation/providers/customer_providers.dart';

class CustomersListPage extends ConsumerWidget {
  const CustomersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(customerSortOrderProvider);
    final customersAsync = ref.watch(customersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customers/new'),
        tooltip: 'Add customer',
        icon: const Icon(Icons.add),
        label: const Text('Add customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              0,
              AppSpacing.pagePadding,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    hintText: 'Search by customer name',
                    onChanged: (value) {
                      ref
                          .read(customerSearchQueryProvider.notifier)
                          .setQuery(value);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PopupMenuButton<CustomerSortOrder>(
                  tooltip: 'Sort customers',
                  initialValue: sort,
                  onSelected: (order) {
                    ref.read(customerSortOrderProvider.notifier).setSort(order);
                  },
                  itemBuilder: (context) {
                    return CustomerSortOrder.values.map((order) {
                      Widget? checkIcon;
                      if (sort == order) {
                        checkIcon = const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.primaryDark,
                        );
                      }
                      return PopupMenuItem<CustomerSortOrder>(
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
            child: customersAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, stackTrace) => ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(customersListProvider),
              ),
              data: (customers) {
                if (customers.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: 'No customers yet',
                    message: 'Tap + Add customer to add.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(customersListProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.xs,
                      AppSpacing.pagePadding,
                      104,
                    ),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      Color avatarColor;
                      if (index.isEven) {
                        avatarColor = AppColors.primaryLight;
                      } else {
                        avatarColor = AppColors.accentLight;
                      }
                      String initial;
                      if (customer.name.isNotEmpty) {
                        initial = customer.name[0].toUpperCase();
                      } else {
                        initial = '?';
                      }
                      return AppCard(
                        onTap: () => context.push('/customers/${customer.id}'),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: avatarColor,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Text(
                                initial,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (customer.phone != null &&
                                      customer.phone!.isNotEmpty)
                                    Text(
                                      customer.phone!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 15,
                              color: AppColors.textMuted,
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
