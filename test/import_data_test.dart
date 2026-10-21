import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';
import 'package:utang_tracker/features/export/domain/entities/export_file.dart';
import 'package:utang_tracker/features/export/domain/repositories/file_share_repository.dart';
import 'package:utang_tracker/features/export/domain/usecases/export_data.dart';
import 'package:utang_tracker/features/import/data/repositories/transaction_runner_impl.dart';
import 'package:utang_tracker/features/import/domain/entities/import_file.dart';
import 'package:utang_tracker/features/import/domain/usecases/import_data.dart';
import 'package:utang_tracker/features/payments/data/repositories/payment_repository_impl.dart';

class _FakeFileShareRepository implements FileShareRepository {
  @override
  Future<void> shareFiles(List<ExportFile> files) async {}
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase sourceDatabase;
  late CustomerRepositoryImpl sourceCustomers;
  late DebtRepositoryImpl sourceDebts;
  late PaymentRepositoryImpl sourcePayments;

  late AppDatabase targetDatabase;
  late CustomerRepositoryImpl targetCustomers;
  late DebtRepositoryImpl targetDebts;
  late PaymentRepositoryImpl targetPayments;
  late ImportData importData;

  Future<List<ImportFile>> exportFiles() async {
    final export = ExportData(
      customers: sourceCustomers,
      debts: sourceDebts,
      payments: sourcePayments,
      fileShare: _FakeFileShareRepository(),
      now: () => DateTime(2026, 10, 21),
    );
    final files = await export.buildFiles();
    return files
        .map((file) => ImportFile(name: file.fileName, content: file.content))
        .toList();
  }

  Future<void> seedSource() async {
    final customer = await sourceCustomers.create(
      name: 'Maria Santos',
      phone: '09171234567',
    );
    final debt = await sourceDebts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 10, 20),
      items: [
        DebtItemInput(
          productName: 'Bigas',
          quantity: 2,
          unit: DebtItemUnits.kilogram,
          price: Money.fromPesos(50),
        ),
        DebtItemInput(
          productName: 'Noodles',
          quantity: 1.5,
          price: Money.fromPesos(10),
        ),
      ],
    );
    await sourcePayments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(20),
      paymentDate: DateTime(2026, 10, 21),
      paymentMethod: 'Cash',
    );
  }

  setUp(() {
    sourceDatabase = AppDatabase.forTesting();
    sourceCustomers = CustomerRepositoryImpl(sourceDatabase);
    sourceDebts = DebtRepositoryImpl(sourceDatabase);
    sourcePayments = PaymentRepositoryImpl(sourceDatabase);

    targetDatabase = AppDatabase.forTesting();
    targetCustomers = CustomerRepositoryImpl(targetDatabase);
    targetDebts = DebtRepositoryImpl(targetDatabase);
    targetPayments = PaymentRepositoryImpl(targetDatabase);
    importData = ImportData(
      customers: targetCustomers,
      debts: targetDebts,
      payments: targetPayments,
      transactions: DriftTransactionRunnerImpl(targetDatabase),
    );
  });

  tearDown(() async {
    await sourceDatabase.close();
    await targetDatabase.close();
  });

  test('imports an export into an empty database', () async {
    await seedSource();
    final files = await exportFiles();

    final summary = await importData.apply(files);

    expect(summary.hasIssues, isFalse);
    expect(summary.customers, 1);
    expect(summary.debts, 1);
    expect(summary.payments, 1);

    final customers = await targetCustomers.getAll();
    expect(customers.length, 1);
    expect(customers.first.name, 'Maria Santos');
    expect(customers.first.phone, '09171234567');

    final debts = await targetDebts.getAllWithItems();
    expect(debts.length, 1);
    expect(debts.first.debt.totalAmount.centavos, 6000);
    expect(debts.first.debt.paidAmount.centavos, 2000);
    expect(debts.first.debt.balance.centavos, 4000);
    expect(debts.first.debt.status, DebtStatus.partial);
    expect(debts.first.items.length, 2);
    expect(debts.first.items.first.productName, 'Bigas');
    expect(debts.first.items.first.unit, 'kg');
    expect(debts.first.items.first.price.centavos, 5000);
    expect(debts.first.items.last.quantity, 1.5);

    final payments = await targetPayments.getAll();
    expect(payments.length, 1);
    expect(payments.first.amount.centavos, 2000);
    expect(payments.first.paymentMethod, 'Cash');
  });

  test('keeps the exported ids so payments still match their debt', () async {
    await seedSource();
    final sourceCustomer = (await sourceCustomers.getAll()).first;
    final files = await exportFiles();

    await importData.apply(files);

    final importedCustomer = (await targetCustomers.getAll()).first;
    final importedDebt = (await targetDebts.getAll()).first;
    final importedPayment = (await targetPayments.getAll()).first;

    expect(importedCustomer.id, sourceCustomer.id);
    expect(importedPayment.debtId, importedDebt.id);
  });

  test('skips rows that are already imported', () async {
    await seedSource();
    final files = await exportFiles();

    await importData.apply(files);
    final summary = await importData.apply(files);

    expect(summary.hasIssues, isFalse);
    expect(summary.records, 0);
    expect(summary.skipped, 3);
    expect((await targetDebts.getAll()).length, 1);
    expect((await targetPayments.getAll()).length, 1);
  });

  test('blocks the import when a row is invalid', () async {
    await seedSource();
    final files = await exportFiles();
    final debtsFile = files.firstWhere((file) => file.name.contains('debts'));
    final broken = ImportFile(
      name: debtsFile.name,
      content: debtsFile.content.replaceAll(',60.00,', ',99.00,'),
    );
    final brokenFiles = files
        .map((file) => file.name == debtsFile.name ? broken : file)
        .toList();

    final summary = await importData.apply(brokenFiles);

    expect(summary.hasIssues, isTrue);
    expect(summary.issues.first.message, contains('Total does not match'));
    expect((await targetCustomers.getAll()).length, 0);
    expect((await targetDebts.getAll()).length, 0);
  });

  test('reports a customer that cannot be resolved', () async {
    await seedSource();
    final files = await exportFiles();
    final debtsOnly = files
        .where((file) => file.name.contains('debts'))
        .toList();

    final summary = await importData.validate(debtsOnly);

    expect(summary.hasIssues, isTrue);
    expect(summary.issues.first.message, contains('Customer not found'));
  });

  test('reports a payment that exceeds the debt balance', () async {
    await seedSource();
    final files = await exportFiles();
    final paymentsFile = files.firstWhere(
      (file) => file.name.contains('payments'),
    );
    final broken = ImportFile(
      name: paymentsFile.name,
      content: paymentsFile.content.replaceAll(',20.00,', ',500.00,'),
    );
    final brokenFiles = files
        .map((file) => file.name == paymentsFile.name ? broken : file)
        .toList();

    final summary = await importData.validate(brokenFiles);

    expect(summary.hasIssues, isTrue);
    expect(summary.issues.first.message, contains('exceeds the remaining'));
  });

  test('reuses an existing customer instead of duplicating it', () async {
    final existing = await targetCustomers.create(name: 'maria santos');
    await seedSource();
    final files = await exportFiles();

    final summary = await importData.apply(files);

    expect(summary.hasIssues, isFalse);
    expect(summary.customers, 0);
    expect(summary.skipped, 1);
    final customers = await targetCustomers.getAll();
    expect(customers.length, 1);
    expect(customers.first.id, existing.id);
  });
}
