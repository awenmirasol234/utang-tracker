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

  test('create debt and record partial then full payment', () async {
    final customer = await customers.create(name: 'Maria');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Bigas',
          quantity: 2,
          unit: DebtItemUnits.kilogram,
          price: Money.fromPesos(50),
        ),
        DebtItemInput(
          productName: 'Noodles',
          quantity: 3,
          price: Money.fromPesos(10),
        ),
      ],
    );

    expect(debt.totalAmount.centavos, 6000);
    expect(debt.paidAmount.isZero, isTrue);
    expect(debt.balance.centavos, 6000);
    expect(debt.status, DebtStatus.unpaid);

    final createdDetail = await debts.getById(debt.id);
    expect(createdDetail!.items[0].unit, DebtItemUnits.kilogram);
    expect(createdDetail.items[1].unit, DebtItemUnits.piece);

    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(20),
      paymentDate: DateTime.now(),
      paymentMethod: 'Cash',
    );

    final partial = await debts.getById(debt.id);
    expect(partial!.debt.status, DebtStatus.partial);
    expect(partial.debt.paidAmount.centavos, 2000);
    expect(partial.debt.balance.centavos, 4000);

    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(40),
      paymentDate: DateTime.now(),
      paymentMethod: 'GCash',
    );

    final paid = await debts.getById(debt.id);
    expect(paid!.debt.status, DebtStatus.paid);
    expect(paid.debt.balance.isZero, isTrue);

    expect(
      () => payments.recordPayment(
        debtId: debt.id,
        amount: Money.fromPesos(1),
        paymentDate: DateTime.now(),
        paymentMethod: 'Cash',
      ),
      throwsA(isA<ConflictException>()),
    );
  });

  test('debt saves use the selected day and current save time', () async {
    var savedAt = DateTime(2026, 7, 19, 14, 25, 36);
    debts = DebtRepositoryImpl(appDatabase, now: () => savedAt);
    final customer = await customers.create(name: 'Timestamp debt');
    final dueDate = DateTime(2026, 5, 10);

    final created = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 5, 3),
      dueDate: dueDate,
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          price: Money.fromPesos(50),
        ),
      ],
    );

    expect(created.transactionDate, DateTime(2026, 5, 3, 14, 25, 36));
    expect(created.createdAt, savedAt);
    expect(created.updatedAt, savedAt);
    expect(created.dueDate, dueDate);

    savedAt = DateTime(2026, 7, 20, 9, 8, 7);
    final updated = await debts.update(
      debtId: created.id,
      transactionDate: DateTime(2026, 6, 4),
      dueDate: dueDate,
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          price: Money.fromPesos(60),
        ),
      ],
    );

    expect(updated.transactionDate, DateTime(2026, 6, 4, 9, 8, 7));
    expect(updated.createdAt, DateTime(2026, 7, 19, 14, 25, 36));
    expect(updated.updatedAt, savedAt);
    expect(updated.dueDate, dueDate);
  });

  test('payment saves use the selected day and current save time', () async {
    var savedAt = DateTime(2026, 7, 19, 10, 11, 12);
    debts = DebtRepositoryImpl(appDatabase, now: () => savedAt);
    payments = PaymentRepositoryImpl(appDatabase, now: () => savedAt);
    final customer = await customers.create(name: 'Timestamp payment');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 5, 3),
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          price: Money.fromPesos(50),
        ),
      ],
    );

    savedAt = DateTime(2026, 7, 20, 16, 17, 18);
    final payment = await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(20),
      paymentDate: DateTime(2026, 6, 8),
      paymentMethod: 'Cash',
    );

    expect(payment.paymentDate, DateTime(2026, 6, 8, 16, 17, 18));
    expect(payment.createdAt, savedAt);
    final updatedDebt = await debts.getById(debt.id);
    expect(updatedDebt!.debt.updatedAt, savedAt);
  });

  test('rejects overpayment', () async {
    final customer = await customers.create(name: 'Juan');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Soda',
          quantity: 1,
          price: Money.fromPesos(20),
        ),
      ],
    );

    expect(
      () => payments.recordPayment(
        debtId: debt.id,
        amount: Money.fromPesos(50),
        paymentDate: DateTime.now(),
        paymentMethod: 'Cash',
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('rejects zero and negative payment amounts in repository', () async {
    final customer = await customers.create(name: 'Invalid Amount');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Soda',
          quantity: 1,
          price: Money.fromPesos(20),
        ),
      ],
    );

    for (final amount in [Money.zero(), Money.fromCentavos(-1)]) {
      await expectLater(
        () => payments.recordPayment(
          debtId: debt.id,
          amount: amount,
          paymentDate: DateTime.now(),
          paymentMethod: 'Cash',
        ),
        throwsA(isA<ValidationException>()),
      );
    }

    expect(await payments.getByDebt(debt.id), isEmpty);
  });

  test('rejects empty payment method in repository', () async {
    final customer = await customers.create(name: 'Invalid Method');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Soda',
          quantity: 1,
          price: Money.fromPesos(20),
        ),
      ],
    );

    await expectLater(
      () => payments.recordPayment(
        debtId: debt.id,
        amount: Money.fromPesos(5),
        paymentDate: DateTime.now(),
        paymentMethod: '   ',
      ),
      throwsA(isA<ValidationException>()),
    );

    expect(await payments.getByDebt(debt.id), isEmpty);
  });

  test('paid history is hidden after customer deletion', () async {
    final customer = await customers.create(name: 'Archived customer');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          price: Money.fromPesos(10),
        ),
      ],
    );
    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(10),
      paymentDate: DateTime.now(),
      paymentMethod: 'Cash',
    );

    await customers.delete(customer.id);

    expect(await customers.getById(customer.id), isNull);
    expect(await debts.getById(debt.id), isNull);
    expect(await debts.getAll(), isEmpty);
    expect(await payments.getByDebt(debt.id), hasLength(1));
    expect(await payments.getAll(), isEmpty);
  });

  test('cannot delete customer with debts', () async {
    final customer = await customers.create(name: 'Ana');
    await debts.create(
      customerId: customer.id,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Item',
          quantity: 1,
          price: Money.fromPesos(10),
        ),
      ],
    );

    expect(
      () => customers.delete(customer.id),
      throwsA(isA<ConflictException>()),
    );
  });

  test('soft deletes customer and keeps row hidden from lists', () async {
    final customer = await customers.create(name: 'Pedro');
    await customers.delete(customer.id);

    final listed = await customers.getAll();
    expect(listed.where((customerEntry) => customerEntry.id == customer.id), isEmpty);
    expect(await customers.getById(customer.id), isNull);

    final row = await (appDatabase.select(
      appDatabase.customers,
    )..where((table) => table.id.equals(customer.id))).getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.deletedAt, isNotNull);
  });

  test('can delete customer with only paid debts', () async {
    final customer = await customers.create(name: 'Rosa');

    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Item',
          quantity: 1,
          price: Money.fromPesos(10),
        ),
      ],
    );

    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(10),
      paymentDate: DateTime.now(),
      paymentMethod: 'Cash',
    );

    await customers.delete(customer.id);

    final listed = await customers.getAll();
    expect(listed.where((customerEntry) => customerEntry.id == customer.id), isEmpty);
  });
}
