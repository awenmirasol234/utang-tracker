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
  switch (sort) {
    case DebtSortOrder.newest:
      sorted.sort((first, second) => second.transactionDate.compareTo(first.transactionDate));
    case DebtSortOrder.highestBalance:
      sorted.sort((first, second) => second.balance.centavos.compareTo(first.balance.centavos));
    case DebtSortOrder.lowestBalance:
      sorted.sort((first, second) => first.balance.centavos.compareTo(second.balance.centavos));
  }
  return sorted;
}
