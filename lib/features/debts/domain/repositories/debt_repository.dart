import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';

class DebtDetail {
  const DebtDetail({required this.debt, required this.items});

  final Debt debt;
  final List<DebtItem> items;
}

abstract class DebtRepository {
  Future<List<Debt>> getAll({DebtStatus? status});
  Future<List<Debt>> getByCustomer(String customerId);
  Future<DebtDetail?> getById(String debtId);

  /// Active debts together with their active items, for reporting.
  Future<List<DebtDetail>> getAllWithItems();
  Future<List<Debt>> getRecent({int limit = 5, DebtStatus? status});
  Future<Debt> create({
    required String customerId,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? notes,
    required List<DebtItemInput> items,
  });
  Future<Debt> update({
    required String debtId,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? notes,
    required List<DebtItemInput> items,
  });
  Future<Debt> addItems({
    required String debtId,
    required List<DebtItemInput> items,
  });

  Future<int> countActive();
  Future<int> outstandingBalanceCentavos();
}
