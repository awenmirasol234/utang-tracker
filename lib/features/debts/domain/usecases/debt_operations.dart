import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';

class DebtOperations {
  const DebtOperations(this._repository);

  final DebtRepository _repository;

  Future<List<Debt>> getAll({DebtStatus? status}) {
    return _repository.getAll(status: status);
  }

  Future<DebtDetail?> getById(String debtId) => _repository.getById(debtId);

  Future<Debt> create({
    required String customerId,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? notes,
    required List<DebtItemInput> items,
  }) {
    return _repository.create(
      customerId: customerId,
      transactionDate: transactionDate,
      dueDate: dueDate,
      notes: notes,
      items: items,
    );
  }

  Future<Debt> update({
    required String debtId,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? notes,
    required List<DebtItemInput> items,
  }) {
    return _repository.update(
      debtId: debtId,
      transactionDate: transactionDate,
      dueDate: dueDate,
      notes: notes,
      items: items,
    );
  }

  Future<Debt> addItems({
    required String debtId,
    required List<DebtItemInput> items,
  }) {
    return _repository.addItems(debtId: debtId, items: items);
  }
}
