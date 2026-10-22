import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_sort_order.dart';
import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';

enum DebtListFilter { all, unpaid, partial, paid, overdue }

extension DebtListFilterX on DebtListFilter {
  String get label => switch (this) {
    DebtListFilter.all => 'All',
    DebtListFilter.unpaid => DebtStatus.unpaid.label,
    DebtListFilter.partial => DebtStatus.partial.label,
    DebtListFilter.paid => DebtStatus.paid.label,
    DebtListFilter.overdue => 'Overdue',
  };

  DebtStatus? get status => switch (this) {
    DebtListFilter.unpaid => DebtStatus.unpaid,
    DebtListFilter.partial => DebtStatus.partial,
    DebtListFilter.paid => DebtStatus.paid,
    _ => null,
  };
}

class DebtStatusFilter extends Notifier<DebtListFilter> {
  @override
  DebtListFilter build() => DebtListFilter.all;

  void setFilter(DebtListFilter filter) => state = filter;
}

final debtStatusFilterProvider =
    NotifierProvider<DebtStatusFilter, DebtListFilter>(DebtStatusFilter.new);

class DebtSortFilter extends Notifier<DebtSortOrder> {
  @override
  DebtSortOrder build() => DebtSortOrder.newest;

  void setSort(DebtSortOrder order) => state = order;
}

final debtSortOrderProvider = NotifierProvider<DebtSortFilter, DebtSortOrder>(
  DebtSortFilter.new,
);

final debtsListProvider = AsyncNotifierProvider<DebtsListNotifier, List<Debt>>(
  DebtsListNotifier.new,
);

class DebtsListNotifier extends AsyncNotifier<List<Debt>> {
  @override
  Future<List<Debt>> build() async {
    final filter = ref.watch(debtStatusFilterProvider);
    final sort = ref.watch(debtSortOrderProvider);
    final debts = await _loadDebts(filter);
    return applySort(debts, sort);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final filter = ref.read(debtStatusFilterProvider);
      final sort = ref.read(debtSortOrderProvider);
      final debts = await _loadDebts(filter);
      return applySort(debts, sort);
    });
  }

  Future<List<Debt>> _loadDebts(DebtListFilter filter) async {
    final debts = await ref
        .read(debtRepositoryProvider)
        .getAll(status: filter.status);
    if (filter != DebtListFilter.overdue) return debts;

    return debts.where(_isOverdue).toList(growable: false);
  }
}

bool _isOverdue(Debt debt) {
  final dueDate = debt.dueDate;
  if (dueDate == null ||
      debt.status == DebtStatus.paid ||
      !debt.balance.isPositive) {
    return false;
  }
  return _localDay(dueDate).isBefore(_localDay(DateTime.now()));
}

DateTime _localDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class DebtDetailViewData {
  const DebtDetailViewData({required this.detail, required this.payments});

  final DebtDetail detail;
  final List<Payment> payments;
}

final debtDetailProvider = FutureProvider.family<DebtDetailViewData?, String>((
  ref,
  id,
) async {
  final detail = await ref.watch(debtRepositoryProvider).getById(id);
  if (detail == null) return null;
  final payments = await ref.watch(paymentRepositoryProvider).getByDebt(id);
  return DebtDetailViewData(detail: detail, payments: payments);
});
