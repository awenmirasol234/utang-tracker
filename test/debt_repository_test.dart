import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';
import 'package:utang_tracker/features/payments/data/repositories/payment_repository_impl.dart';

void main() {
  late AppDatabase appDatabase;
  late CustomerRepositoryImpl customers;
  late DebtRepositoryImpl debts;
  late PaymentRepositoryImpl payments;

  setUp(() {
    appDatabase = AppDatabase.forTesting();
    customers = CustomerRepositoryImpl(appDatabase);
    debts = DebtRepositoryImpl(appDatabase);
    payments = PaymentRepositoryImpl(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  Future<String> createPartialDebt() async {
    final customer = await customers.create(name: 'Maria');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Bigas',
          quantity: 2,
          unit: DebtItemUnits.kilogram,
          price: Money.fromPesoString('50'),
        ),
      ],
    );
    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesoString('20'),
      paymentDate: DateTime.now(),
      paymentMethod: 'Cash',
    );
    return debt.id;
  }

  test('adding items to a partially paid debt keeps payments and grows the balance', () async {
    final debtId = await createPartialDebt();

    final updated = await debts.addItems(
      debtId: debtId,
      items: [
        DebtItemInput(
          productName: 'Noodles',
          quantity: 3,
          price: Money.fromPesoString('10'),
        ),
      ],
    );

    expect(updated.totalAmount.centavos, 6000);
    expect(updated.paidAmount.centavos, 2000);
    expect(updated.balance.centavos, 4000);
    expect(updated.status, DebtStatus.partial);

    final detail = await debts.getById(debtId);
    expect(detail!.items.length, 2);
    expect(
      detail.items.map((item) => item.productName),
      ['Bigas', 'Noodles'],
    );

    final recordedPayments = await payments.getByDebt(debtId);
    expect(recordedPayments.length, 1);
    expect(recordedPayments.first.amount.centavos, 2000);
  });

  test('adding items to a fully paid debt is rejected', () async {
    final customer = await customers.create(name: 'Maria');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Bigas',
          quantity: 1,
          price: Money.fromPesoString('50'),
        ),
      ],
    );
    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesoString('50'),
      paymentDate: DateTime.now(),
      paymentMethod: 'Cash',
    );

    expect(
      () => debts.addItems(
        debtId: debt.id,
        items: [
          DebtItemInput(
            productName: 'Noodles',
            quantity: 1,
          price: Money.fromPesoString('10'),
          ),
        ],
      ),
      throwsA(isA<ConflictException>()),
    );
  });

  test('adding no items is rejected', () async {
    final debtId = await createPartialDebt();

    expect(
      () => debts.addItems(debtId: debtId, items: []),
      throwsA(isA<ValidationException>()),
    );
  });
}
