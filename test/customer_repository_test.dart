import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
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

  Future<String> createDebt(String customerId) async {
    final debt = await debts.create(
      customerId: customerId,
      transactionDate: DateTime.now(),
      items: [
        DebtItemInput(
          productName: 'Bigas',
          quantity: 1,
          price: Money.fromCentavos(5000),
        ),
      ],
    );
    return debt.id;
  }

  test('a customer name is required', () async {
    await expectLater(
      customers.create(name: '   '),
      throwsA(isA<ValidationException>()),
    );
  });

  test('names are unique among active customers regardless of case', () async {
    await customers.create(name: 'Maria Santos');

    await expectLater(
      customers.create(name: 'maria santos'),
      throwsA(isA<ConflictException>()),
    );
    await expectLater(
      customers.create(name: 'MARIA SANTOS'),
      throwsA(isA<ConflictException>()),
    );
  });

  test('updating a customer cannot take a name that is already taken', () async {
    final maria = await customers.create(name: 'Maria Santos');
    final juan = await customers.create(name: 'Juan Cruz');

    await expectLater(
      customers.update(
        Customer(
          id: juan.id,
          name: 'maria santos',
          createdAt: juan.createdAt,
          updatedAt: juan.updatedAt,
        ),
      ),
      throwsA(isA<ConflictException>()),
    );

    final updated = await customers.update(
      Customer(
        id: maria.id,
        name: 'Maria Santos-Reyes',
        createdAt: maria.createdAt,
        updatedAt: maria.updatedAt,
      ),
    );
    expect(updated.name, 'Maria Santos-Reyes');
  });

  test('a soft-deleted name can be reused', () async {
    final maria = await customers.create(name: 'Maria Santos');
    await customers.delete(maria.id);

    final recreated = await customers.create(name: 'Maria Santos');
    expect(recreated.name, 'Maria Santos');
  });

  test('soft-deleted customers are hidden from lists, search and counts', () async {
    final maria = await customers.create(name: 'Maria Santos');
    await customers.create(name: 'Juan Cruz');
    await customers.delete(maria.id);

    final all = await customers.getAll();
    expect(all.map((customer) => customer.name), ['Juan Cruz']);
    expect(await customers.search('Maria'), isEmpty);
    expect(await customers.count(), 1);
    expect(await customers.getById(maria.id), isNull);
  });

  test('a customer with an unpaid debt cannot be deleted', () async {
    final maria = await customers.create(name: 'Maria Santos');
    await createDebt(maria.id);

    expect(await customers.hasDebts(maria.id), isTrue);
    await expectLater(
      customers.delete(maria.id),
      throwsA(isA<ConflictException>()),
    );
  });

  test('a customer can be deleted once every debt is fully paid', () async {
    final maria = await customers.create(name: 'Maria Santos');
    final debtId = await createDebt(maria.id);

    await payments.recordPayment(
      debtId: debtId,
      amount: Money.fromPesos(50),
      paymentDate: DateTime.now(),
      paymentMethod: 'Cash',
    );

    expect(await customers.hasDebts(maria.id), isFalse);
    await customers.delete(maria.id);
    expect(await customers.getById(maria.id), isNull);
  });
}
