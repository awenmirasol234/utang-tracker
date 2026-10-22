import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/domain/audit_action.dart';
import 'package:utang_tracker/core/database/app_database.dart';
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
            price: Money.fromPesos(50),
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
            price: Money.fromPesos(50),
          ),
        ],
      );
      await debts.addItems(
        debtId: debt.id,
        items: [
          DebtItemInput(
            productName: 'Noodles',
            quantity: 1,
            price: Money.fromPesos(10),
          ),
        ],
      );
      await payments.recordPayment(
        debtId: debt.id,
        amount: Money.fromPesos(20),
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
      expect(entries.first.summary, 'Nagbayad ni Maria Santos (₱20.00)');
      expect(entries[1].summary, 'Nag-add items sa utang ni Maria Santos');
      expect(entries[2].summary, 'Na-update ang utang ni Maria Santos');
      expect(entries[3].summary, 'Bag-ong utang ni Maria Santos');
      expect(entries[4].summary, 'Na-update si Maria Santos');
      expect(entries[5].summary, 'Nag-add si Maria');
    });

    test('a rejected write is not logged', () async {
      await expectLater(
        customers.create(name: '   '),
        throwsA(isA<Exception>()),
      );

      final entries = await auditLogs.getAll();

      expect(entries, isEmpty);
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
          summary: 'Nag-add si Maria Santos',
          createdAt: DateTime.utc(2030, 1, 1, 10),
        ),
      ],
    );

    expect(find.text('Audit Log'), findsOneWidget);
    expect(find.text('Nag-add customer'), findsOneWidget);
    expect(find.text('Nag-add si Maria Santos'), findsOneWidget);
  });

  testWidgets('audit log page shows an empty state', (tester) async {
    await _pumpPage(tester, []);

    expect(find.text('Walay audit log'), findsOneWidget);
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
