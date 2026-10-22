import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_sort_order.dart';
import 'package:utang_tracker/features/debts/domain/usecases/get_debt_detail.dart';

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

class DebtStatusFilterNotifier extends Notifier<DebtListFilter> {
  @override
  DebtListFilter build() => DebtListFilter.all;

  void setFilter(DebtListFilter filter) => state = filter;
}

final debtStatusFilterProvider =
    NotifierProvider<DebtStatusFilterNotifier, DebtListFilter>(
      DebtStatusFilterNotifier.new,
    );

class DebtSortFilterNotifier extends Notifier<DebtSortOrder> {
  @override
  DebtSortOrder build() => DebtSortOrder.newest;

  void setSort(DebtSortOrder order) => state = order;
}

final debtSortOrderProvider =
    NotifierProvider<DebtSortFilterNotifier, DebtSortOrder>(
      DebtSortFilterNotifier.new,
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

    final now = DateTime.now();
    return debts
        .where((debt) => debt.isOverdue(now: now))
        .toList(growable: false);
  }
}

final getDebtDetailUseCaseProvider = Provider((ref) {
  return GetDebtDetail(
    debts: ref.watch(debtRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
  );
});

final debtDetailProvider = FutureProvider.family<DebtDetailData?, String>((
  ref,
  id,
) async {
  return ref.watch(getDebtDetailUseCaseProvider)(id);
});
