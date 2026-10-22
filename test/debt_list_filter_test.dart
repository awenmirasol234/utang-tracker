import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';
import 'package:utang_tracker/features/debts/presentation/providers/debt_providers.dart';

void main() {
  test(
    'overdue filter keeps only active debts due before local today',
    () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));
      final container = ProviderContainer(
        overrides: [
          debtRepositoryProvider.overrideWithValue(
            _FakeDebtRepository([
              _debt('overdue-unpaid', dueDate: yesterday),
              _debt(
                'overdue-partial',
                dueDate: yesterday,
                status: DebtStatus.partial,
              ),
              _debt(
                'paid',
                dueDate: yesterday,
                status: DebtStatus.paid,
                balance: Money.zero(),
              ),
              _debt('today', dueDate: today),
              _debt('future', dueDate: tomorrow),
              _debt('no-date'),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(debtStatusFilterProvider.notifier)
          .setFilter(DebtListFilter.overdue);

      final debts = await container.read(debtsListProvider.future);

      expect(debts.map((debt) => debt.id), [
        'overdue-unpaid',
        'overdue-partial',
      ]);
    },
  );
}

Debt _debt(
  String debtId, {
  DateTime? dueDate,
  DebtStatus status = DebtStatus.unpaid,
  Money? balance,
}) {
  final date = DateTime(2026, 7, 1);
  return Debt(
    id: debtId,
    customerId: 'customer-$debtId',
    totalAmount: Money.fromPesos(100),
    paidAmount: Money.zero(),
    balance: balance ?? Money.fromPesos(100),
    status: status,
    transactionDate: date,
    dueDate: dueDate,
    createdAt: date,
    updatedAt: date,
  );
}

class _FakeDebtRepository implements DebtRepository {
  const _FakeDebtRepository(this.debts);

  final List<Debt> debts;

  @override
  Future<List<Debt>> getAll({DebtStatus? status}) async => status == null
      ? debts
      : debts.where((debt) => debt.status == status).toList(growable: false);

  @override
  Future<List<Debt>> getByCustomer(String customerId) async =>
      throw UnimplementedError();

  @override
  Future<DebtDetail?> getById(String debtId) async => throw UnimplementedError();

  @override
  Future<List<Debt>> getRecent({int limit = 5, DebtStatus? status}) async =>
      throw UnimplementedError();

  @override
  Future<Debt> create({
    required String customerId,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? notes,
    required List<DebtItemInput> items,
  }) async => throw UnimplementedError();

  @override
  Future<Debt> update({
    required String debtId,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? notes,
    required List<DebtItemInput> items,
  }) async => throw UnimplementedError();

  @override
  Future<Debt> addItems({
    required String debtId,
    required List<DebtItemInput> items,
  }) async => throw UnimplementedError();

  @override
  Future<int> countActive() async => throw UnimplementedError();

  @override
  Future<int> outstandingBalanceCentavos() async => throw UnimplementedError();
}
