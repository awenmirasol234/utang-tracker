import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';
import 'package:utang_tracker/features/export/domain/entities/export_file.dart';
import 'package:utang_tracker/features/export/domain/repositories/file_share_repository.dart';
import 'package:utang_tracker/features/export/domain/usecases/export_data.dart';
import 'package:utang_tracker/features/payments/data/repositories/payment_repository_impl.dart';

class _RecordingFileShareRepository implements FileShareRepository {
  final List<ExportFile> shared = [];

  @override
  Future<void> shareFiles(List<ExportFile> files) async {
    shared.addAll(files);
  }
}

void main() {
  late AppDatabase appDatabase;
  late CustomerRepositoryImpl customers;
  late DebtRepositoryImpl debts;
  late PaymentRepositoryImpl payments;
  late _RecordingFileShareRepository fileShare;
  late ExportData exportData;

  setUp(() {
    appDatabase = AppDatabase.forTesting();
    customers = CustomerRepositoryImpl(appDatabase);
    debts = DebtRepositoryImpl(appDatabase);
    payments = PaymentRepositoryImpl(appDatabase);
    fileShare = _RecordingFileShareRepository();
    exportData = ExportData(
      customers: customers,
      debts: debts,
      payments: payments,
      fileShare: fileShare,
      now: () => DateTime(2026, 10, 21),
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  List<String> csvLines(String content) =>
      content.split('\n').where((line) => line.isNotEmpty).toList();

  test('builds one csv file per table', () async {
    final files = await exportData.buildFiles();

    expect(files.map((file) => file.fileName).toList(), [
      'utang_customers_2026-10-21.csv',
      'utang_debts_2026-10-21.csv',
      'utang_payments_2026-10-21.csv',
    ]);
    expect(csvLines(files[0].content).first, 'id,name,phone,notes,created_at');
    expect(
      csvLines(files[1].content).first,
      'debt_id,customer_name,customer_phone,transaction_date,due_date,status,'
      'total_amount,paid_amount,balance,items,notes',
    );
    expect(
      csvLines(files[2].content).first,
      'payment_id,debt_id,customer_name,payment_date,amount,payment_method,notes',
    );
  });

  test('exports customers, debts and payments with plain values', () async {
    final customer = await customers.create(
      name: 'Maria Santos',
      phone: '09171234567',
      notes: 'Says "hi"',
    );
    final debt = await debts.create(
      customerId: customer.id,
      transactionDate: DateTime(2026, 10, 20),
      notes: 'Bought stuff',
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
    await payments.recordPayment(
      debtId: debt.id,
      amount: Money.fromPesos(20),
      paymentDate: DateTime(2026, 10, 21),
      paymentMethod: 'Cash',
    );

    final files = await exportData.buildFiles();

    final customerLines = csvLines(files[0].content);
    expect(customerLines.length, 2);
    expect(customerLines[1], contains('Maria Santos'));
    expect(customerLines[1], contains('09171234567'));
    expect(customerLines[1], contains('"Says ""hi"""'));

    final debtLines = csvLines(files[1].content);
    expect(debtLines.length, 2);
    expect(debtLines[1], contains('Maria Santos'));
    expect(debtLines[1], contains('09171234567'));
    expect(debtLines[1], contains('2026-10-20'));
    expect(debtLines[1], contains('PARTIAL'));
    expect(debtLines[1], contains('60.00'));
    expect(debtLines[1], contains('40.00'));
    expect(debtLines[1], contains('Bigas x2 kg @50.00'));
    expect(debtLines[1], contains('Noodles x1.5 piece @10.00'));

    final paymentLines = csvLines(files[2].content);
    expect(paymentLines.length, 2);
    expect(paymentLines[1], contains('Maria Santos'));
    expect(paymentLines[1], contains('2026-10-21'));
    expect(paymentLines[1], contains('20.00'));
    expect(paymentLines[1], contains('Cash'));
  });

  test('shares the built files', () async {
    await exportData();

    expect(fileShare.shared.length, 3);
    expect(fileShare.shared.first.fileName, 'utang_customers_2026-10-21.csv');
  });
}
