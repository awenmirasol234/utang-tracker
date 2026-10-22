import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/core/utils/local_date_time.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';
import 'package:utang_tracker/features/payments/presentation/pages/payments_list_page.dart';
import 'package:utang_tracker/features/payments/presentation/providers/payment_providers.dart';

void main() {
  testWidgets('smart payment timestamp appears beside payment method', (
    tester,
  ) async {
    final paymentDate = DateTime(2026, 7, 15, 14, 5);
    final payment = _payment(
      id: 'payment-id',
      debtId: 'debt-id',
      amount: 125,
      paymentDate: paymentDate,
      paymentMethod: 'Cash',
      customerName: 'Maria Santos',
    );

    await _pumpPage(tester, [payment]);

    final timestamp = find.text(
      DateFormatters.smartTimestamp(
        paymentDate,
        relativeTo: DateTime.now(),
        locale: 'en-US',
        use24HourFormat: false,
      ),
    );
    final method = find.descendant(
      of: find.byType(AppCard),
      matching: find.text('Cash'),
    );
    final amount = find.text(payment.amount.format());

    expect(timestamp, findsOneWidget);
    expect(method, findsOneWidget);
    expect(tester.widget<Text>(timestamp).style?.fontWeight, FontWeight.w500);
    expect(tester.widget<Text>(method).style?.fontWeight, FontWeight.w500);
    expect(amount, findsOneWidget);
    expect(
      tester.getTopLeft(method).dy,
      greaterThan(tester.getTopLeft(amount).dy),
    );
    expect(
      tester.getTopLeft(method).dy,
      closeTo(tester.getTopLeft(timestamp).dy, 2),
    );
    expect(
      tester.getTopRight(method).dx,
      closeTo(tester.getTopRight(amount).dx, 1),
    );
  });

  testWidgets('filters payments by customer search', (tester) async {
    await _pumpPage(tester, [
      _payment(id: '1', customerName: 'Maria Santos'),
      _payment(id: '2', customerName: 'Juan Cruz'),
    ]);

    await tester.enterText(find.byType(TextField), 'maria');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Juan Cruz'), findsNothing);
  });

  testWidgets('filters payments by method chip', (tester) async {
    await _pumpPage(tester, [
      _payment(id: '1', paymentMethod: 'Cash', customerName: 'Maria Santos'),
      _payment(id: '2', paymentMethod: 'GCash', customerName: 'Juan Cruz'),
    ]);

    await tester.tap(find.widgetWithText(FilterChip, 'GCash'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Santos'), findsNothing);
    expect(find.text('Juan Cruz'), findsOneWidget);
  });

  testWidgets('filters payments by selected date range', (tester) async {
    final container = await _pumpPage(tester, [
      _payment(
        id: '1',
        paymentDate: DateTime(2026, 7, 15, 9),
        customerName: 'Maria Santos',
      ),
      _payment(
        id: '2',
        paymentDate: DateTime(2026, 7, 16, 9),
        customerName: 'Juan Cruz',
      ),
    ]);

    container
        .read(paymentFiltersProvider.notifier)
        .setDateRange(
          startDate: DateTime(2026, 7, 16),
          endDate: DateTime(2026, 7, 16),
        );
    await tester.pumpAndSettle();

    expect(find.text('Maria Santos'), findsNothing);
    expect(find.text('Juan Cruz'), findsOneWidget);
  });

  testWidgets('date range compares stored UTC payments by local day', (
    tester,
  ) async {
    final paymentDate = DateTime.utc(2026, 7, 15, 23, 30);
    final localDay = startOfLocalDay(paymentDate);
    final utcDay = DateTime(
      paymentDate.year,
      paymentDate.month,
      paymentDate.day,
    );
    final container = await _pumpPage(tester, [
      _payment(
        id: 'utc-payment',
        paymentDate: paymentDate,
        customerName: 'UTC Payment',
      ),
    ]);

    container
        .read(paymentFiltersProvider.notifier)
        .setDateRange(startDate: localDay, endDate: localDay);
    await tester.pumpAndSettle();

    expect(find.text('UTC Payment'), findsOneWidget);

    if (localDay != utcDay) {
      container
          .read(paymentFiltersProvider.notifier)
          .setDateRange(startDate: utcDay, endDate: utcDay);
      await tester.pumpAndSettle();

      expect(find.text('UTC Payment'), findsNothing);
    }
  });

  testWidgets('clear filters restores all payments and clears search text', (
    tester,
  ) async {
    final container = await _pumpPage(tester, [
      _payment(id: '1', customerName: 'Maria Santos'),
      _payment(id: '2', customerName: 'Juan Cruz'),
    ]);
    container.read(paymentFiltersProvider.notifier).setSearchQuery('maria');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear filters'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Juan Cruz'), findsOneWidget);
  });
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester,
  List<Payment> payments,
) async {
  final container = ProviderContainer(
    overrides: [
      paymentRepositoryProvider.overrideWithValue(
        _FakePaymentRepository(payments),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PaymentsListPage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Payment _payment({
  required String id,
  String debtId = 'debt-id',
  double amount = 125,
  DateTime? paymentDate,
  String paymentMethod = 'Cash',
  String customerName = 'Customer',
}) {
  final date = paymentDate ?? DateTime(2026, 7, 15, 14, 5);
  return Payment(
    id: id,
    debtId: debtId,
    amount: Money.fromPesos(amount),
    paymentDate: date,
    paymentMethod: paymentMethod,
    createdAt: date,
    customerName: customerName,
  );
}

class _FakePaymentRepository implements PaymentRepository {
  const _FakePaymentRepository(this.payments);

  final List<Payment> payments;

  @override
  Future<List<Payment>> getAll() async => payments;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
