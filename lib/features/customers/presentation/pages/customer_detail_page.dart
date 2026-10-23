import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/utils/user_facing_error.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/core/widgets/empty_state.dart';
import 'package:utang_tracker/core/widgets/error_view.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/core/widgets/money_text.dart';
import 'package:utang_tracker/core/widgets/status_badge.dart';
import 'package:utang_tracker/features/customers/domain/usecases/get_customer_detail.dart';
import 'package:utang_tracker/features/customers/presentation/providers/customer_providers.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerDetailProvider(customerId));

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: const LoadingIndicator(),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: ErrorView(
          message: userFacingError(error),
          onRetry: () => ref.invalidate(customerDetailProvider(customerId)),
        ),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Customer')),
            body: const Center(child: Text('Customer not found')),
          );
        }

        final customer = data.customer;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(customer.name),
              actions: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/customers/$customerId/edit'),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/debts/new?customerId=$customerId'),
              tooltip: 'New debt',
              icon: const Icon(Icons.add),
              label: const Text('New debt'),
            ),
            body: RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(customerDetailProvider(customerId).future),
              child: NestedScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.lg,
                      AppSpacing.pagePadding,
                      AppSpacing.lg,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _CustomerSummaryCard(data: data),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarHeaderDelegate(
                      child: const _HistoryTabBar(),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _DebtHistoryList(debts: data.debts),
                    _PaymentHistoryList(payments: data.payments),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CustomerSummaryCard extends StatelessWidget {
  const _CustomerSummaryCard({required this.data});

  final CustomerDetailData data;

  @override
  Widget build(BuildContext context) {
    final customer = data.customer;
    Color balanceColor;
    if (data.outstandingBalance.isZero) {
      balanceColor = AppColors.paid;
    } else {
      balanceColor = AppColors.unpaid;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remaining balance',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          MoneyText(
            data.outstandingBalance,
            style: Theme.of(context).textTheme.headlineSmall,
            color: balanceColor,
          ),
          if (customer.phone != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(customer.phone!)),
                IconButton(
                  tooltip: 'Copy phone number',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: customer.phone!),
                    );
                    if (!context.mounted) return;
                    AppSnackBar.success(context, 'Phone number copied');
                  },
                ),
              ],
            ),
          ],
          if (customer.notes != null && customer.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    customer.notes!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTabBar extends StatelessWidget {
  const _HistoryTabBar();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: const TabBar(
        tabs: [
          Tab(text: 'Debts'),
          Tab(text: 'Payments'),
        ],
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(_TabBarHeaderDelegate oldDelegate) =>
      child != oldDelegate.child;
}

class _DebtHistoryList extends StatelessWidget {
  const _DebtHistoryList({required this.debts});

  final List<Debt> debts;

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return ListView(
        key: const PageStorageKey('empty-debt-history'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No debts yet',
            message: 'Tap + New debt to add.',
          ),
        ],
      );
    }

    return ListView.separated(
      key: const PageStorageKey('debt-history'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        100,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: debts.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final debt = debts[index];
        return AppCard(
          onTap: () => context.push('/debts/${debt.id}'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.smartTimestamp(debt.transactionDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: debt.status),
                  const SizedBox(height: AppSpacing.xs),
                  MoneyText(debt.balance),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentHistoryList extends StatelessWidget {
  const _PaymentHistoryList({required this.payments});

  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return ListView(
        key: const PageStorageKey('empty-payment-history'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          EmptyState(
            icon: Icons.payments_outlined,
            title: 'No payments yet',
            message: 'Tap + Record payment to add.',
          ),
        ],
      );
    }

    return ListView.separated(
      key: const PageStorageKey('payment-history'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        100,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: payments.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final payment = payments[index];
        return AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.smartTimestamp(payment.paymentDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(payment.amount, color: AppColors.paid),
                  Text(
                    payment.paymentMethod,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
