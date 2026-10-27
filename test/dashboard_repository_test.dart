import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:utang_tracker/features/dashboard/domain/entities/recent_activity_item.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/payments/data/repositories/payment_repository_impl.dart';

void main() {
  late AppDatabase appDatabase;
  late CustomerRepositoryImpl customers;
  late DebtRepositoryImpl debts;
  late PaymentRepositoryImpl payments;
  late DateTime clock;

  DateTime now() => clock;

  setUp(() {
    appDatabase = AppDatabase.forTesting();
    clock = DateTime(2026, 3, 10, 9);
    customers = CustomerRepositoryImpl(appDatabase, now: now);
    debts = DebtRepositoryImpl(appDatabase, now: now);
    payments = PaymentRepositoryImpl(appDatabase, now: now);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  DashboardRepositoryImpl dashboard() {
    return DashboardRepositoryImpl(customers, debts, payments, now: now);
  }

  Future<Debt> createDebt(String customerId, String price) {
    return debts.create(
      customerId: customerId,
      transactionDate: clock,
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          price: Money.fromPesoString(price),
        ),
      ],
    );
  }

  test('reports an empty ledger', () async {
    final summary = await dashboard().getDashboardData();

    expect(summary.outstandingBalance, Money.zero());
    expect(summary.collectedToday, Money.zero());
    expect(summary.activeDebtsCount, 0);
    expect(summary.totalCustomers, 0);
    expect(summary.recentActivity, isEmpty);
  });

  test('counts only unpaid debts in the outstanding balance', () async {
    final customer = await customers.create(name: 'Maria');
    await createDebt(customer.id, '50');
    final paidDebt = await createDebt(customer.id, '30');
    await payments.recordPayment(
      debtId: paidDebt.id,
      amount: Money.fromPesoString('30'),
      paymentDate: clock,
      paymentMethod: 'Cash',
    );

    final summary = await dashboard().getDashboardData();

    expect(summary.outstandingBalance, Money.fromPesoString('50'));
    expect(summary.activeDebtsCount, 1);
    expect(summary.totalCustomers, 1);
  });

  test('collects only payments dated today', () async {
    final customer = await customers.create(name: 'Maria');
    final debt = await createDebt(customer.id, '100');
    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesoString('10'),
      paymentDate: DateTime(2026, 3, 9, 23, 59),
      paymentMethod: 'Cash',
    );
    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesoString('20'),
      paymentDate: DateTime(2026, 3, 10),
      paymentMethod: 'Cash',
    );
    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesoString('40'),
      paymentDate: DateTime(2026, 3, 11),
      paymentMethod: 'Cash',
    );

    final summary = await dashboard().getDashboardData();

    expect(summary.collectedToday, Money.fromPesoString('20'));
  });

  test('recent activity merges debts and payments newest first', () async {
    final customer = await customers.create(name: 'Maria');
    await createDebt(customer.id, '10');
    clock = clock.add(const Duration(minutes: 1));
    final paidDebt = await createDebt(customer.id, '20');
    clock = clock.add(const Duration(minutes: 1));
    await payments.recordPayment(
      debtId: paidDebt.id,
      amount: Money.fromPesoString('5'),
      paymentDate: clock,
      paymentMethod: 'Cash',
    );

    final summary = await dashboard().getDashboardData();

    expect(summary.recentActivity.map((item) => item.type), [
      RecentActivityType.payment,
      RecentActivityType.debt,
      RecentActivityType.debt,
    ]);
  });

  test('recent activity keeps the five newest entries', () async {
    final customer = await customers.create(name: 'Maria');
    final firstDebt = await createDebt(customer.id, '10');
    for (var index = 0; index < 5; index++) {
      clock = clock.add(const Duration(minutes: 1));
      await createDebt(customer.id, '10');
    }

    final summary = await dashboard().getDashboardData();

    expect(summary.recentActivity, hasLength(5));
    expect(
      summary.recentActivity.map((item) => item.id),
      isNot(contains(firstDebt.id)),
    );
  });
}
