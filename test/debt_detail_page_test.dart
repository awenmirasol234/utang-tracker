import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/core/widgets/app_text_field.dart';
import 'package:utang_tracker/core/widgets/money_text.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';
import 'package:utang_tracker/features/debts/presentation/pages/debt_detail_page.dart';
import 'package:utang_tracker/features/payments/data/repositories/payment_repository_impl.dart';

void main() {
  testWidgets('items card shows aligned subtotals and a separated total', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final customers = CustomerRepositoryImpl(database);
    final debts = DebtRepositoryImpl(database);
    final customer = await customers.create(name: 'Maria Santos');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 7, 15, 14, 5),
      items: [
        DebtItemInput(
          productName: 'Softdrinks',
          quantity: 2,
          unit: DebtItemUnits.bottle,
          price: Money.fromPesos(50),
        ),
        DebtItemInput(
          productName: 'Candy',
          quantity: 2,
          unit: DebtItemUnits.piece,
          price: Money.fromPesos(20),
        ),
        DebtItemInput(
          productName: 'Premium long-grain rice refill',
          quantity: 0.5,
          unit: DebtItemUnits.kilogram,
          price: Money.fromPesos(80.25),
        ),
      ],
    );
    final detail = await debts.getById(debt.id);
    final softdrinks = detail!.items.singleWhere(
      (item) => item.productName == 'Softdrinks',
    );
    final rice = detail.items.singleWhere(
      (item) => item.productName == 'Premium long-grain rice refill',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: DebtDetailPage(debtId: debt.id)),
      ),
    );
    await tester.pumpAndSettle();

    final transactionDate = find.text(
      DateFormatters.smartTimestamp(
        debt.transactionDate,
        relativeTo: DateTime.now(),
        locale: 'en-US',
        use24HourFormat: false,
      ),
    );
    expect(transactionDate, findsOneWidget);
    expect(
      tester.widget<Text>(transactionDate).style?.fontWeight,
      FontWeight.w600,
    );
    expect(find.text('Items (3)'), findsOneWidget);
    expect(find.byKey(const Key('debt-note-label')), findsNothing);
    expect(find.byKey(const Key('debt-note-text')), findsNothing);
    expect(find.byKey(const Key('debt-items-card')), findsOneWidget);
    expect(find.text('Softdrinks'), findsOneWidget);
    expect(find.text('2 bottles'), findsOneWidget);
    expect(find.text('Candy'), findsOneWidget);
    expect(find.text('2 pieces'), findsOneWidget);
    expect(find.text('Premium long-grain rice refill'), findsOneWidget);
    expect(find.text('0.5 kg'), findsOneWidget);
    expect(find.byKey(const Key('debt-items-total-row')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('debt-items-total-row')),
        matching: find.text('Total'),
      ),
      findsOneWidget,
    );

    final softdrinksAmount = find.byKey(
      ValueKey('debt-item-subtotal-${softdrinks.id}'),
    );
    final riceAmount = find.byKey(ValueKey('debt-item-subtotal-${rice.id}'));
    final totalAmount = find.byKey(const Key('debt-items-total-amount'));
    final softdrinksNameFinder = find.byKey(
      ValueKey('debt-item-name-${softdrinks.id}'),
    );
    final softdrinksMetaFinder = find.byKey(
      ValueKey('debt-item-meta-${softdrinks.id}'),
    );
    final softdrinksName = tester.widget<Text>(softdrinksNameFinder);
    final softdrinksMeta = tester.widget<Text>(softdrinksMetaFinder);
    final textTheme = Theme.of(tester.element(softdrinksNameFinder)).textTheme;
    final softdrinksSubtotal = tester.widget<MoneyText>(softdrinksAmount);
    final itemsTotal = tester.widget<MoneyText>(totalAmount);

    expect(softdrinksMeta.style?.color, AppColors.textSecondary);
    expect(softdrinksName.style?.fontSize, textTheme.bodyMedium!.fontSize);
    expect(softdrinksMeta.style?.fontSize, textTheme.bodySmall!.fontSize);
    expect(softdrinksMeta.style?.fontWeight, FontWeight.w500);
    expect(softdrinksSubtotal.style?.fontSize, textTheme.bodyLarge!.fontSize);
    expect(itemsTotal.style, isNull);
    expect(find.text(softdrinks.price.format()), findsOneWidget);
    expect(find.text(rice.price.format()), findsOneWidget);
    expect(
      find.descendant(
        of: totalAmount,
        matching: find.text(debt.totalAmount.format()),
      ),
      findsOneWidget,
    );

    final rightEdges = [
      tester.getTopRight(softdrinksAmount).dx,
      tester.getTopRight(riceAmount).dx,
      tester.getTopRight(totalAmount).dx,
    ];
    for (final edge in rightEdges.skip(1)) {
      expect(edge, closeTo(rightEdges.first, 0.01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('note section shows its label and content when notes exist', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final customers = CustomerRepositoryImpl(database);
    final debts = DebtRepositoryImpl(database);
    final customer = await customers.create(name: 'Maria Santos');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 7, 15, 14, 5),
      notes: 'Deliver on Friday.',
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          unit: DebtItemUnits.kilogram,
          price: Money.fromPesos(80),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: DebtDetailPage(debtId: debt.id)),
      ),
    );
    await tester.pumpAndSettle();

    final noteLabel = tester.widget<Text>(
      find.byKey(const Key('debt-note-label')),
    );
    final noteText = tester.widget<Text>(
      find.byKey(const Key('debt-note-text')),
    );

    expect(noteLabel.data, 'Note');
    expect(noteText.data, 'Deliver on Friday.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial debt can append an item without touching payments', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final customers = CustomerRepositoryImpl(database);
    final debts = DebtRepositoryImpl(database);
    final payments = PaymentRepositoryImpl(database);
    final customer = await customers.create(name: 'Maria Santos');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 7, 15, 14, 5),
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          unit: DebtItemUnits.kilogram,
          price: Money.fromPesos(80),
        ),
      ],
    );
    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(30),
      paymentDate: DateTime(2026, 7, 16),
      paymentMethod: 'Cash',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: DebtDetailPage(debtId: debt.id)),
      ),
    );
    await tester.pumpAndSettle();

    final addItemButton = find.byKey(const Key('add-debt-item-button'));
    expect(addItemButton, findsOneWidget);

    await tester.ensureVisible(addItemButton);
    await tester.pumpAndSettle();
    await tester.tap(addItemButton);
    await tester.pumpAndSettle();

    final productField = find.byWidgetPredicate(
      (widget) => widget is AppTextField && widget.label == 'Product *',
    );
    final priceField = find.byWidgetPredicate(
      (widget) => widget is AppTextField && widget.label == 'Price *',
    );

    await tester.enterText(
      find.descendant(of: productField, matching: find.byType(TextField)),
      'Coke',
    );
    await tester.enterText(
      find.descendant(of: priceField, matching: find.byType(TextField)),
      '20',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('New balance: ₱70.00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('debt-items-card')));
    await tester.pumpAndSettle();

    expect(find.text('Items (2)'), findsOneWidget);
    expect(find.text('Coke'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('debt-items-total-amount')),
        matching: find.text('₱100.00'),
      ),
      findsOneWidget,
    );
    expect(find.text('₱70.00'), findsOneWidget);

    final detail = await debts.getById(debt.id);
    expect(detail!.items.length, 2);
    expect(detail.debt.totalAmount.centavos, 10000);
    expect(detail.debt.paidAmount.centavos, 3000);
    expect(detail.debt.balance.centavos, 7000);
    expect((await payments.getByDebt(debt.id)).length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fully paid debt does not offer adding items', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final customers = CustomerRepositoryImpl(database);
    final debts = DebtRepositoryImpl(database);
    final payments = PaymentRepositoryImpl(database);
    final customer = await customers.create(name: 'Maria Santos');
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 7, 15, 14, 5),
      items: [
        DebtItemInput(
          productName: 'Rice',
          quantity: 1,
          price: Money.fromPesos(80),
        ),
      ],
    );
    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(80),
      paymentDate: DateTime(2026, 7, 16),
      paymentMethod: 'Cash',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: DebtDetailPage(debtId: debt.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-debt-item-button')), findsNothing);
  });
}
