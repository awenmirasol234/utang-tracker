import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_theme.dart';
import 'package:utang_tracker/core/widgets/app_modal_bottom_sheet.dart';
import 'package:utang_tracker/core/widgets/app_text_field.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/customers/presentation/pages/customer_form_page.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';
import 'package:utang_tracker/features/debts/presentation/pages/debt_form_page.dart';

void main() {
  testWidgets(
    'adding item via bottom sheet shows in list with correct subtotal and quantity/unit grammar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: AppTheme.light(), home: const DebtFormPage()),
        ),
      );

      final transactionDate = find.text('Today');
      expect(transactionDate, findsOneWidget);
      expect(
        tester.widget<Text>(transactionDate).style?.fontWeight,
        FontWeight.w500,
      );
      expect(
        tester.widget<Text>(find.text('Select customer')).style?.fontWeight,
        FontWeight.w500,
      );

      expect(find.text('No items'), findsOneWidget);
      final headerAddItem = find.widgetWithText(TextButton, 'Add item');
      expect(headerAddItem, findsOneWidget);

      await tester.tap(headerAddItem);
      await tester.pumpAndSettle();

      expect(find.byType(AppModalBottomSheet), findsOneWidget);

      expect(
        find.descendant(
          of: find.byType(AppModalBottomSheet),
          matching: find.byWidgetPredicate(
            (widget) => widget is AppTextField && widget.label == 'Product *',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppModalBottomSheet),
          matching: find.byWidgetPredicate(
            (widget) => widget is AppTextField && widget.label == 'Quantity *',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byType(AppModalBottomSheet),
          matching: find.byWidgetPredicate(
            (widget) => widget is AppTextField && widget.label == 'Price *',
          ),
        ),
        findsOneWidget,
      );

      expect(find.text('piece'), findsOneWidget);

      final productField = find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Product *',
      );
      final quantityField = find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Quantity *',
      );
      final priceField = find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Price *',
      );

      await tester.enterText(
        find.descendant(of: productField, matching: find.byType(TextField)),
        'Bugas',
      );
      await tester.enterText(
        find.descendant(of: quantityField, matching: find.byType(TextField)),
        '2',
      );
      await tester.enterText(
        find.descendant(of: priceField, matching: find.byType(TextField)),
        '75.50',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Bugas'), findsOneWidget);
      expect(find.text('2 pieces'), findsOneWidget);

      expect(find.text(Money.fromPesos(75.50).format()), findsWidgets);
      expect(find.text('No items'), findsNothing);

      expect(find.text(Money.fromPesos(75.50).format()), findsNWidgets(2));

      await tester.tap(find.widgetWithText(TextButton, 'Add item'));
      await tester.pumpAndSettle();

      expect(find.byType(AppModalBottomSheet), findsOneWidget);

      final productField2 = find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Product *',
      );
      final quantityField2 = find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Quantity *',
      );
      final priceField2 = find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Price *',
      );

      await tester.enterText(
        find.descendant(of: productField2, matching: find.byType(TextField)),
        'Kape',
      );
      await tester.enterText(
        find.descendant(of: quantityField2, matching: find.byType(TextField)),
        '1',
      );

      final pieceInSheet = find.descendant(
        of: find.byType(AppModalBottomSheet),
        matching: find.text('piece'),
      );
      expect(pieceInSheet, findsOneWidget);
      await tester.ensureVisible(pieceInSheet);
      final pieceInkWell = find.ancestor(
        of: pieceInSheet,
        matching: find.byType(InkWell),
      );
      await tester.tap(pieceInkWell.first);
      await tester.pumpAndSettle();

      expect(find.text('Select unit'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('sachet'),
        100,
        scrollable: find.descendant(
          of: find.byKey(const Key('app-modal-bottom-sheet')),
          matching: find.byType(Scrollable),
        ).last,
      );
      await tester.tap(find.text('sachet'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(of: priceField2, matching: find.byType(TextField)),
        '12.00',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Bugas'), findsOneWidget);
      expect(find.text('Kape'), findsOneWidget);
      expect(find.text('1 sachet'), findsOneWidget);
      expect(find.text(Money.fromPesos(12.00).format()), findsOneWidget);

      expect(find.text(Money.fromPesos(87.50).format()), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('custom unit dialog stays compact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const DebtFormPage()),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();

    expect(find.byType(AppModalBottomSheet), findsOneWidget);
    expect(find.text('Add item'), findsWidgets);

    final unit = find.text(DebtItemUnits.displayName(DebtItemUnits.piece));
    expect(unit, findsOneWidget);
    await tester.ensureVisible(unit);

    final unitInkWell = find.ancestor(
      of: unit,
      matching: find.byType(InkWell),
    );
    expect(unitInkWell, findsWidgets);
    await tester.tap(unitInkWell.first);
    await tester.pumpAndSettle();

    expect(find.text('Select unit'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Custom unit'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('app-modal-bottom-sheet')),
        matching: find.byType(Scrollable),
      ).last,
    );
    expect(find.text('Custom unit'), findsOneWidget);
    await tester.tap(find.text('Custom unit'));
    await tester.pumpAndSettle();

    final dialog = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate(
        (candidateWidget) => candidateWidget is Material && candidateWidget.type == MaterialType.card,
      ),
    );
    final dialogSize = tester.getSize(dialog);
    expect(dialogSize.width, lessThanOrEqualTo(360));
    expect(dialogSize.height, lessThanOrEqualTo(260));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding items appends to list without collapsing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const DebtFormPage()),
      ),
    );

    expect(find.text('No items'), findsOneWidget);
    expect(find.text('Bugas'), findsNothing);

    expect(find.byWidgetPredicate((candidateWidget) {
      if (candidateWidget is Text) {
        return candidateWidget.data != null && candidateWidget.data!.contains('Items');
      }
      if (candidateWidget is TextSpan) return false;

      return false;
    }), findsNothing);

    expect(find.textContaining('Items'), findsOneWidget);

    final addItem = find.widgetWithText(TextButton, 'Add item');
    expect(addItem, findsOneWidget);
    await tester.tap(addItem);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is AppTextField && widget.label == 'Product *'),
        matching: find.byType(TextField),
      ),
      'Bugas',
    );
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is AppTextField && widget.label == 'Quantity *'),
        matching: find.byType(TextField),
      ),
      '2',
    );
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is AppTextField && widget.label == 'Price *'),
        matching: find.byType(TextField),
      ),
      '10.00',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('No items'), findsNothing);
    expect(find.text('Bugas'), findsOneWidget);
    expect(find.text('2 pieces'), findsOneWidget);

    expect(find.textContaining('No product yet'), findsNothing);
    expect(find.textContaining('collapsedSummary'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is AppTextField && widget.label == 'Product *'),
        matching: find.byType(TextField),
      ),
      'Kape',
    );
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is AppTextField && widget.label == 'Quantity *'),
        matching: find.byType(TextField),
      ),
      '1',
    );
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is AppTextField && widget.label == 'Price *'),
        matching: find.byType(TextField),
      ),
      '5.00',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Bugas'), findsOneWidget);
    expect(find.text('Kape'), findsOneWidget);
    expect(find.textContaining('Items'), findsOneWidget);
    expect(find.textContaining('No product yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('required debt fields show and clear inline errors', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final customers = CustomerRepositoryImpl(database);
    final testCustomer = await customers.create(name: 'Test Customer');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(theme: AppTheme.light(), home: const DebtFormPage()),
      ),
    );

    expect(testCustomer.name, 'Test Customer');

    expect(find.text('No items'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Add item'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.textContaining('Items'), findsOneWidget);

    final save = find.text('Save');
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(save, 500, scrollable: scrollable);
    await tester.tap(save);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Select customer'),
      -500,
      scrollable: scrollable,
    );
    expect(find.text('Select a customer.'), findsOneWidget);

    expect(find.text('Add at least one item'), findsNothing);

    final customerDecorator = find.ancestor(
      of: find.text('Select customer'),
      matching: find.byType(InputDecorator),
    );
    expect(
      tester.widget<InputDecorator>(customerDecorator).decoration.errorText,
      'Select a customer.',
    );

    await tester.tap(find.text('Select customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(testCustomer.name));
    await tester.pumpAndSettle();
    expect(find.text(testCustomer.name), findsOneWidget);

    await tester.scrollUntilVisible(save, 500, scrollable: scrollable);
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Add at least one item'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();

    expect(find.byType(AppModalBottomSheet), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    final productFields = find.byWidgetPredicate(
      (widget) => widget is AppTextField && widget.label == 'Product *',
    );
    final firstProductInput = find
        .descendant(of: productFields, matching: find.byType(TextField))
        .first;
    expect(
      tester.widget<TextField>(firstProductInput).decoration?.errorText,
      'Product name is required.',
    );

    await tester.enterText(firstProductInput, 'Rice');
    await tester.pump();
    expect(
      tester.widget<TextField>(firstProductInput).decoration?.errorText,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer picker check follows the selected customer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final customers = CustomerRepositoryImpl(database);
    final maria = await customers.create(name: 'Maria Santos');
    await customers.create(name: 'Juan Cruz');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: DebtFormPage(initialCustomerId: maria.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maria Santos'));
    await tester.pumpAndSettle();

    Finder customerTile(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(ListTile));
    Finder checkIn(Finder tile) =>
        find.descendant(of: tile, matching: find.byIcon(Icons.check));

    final mariaTile = customerTile('Maria Santos');
    final juanTile = customerTile('Juan Cruz');
    final mariaCheck = checkIn(mariaTile);

    expect(mariaTile, findsOneWidget);
    expect(juanTile, findsOneWidget);
    expect(mariaCheck, findsOneWidget);
    expect(checkIn(juanTile), findsNothing);
    expect(tester.widget<Icon>(mariaCheck).color, AppColors.primaryDark);

    await tester.tap(juanTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juan Cruz'));
    await tester.pumpAndSettle();

    final reopenedMariaTile = customerTile('Maria Santos');
    final reopenedJuanTile = customerTile('Juan Cruz');
    final juanCheck = checkIn(reopenedJuanTile);

    expect(checkIn(reopenedMariaTile), findsNothing);
    expect(juanCheck, findsOneWidget);
    expect(tester.widget<Icon>(juanCheck).color, AppColors.primaryDark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer added from the picker is selected automatically', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DebtFormPage()),
        GoRoute(
          path: '/customers/new',
          builder: (_, _) => const CustomerFormPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select customer'));
    await tester.pumpAndSettle();
    expect(find.byType(AppModalBottomSheet), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Add customer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is AppTextField && widget.label == 'Name *',
        ),
        matching: find.byType(TextField),
      ),
      'Bela',
    );

    final saveButton = find.widgetWithText(ElevatedButton, 'Add customer');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.byType(AppModalBottomSheet), findsNothing);
    expect(find.text('Bela'), findsOneWidget);
    expect(find.text('Select customer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmation dialog hides notes when empty and shows them when set', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final customers = CustomerRepositoryImpl(database);
    final customer = await customers.create(name: 'Test Customer');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: DebtFormPage(initialCustomerId: customer.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is AppTextField && widget.label == 'Product *',
        ),
        matching: find.byType(TextField),
      ),
      'Rice',
    );
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is AppTextField && widget.label == 'Quantity *',
        ),
        matching: find.byType(TextField),
      ),
      '1',
    );
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is AppTextField && widget.label == 'Price *',
        ),
        matching: find.byType(TextField),
      ),
      '10.00',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm debt?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Notes'),
      ),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('Add note'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is AppTextField &&
              widget.hint == 'Add any details (optional)',
        ),
        matching: find.byType(TextField),
      ),
      'Deliver on Friday',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Notes'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Deliver on Friday'),
      ),
      findsOneWidget,
    );
  });
}
