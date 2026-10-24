import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/utils/user_facing_error.dart';
import 'package:utang_tracker/core/widgets/app_button.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/core/widgets/error_view.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/core/widgets/money_text.dart';
import 'package:utang_tracker/core/widgets/status_badge.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';
import 'package:utang_tracker/features/debts/presentation/providers/debt_providers.dart';
import 'package:utang_tracker/features/debts/presentation/widgets/debt_item_sheet.dart';

class DebtDetailPage extends ConsumerWidget {
  const DebtDetailPage({super.key, required this.debtId});

  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(debtDetailProvider(debtId));

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Debt')),
        body: const LoadingIndicator(),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Debt')),
        body: ErrorView(
          message: userFacingError(error),
          onRetry: () => ref.invalidate(debtDetailProvider(debtId)),
        ),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Debt')),
            body: const Center(child: Text('Debt not found')),
          );
        }

        final debt = data.detail.debt;
        final items = data.detail.items;
        final payments = data.payments;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Debt details'),
            actions: [
              if (debt.isEditable)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/debts/$debtId/edit'),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(debtDetailProvider(debtId));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  context.push('/customers/${debt.customerId}'),
                              child: Text(
                                debt.customerName ?? 'Customer',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ),
                          StatusBadge(status: debt.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _kv(
                        context,
                        'Date',
                        context.smartTimestamp(debt.transactionDate),
                        valueAlignRight: true,
                      ),
                      if (debt.dueDate != null)
                        _kv(
                          context,
                          'Due date',
                          context.smartDate(debt.dueDate!),
                          valueAlignRight: true,
                        ),
                      const Divider(height: AppSpacing.xl),
                      _amountRow(context, 'Total', debt.totalAmount),
                      _amountRow(context, 'Paid', debt.paidAmount),
                      _amountRow(
                        context,
                        'Balance',
                        debt.balance,
                        emphasize: true,
                      ),
                      if (debt.notes != null && debt.notes!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Note',
                          key: const Key('debt-note-label'),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          debt.notes!,
                          key: const Key('debt-note-text'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (debt.status != DebtStatus.paid) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Record payment',
                    onPressed: () =>
                        context.push('/payments/new?debtId=$debtId'),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items (${items.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (debt.status == DebtStatus.partial)
                      TextButton.icon(
                        key: const Key('add-debt-item-button'),
                        onPressed: () => _addItem(context, ref, debt),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add item'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _DebtItemsCard(items: items, totalAmount: debt.totalAmount),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Payments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (payments.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        'No payments yet.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  ...payments.map(
                    (payment) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.smartTimestamp(payment.paymentDate),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    payment.paymentMethod,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            MoneyText(payment.amount, color: AppColors.paid),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref, Debt debt) async {
    final result = await showDebtItemSheet(context);
    if (result == null) return;
    final input = result.input;
    if (input == null) return;
    if (!context.mounted) return;

    final newTotal = debt.totalAmount + input.price;
    final newBalance = newTotal - debt.paidAmount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xl,
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.pagePadding,
          AppSpacing.xl,
          0,
        ),
        title: const Text('Add item?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              input.productName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Amount: ${input.price.format()}'),
            Text('New balance: ${newBalance.format()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add item'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref
          .read(debtOperationsProvider)
          .addItems(debtId: debt.id, items: [input]);
      if (!context.mounted) return;
      ref.read(dataVersionProvider.notifier).bump();
      AppSnackBar.success(context, 'Item added');
    } on AppException catch (appException) {
      if (!context.mounted) return;
      AppSnackBar.error(context, appException.message);
    } catch (caughtError) {
      if (!context.mounted) return;
      AppSnackBar.error(context, userFacingError(caughtError));
    }
  }

  Widget _kv(
    BuildContext context,
    String label,
    String value, {
    bool valueAlignRight = false,
  }) {
    TextAlign valueAlignment;
    if (valueAlignRight) {
      valueAlignment = TextAlign.right;
    } else {
      valueAlignment = TextAlign.left;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: valueAlignment,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
    BuildContext context,
    String label,
    Money money, {
    bool emphasize = false,
  }) {
    TextStyle? amountStyle;
    if (emphasize) {
      amountStyle = Theme.of(context).textTheme.titleMedium;
    } else {
      amountStyle = Theme.of(context).textTheme.bodyLarge;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          MoneyText(money, style: amountStyle),
        ],
      ),
    );
  }
}

class _DebtItemsCard extends StatelessWidget {
  const _DebtItemsCard({required this.items, required this.totalAmount});

  final List<DebtItem> items;
  final Money totalAmount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('debt-items-card'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _DebtItemRow(item: items[index]),
            if (index < items.length - 1)
              const Divider(
                height: 1,
                indent: AppSpacing.cardPadding,
                endIndent: AppSpacing.cardPadding,
              ),
          ],
          const Divider(height: 1),
          Padding(
            key: const Key('debt-items-total-row'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                MoneyText(
                  totalAmount,
                  key: const Key('debt-items-total-amount'),
                  color: AppColors.primaryDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtItemRow extends StatelessWidget {
  const _DebtItemRow({required this.item});

  final DebtItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final descriptionStyle = textTheme.bodyMedium!;
    final subtotalStyle = textTheme.bodyLarge!;
    final quantityAndUnit =
        '${DebtItemUnits.formatQuantity(item.quantity)} '
        '${DebtItemUnits.displayNameForQuantity(item.unit, item.quantity)}';

    return Padding(
      key: ValueKey('debt-item-row-${item.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  key: ValueKey('debt-item-name-${item.id}'),
                  style: descriptionStyle.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  quantityAndUnit,
                  key: ValueKey('debt-item-meta-${item.id}'),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          MoneyText(
            item.price,
            key: ValueKey('debt-item-subtotal-${item.id}'),
            style: subtotalStyle,
          ),
        ],
      ),
    );
  }
}
