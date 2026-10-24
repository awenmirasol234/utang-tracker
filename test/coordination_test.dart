import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/presentation/providers/customer_providers.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/presentation/providers/debt_providers.dart';

void main() {
  test('restore invalidation refreshes customer and debt details', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final customers = CustomerRepositoryImpl(database);
    final debts = DebtRepositoryImpl(database);
    final customer = await customers.create(name: 'Original customer');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 10, 24),
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          unit: 'piece',
          price: Money.fromCentavos(10000),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    await container.read(customerDetailProvider(customer.id).future);
    await container.read(debtDetailProvider(debt.id).future);

    await customers.update(
      Customer(
        id: customer.id,
        name: 'Updated customer',
        phone: customer.phone,
        notes: customer.notes,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
      ),
    );
    await debts.update(
      debtId: debt.id,
      transactionDate: debt.transactionDate,
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          unit: 'piece',
          price: Money.fromCentavos(12000),
        ),
      ],
    );

    // restore path: bump the data version exactly like
    // notifyBusinessDataChangedFromRef does
    container.read(dataVersionProvider.notifier).bump();

    final customerDetail =
        await container.read(customerDetailProvider(customer.id).future);
    final debtDetail = await container.read(debtDetailProvider(debt.id).future);

    expect(customerDetail?.customer.name, 'Updated customer');
    expect(debtDetail?.detail.debt.totalAmount, Money.fromCentavos(12000));
  });
}
