import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/audit_action.dart';
import 'package:utang_tracker/core/domain/audit_change_detail.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/audit/data/repositories/audit_log_repository_impl.dart';
import 'package:utang_tracker/features/audit/domain/entities/audit_log_entry.dart';
import 'package:utang_tracker/features/audit/domain/repositories/audit_log_repository.dart';
import 'package:utang_tracker/features/audit/presentation/pages/audit_log_page.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/payments/data/repositories/payment_repository_impl.dart';

void main() {
  group('audit log', () {
    late AppDatabase appDatabase;
    late CustomerRepositoryImpl customers;
    late DebtRepositoryImpl debts;
    late PaymentRepositoryImpl payments;
    late AuditLogRepositoryImpl auditLogs;
    late int tick;

    setUp(() {
      appDatabase = AppDatabase.forTesting();
      tick = 0;
      customers = CustomerRepositoryImpl(
        appDatabase,
        now: () => DateTime.utc(2030, 1, 1, 9, 0, tick++),
      );
      debts = DebtRepositoryImpl(
        appDatabase,
        now: () => DateTime.utc(2030, 1, 1, 10, 0, tick++),
      );
      payments = PaymentRepositoryImpl(
        appDatabase,
        now: () => DateTime.utc(2030, 1, 1, 11, 0, tick++),
      );
      auditLogs = AuditLogRepositoryImpl(appDatabase);
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('records every customer, debt and payment change', () async {
      final customer = await customers.create(name: 'Maria');
      await customers.update(
        Customer(
          id: customer.id,
          name: 'Maria Santos',
          createdAt: customer.createdAt,
          updatedAt: customer.updatedAt,
        ),
      );

      final debt = await debts.create(
        customerId: customer.id,
        transactionDate: DateTime.now(),
        items: [
          DebtItemInput(
            productName: 'Bigas',
            quantity: 2,
            price: Money.fromPesoString('50'),
          ),
        ],
      );
      await debts.update(
        debtId: debt.id,
        transactionDate: DateTime.now(),
        items: [
          DebtItemInput(
            productName: 'Bigas',
            quantity: 3,
            price: Money.fromPesoString('50'),
          ),
        ],
      );
      await debts.addItems(
        debtId: debt.id,
        items: [
          DebtItemInput(
            productName: 'Noodles',
            quantity: 1,
            price: Money.fromPesoString('10'),
          ),
        ],
      );
      await payments.recordPayment(
        debtId: debt.id,
        amount: Money.fromPesoString('20'),
        paymentDate: DateTime.now(),
        paymentMethod: 'Cash',
      );

      final entries = await auditLogs.getAll();

      expect(entries.length, 6);
      expect(
        entries.map((entry) => entry.action),
        [
          AuditAction.paymentRecorded,
          AuditAction.debtItemsAdded,
          AuditAction.debtUpdated,
          AuditAction.debtCreated,
          AuditAction.customerUpdated,
          AuditAction.customerCreated,
        ],
      );
      expect(entries.first.summary, 'Paid by Maria Santos (₱20.00)');
      expect(entries[1].summary, 'Added items to debt for Maria Santos');
      expect(entries[2].summary, 'Updated debt for Maria Santos');
      expect(entries[3].summary, 'New debt for Maria Santos');
      expect(entries[4].summary, 'Updated customer Maria Santos');
      expect(entries[5].summary, 'Added customer Maria');
    });

    test('a rejected write is not logged', () async {
      await expectLater(
        customers.create(name: '   '),
        throwsA(isA<Exception>()),
      );

      final entries = await auditLogs.getAll();

      expect(entries, isEmpty);
    });

    test('records the fields a customer change touched', () async {
      final customer = await customers.create(name: 'Maria', phone: '0917');
      await customers.update(
        Customer(
          id: customer.id,
          name: 'Maria Santos',
          phone: '0918',
          notes: 'Tagalog',
          createdAt: customer.createdAt,
          updatedAt: customer.updatedAt,
        ),
      );

      final entries = await auditLogs.getAll();
      final created = entries.firstWhere(
        (entry) => entry.action == AuditAction.customerCreated,
      );
      final updated = entries.firstWhere(
        (entry) => entry.action == AuditAction.customerUpdated,
      );

      expect(created.details, [
        const AuditChangeDetail(field: 'Name', after: 'Maria'),
        const AuditChangeDetail(field: 'Phone', after: '0917'),
      ]);
      expect(updated.details, [
        const AuditChangeDetail(
          field: 'Name',
          before: 'Maria',
          after: 'Maria Santos',
        ),
        const AuditChangeDetail(
          field: 'Phone',
          before: '0917',
          after: '0918',
        ),
        const AuditChangeDetail(field: 'Notes', before: null, after: 'Tagalog'),
      ]);
    });

    test('records debt totals and the remaining balance', () async {
      final customer = await customers.create(name: 'Maria');
      final debt = await debts.create(
        customerId: customer.id,
        transactionDate: DateTime.now(),
        items: [
          DebtItemInput(
            productName: 'Bigas',
            quantity: 2,
            price: Money.fromPesoString('50'),
          ),
        ],
      );
      await debts.update(
        debtId: debt.id,
        transactionDate: DateTime.now(),
        items: [
          DebtItemInput(
            productName: 'Bigas',
            quantity: 3,
            price: Money.fromPesoString('80'),
          ),
        ],
      );
      await payments.recordPayment(
        debtId: debt.id,
        amount: Money.fromPesoString('20'),
        paymentDate: DateTime.now(),
        paymentMethod: 'Cash',
      );

      final entries = await auditLogs.getAll();
      final debtUpdated = entries.firstWhere(
        (entry) => entry.action == AuditAction.debtUpdated,
      );
      final payment = entries.firstWhere(
        (entry) => entry.action == AuditAction.paymentRecorded,
      );

      final total = debtUpdated.details.firstWhere(
        (detail) => detail.field == 'Total',
      );
      expect(total.before, '₱50.00');
      expect(total.after, '₱80.00');

      final balance = payment.details.firstWhere(
        (detail) => detail.field == 'Remaining balance',
      );
      expect(balance.before, '₱80.00');
      expect(balance.after, '₱60.00');
    });
  });

  testWidgets('audit log page lists recorded actions', (tester) async {
    await _pumpPage(
      tester,
      [
        AuditLogEntry(
          id: '1',
          action: AuditAction.customerCreated,
          entityId: 'customer-1',
          summary: 'Added customer Maria Santos',
          createdAt: DateTime.utc(2030, 1, 1, 10),
        ),
      ],
    );

    expect(find.text('Audit Log'), findsOneWidget);
    expect(find.text('Customer added'), findsOneWidget);
    expect(find.text('Added customer Maria Santos'), findsOneWidget);
  });

  testWidgets('audit log page shows an empty state', (tester) async {
    await _pumpPage(tester, []);

    expect(find.text('No audit log'), findsOneWidget);
  });

  testWidgets('audit log tile expands to show what changed', (tester) async {
    await _pumpPage(tester, [
      AuditLogEntry(
        id: '1',
        action: AuditAction.customerUpdated,
        entityId: 'customer-1',
        summary: 'Updated customer Maria Santos',
        createdAt: DateTime.utc(2030, 1, 1, 10),
        details: const [
          AuditChangeDetail(field: 'Name', before: 'Maria', after: 'Maria Santos'),
        ],
      ),
    ]);

    expect(find.text('Show details'), findsOneWidget);
    expect(find.text('Name'), findsNothing);

    await tester.tap(find.text('Show details'));
    await tester.pumpAndSettle();

    expect(find.text('Hide details'), findsOneWidget);
    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Record id'), findsNothing);
    expect(find.text('customer-1'), findsNothing);
    expect(find.text('Logged at'), findsNothing);
    expect(find.text('customer_updated'), findsNothing);
  });

  testWidgets('audit log tile uses plain labels and friendly dates', (
    tester,
  ) async {
    await _pumpPage(tester, [
      AuditLogEntry(
        id: '1',
        action: AuditAction.debtUpdated,
        entityId: 'debt-1',
        summary: 'Updated debt for Maria Santos',
        createdAt: DateTime.utc(2030, 1, 1, 10),
        details: const [
          AuditChangeDetail(field: 'Transaction date', after: '2030-01-01'),
          AuditChangeDetail(field: 'Method', after: 'Cash'),
          AuditChangeDetail(
            field: 'Items added',
            after: '1 item: Bigas x2 pc (\u20B150.00)',
          ),
        ],
      ),
    ]);

    await tester.tap(find.text('Show details'));
    await tester.pumpAndSettle();

    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Jan 1, 2030'), findsOneWidget);
    expect(find.text('2030-01-01'), findsNothing);
    expect(find.text('Payment method'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('Transaction date'), findsNothing);
    expect(find.text('Method'), findsNothing);
  });

  testWidgets('audit log tile hides the details toggle when nothing was recorded', (
    tester,
  ) async {
    await _pumpPage(tester, [
      AuditLogEntry(
        id: '1',
        action: AuditAction.customerCreated,
        entityId: 'customer-1',
        summary: 'Added customer Maria Santos',
        createdAt: DateTime.utc(2030, 1, 1, 10),
      ),
    ]);

    expect(find.text('Show details'), findsNothing);
    expect(find.text('Hide details'), findsNothing);
    expect(find.text('Record id'), findsNothing);
    expect(find.text('customer_created'), findsNothing);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  List<AuditLogEntry> entries,
) async {
  final container = ProviderContainer(
    overrides: [
      auditLogRepositoryProvider.overrideWithValue(_FakeAuditLogRepository(entries)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AuditLogPage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAuditLogRepository implements AuditLogRepository {
  const _FakeAuditLogRepository(this.entries);

  final List<AuditLogEntry> entries;

  @override
  Future<List<AuditLogEntry>> getAll() async => entries;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
