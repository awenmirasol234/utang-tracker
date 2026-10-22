import 'package:utang_tracker/features/debts/domain/entities/debt.dart';

enum DebtSortOrder {
  newest('Newest'),
  highestBalance('Highest balance'),
  lowestBalance('Lowest balance');

  const DebtSortOrder(this.label);

  final String label;
}

List<Debt> applySort(List<Debt> debts, DebtSortOrder sort) {
  final sorted = List<Debt>.from(debts);
  final int Function(Debt first, Debt second) comparator = switch (sort) {
    DebtSortOrder.newest => (first, second) =>
      second.transactionDate.compareTo(first.transactionDate),
    DebtSortOrder.highestBalance => (first, second) =>
      second.balance.centavos.compareTo(first.balance.centavos),
    DebtSortOrder.lowestBalance => (first, second) =>
      first.balance.centavos.compareTo(second.balance.centavos),
  };
  sorted.sort(comparator);
  return sorted;
}
