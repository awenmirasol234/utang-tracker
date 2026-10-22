import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_theme.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/core/widgets/status_badge.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/customers/presentation/pages/customer_detail_page.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/payments/data/repositories/payment_repository_impl.dart';

void main() {
  testWidgets('debt and payment histories switch between tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final customers = CustomerRepositoryImpl(database);
    final debts = DebtRepositoryImpl(database);
    final payments = PaymentRepositoryImpl(database);
    final customer = await customers.create(name: 'Maria Santos');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 7, 14, 9, 30),
      items: [
        DebtItemInput(
          productName: 'Groceries',
          quantity: 1,
          price: Money.fromPesos(200),
        ),
      ],
    );
    final payment = await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(50),
      paymentDate: DateTime(2026, 7, 15, 14, 5),
      paymentMethod: 'Cash',
    );
    final currentDebt = (await debts.getById(debt.id))!.debt;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CustomerDetailPage(customerId: customer.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Debts'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.indicator, isNull);
    expect(tabBar.labelColor, isNull);
    expect(tabBar.unselectedLabelColor, isNull);
    expect(find.byKey(const PageStorageKey('debt-history')), findsOneWidget);
    expect(find.byKey(const PageStorageKey('payment-history')), findsNothing);
    expect(find.text('Cash'), findsNothing);

    final debtTimestamp = find.text(
      DateFormatters.smartTimestamp(
        debt.transactionDate,
        relativeTo: DateTime.now(),
        locale: 'en-US',
        use24HourFormat: false,
      ),
    );
    final status = find.text('Partial');
    final statusBadge = find.byType(StatusBadge);
    final debtAmount = find.descendant(
      of: find.byKey(const PageStorageKey('debt-history')),
      matching: find.text(currentDebt.balance.format()),
    );
    expect(debtTimestamp, findsOneWidget);
    expect(
      tester.widget<Text>(debtTimestamp).style?.fontWeight,
      FontWeight.w500,
    );
    expect(status, findsOneWidget);
    expect(statusBadge, findsOneWidget);
    expect(debtAmount, findsOneWidget);
    expect(
      tester.getTopLeft(debtAmount).dy,
      greaterThan(tester.getTopLeft(status).dy),
    );
    expect(
      tester.getTopRight(debtAmount).dx,
      closeTo(tester.getTopRight(statusBadge).dx, 1),
    );

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();

    expect(find.byKey(const PageStorageKey('debt-history')), findsNothing);
    expect(find.byKey(const PageStorageKey('payment-history')), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);

    final paymentTimestamp = find.text(
      DateFormatters.smartTimestamp(
        payment.paymentDate,
        relativeTo: DateTime.now(),
        locale: 'en-US',
        use24HourFormat: false,
      ),
    );
    final paymentAmount = find.text(payment.amount.format());
    final paymentType = find.text(payment.paymentMethod);
    expect(paymentTimestamp, findsOneWidget);
    expect(
      tester.widget<Text>(paymentTimestamp).style?.fontWeight,
      FontWeight.w500,
    );
    expect(paymentAmount, findsOneWidget);
    expect(paymentType, findsOneWidget);
    final paymentTypeStyle = tester.widget<Text>(paymentType).style;
    expect(paymentTypeStyle?.fontSize, 12);
    expect(paymentTypeStyle?.fontWeight, FontWeight.w500);
    expect(
      tester.getTopLeft(paymentType).dy,
      greaterThan(tester.getTopLeft(paymentAmount).dy),
    );
    expect(
      tester.getTopRight(paymentType).dx,
      closeTo(tester.getTopRight(paymentAmount).dx, 1),
    );
    expect(tester.takeException(), isNull);
  });
}
