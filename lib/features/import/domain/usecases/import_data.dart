import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/customers/domain/repositories/customer_repository.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';
import 'package:utang_tracker/features/import/domain/entities/import_file.dart';
import 'package:utang_tracker/features/import/domain/entities/import_issue.dart';
import 'package:utang_tracker/features/import/domain/entities/import_rows.dart';
import 'package:utang_tracker/features/import/domain/entities/import_summary.dart';
import 'package:utang_tracker/features/import/domain/repositories/transaction_runner.dart';
import 'package:utang_tracker/features/import/domain/usecases/import_parser.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';

/// Imports the CSV files the app exports.
///
/// Every row is validated before anything is written. A single invalid row
/// blocks the whole import, and the write itself runs in one transaction.
class ImportData {
  const ImportData({
    required CustomerRepository customers,
    required DebtRepository debts,
    required PaymentRepository payments,
    required TransactionRunner transactions,
    ImportParser parser = const ImportParser(),
  }) : _customers = customers,
       _debts = debts,
       _payments = payments,
       _transactions = transactions,
       _parser = parser;

  final CustomerRepository _customers;
  final DebtRepository _debts;
  final PaymentRepository _payments;
  final TransactionRunner _transactions;
  final ImportParser _parser;

  /// Checks the files without writing anything.
  Future<ImportSummary> validate(List<ImportFile> files) async {
    final plan = await _prepare(files);
    return ImportSummary(
      customers: plan.newCustomers.length,
      debts: plan.newDebts.length,
      payments: plan.newPayments.length,
      skipped: plan.skipped,
      issues: plan.issues,
    );
  }

  /// Imports the files. Nothing is written when any row is invalid.
  Future<ImportSummary> apply(List<ImportFile> files) async {
    final plan = await _prepare(files);
    if (plan.hasIssues) {
      return ImportSummary(skipped: plan.skipped, issues: plan.issues);
    }

    return _transactions.run(() async {
      for (final customer in plan.newCustomers) {
        await _customers.create(
          id: customer.id,
          name: customer.name,
          phone: customer.phone,
          notes: customer.notes,
        );
      }
      for (final debt in plan.newDebts) {
        await _debts.create(
          id: debt.row.debtId,
          customerId: debt.customerId,
          transactionDate: debt.row.transactionDate,
          dueDate: debt.row.dueDate,
          notes: debt.row.notes,
          items: debt.row.items
              .map(
                (item) => DebtItemInput(
                  productName: item.productName,
                  quantity: item.quantity,
                  unit: item.unit,
                  price: item.price,
                ),
              )
              .toList(),
        );
      }
      for (final payment in plan.newPayments) {
        await _payments.recordPayment(
          id: payment.paymentId,
          debtId: payment.debtId,
          amount: payment.amount,
          paymentDate: payment.paymentDate,
          paymentMethod: payment.paymentMethod,
          notes: payment.notes,
        );
      }

      return ImportSummary(
        customers: plan.newCustomers.length,
        debts: plan.newDebts.length,
        payments: plan.newPayments.length,
        skipped: plan.skipped,
      );
    });
  }

  Future<_ImportPlan> _prepare(List<ImportFile> files) async {
    final parsed = _parser.parse(files);
    final issues = <ImportIssue>[...parsed.issues];
    var skipped = 0;

    final existingCustomers = await _customers.getAll();
    final existingDebts = await _debts.getAll();
    final existingPayments = await _payments.getAll();

    final customerIds = <String>{};
    final customerIdByName = <String, String>{};
    for (final customer in existingCustomers) {
      customerIds.add(customer.id);
      customerIdByName.putIfAbsent(
        customer.name.trim().toLowerCase(),
        () => customer.id,
      );
    }

    final newCustomers = <ImportCustomerRow>[];
    final newCustomerNames = <String>{};
    for (final row in parsed.customers) {
      final nameKey = row.name.trim().toLowerCase();
      if (customerIds.contains(row.id)) {
        skipped += 1;
        customerIdByName.putIfAbsent(nameKey, () => row.id);
        continue;
      }
      if (customerIdByName.containsKey(nameKey)) {
        skipped += 1;
        continue;
      }
      if (!newCustomerNames.add(nameKey)) {
        issues.add(
          ImportIssue(
            fileName: row.fileName,
            rowNumber: row.rowNumber,
            message: 'Duplicate customer name in file: ${row.name}',
          ),
        );
        continue;
      }
      customerIds.add(row.id);
      customerIdByName[nameKey] = row.id;
      newCustomers.add(row);
    }

    final debtIds = <String>{};
    final debtBalances = <String, Money>{};
    for (final debt in existingDebts) {
      debtIds.add(debt.id);
      debtBalances[debt.id] = debt.balance;
    }

    final newDebts = <_PlannedDebt>[];
    for (final row in parsed.debts) {
      if (debtIds.contains(row.debtId)) {
        skipped += 1;
        continue;
      }
      final customerId =
          customerIdByName[row.customerName.trim().toLowerCase()];
      if (customerId == null) {
        issues.add(
          ImportIssue(
            fileName: row.fileName,
            rowNumber: row.rowNumber,
            message: 'Customer not found: ${row.customerName}',
          ),
        );
        continue;
      }
      final total = row.items
          .map((item) => item.price)
          .fold(Money.zero(), (sum, price) => sum + price);
      debtIds.add(row.debtId);
      debtBalances[row.debtId] = total;
      newDebts.add(_PlannedDebt(row: row, customerId: customerId));
    }

    final paymentIds = <String>{};
    for (final payment in existingPayments) {
      paymentIds.add(payment.id);
    }

    final orderedPayments =
        List.generate(parsed.payments.length, (index) {
          return (index: index, row: parsed.payments[index]);
        })..sort((first, second) {
          final byDate = first.row.paymentDate.compareTo(
            second.row.paymentDate,
          );
          if (byDate != 0) {
            return byDate;
          }
          return first.index.compareTo(second.index);
        });

    final paidByDebt = <String, Money>{};
    final newPayments = <ImportPaymentRow>[];
    for (final entry in orderedPayments) {
      final row = entry.row;
      if (paymentIds.contains(row.paymentId)) {
        skipped += 1;
        continue;
      }
      final balance = debtBalances[row.debtId];
      if (balance == null) {
        issues.add(
          ImportIssue(
            fileName: row.fileName,
            rowNumber: row.rowNumber,
            message: 'Debt not found: ${row.debtId}',
          ),
        );
        continue;
      }
      final alreadyPaid = paidByDebt[row.debtId] ?? Money.zero();
      if (alreadyPaid + row.amount > balance) {
        issues.add(
          ImportIssue(
            fileName: row.fileName,
            rowNumber: row.rowNumber,
            message:
                'Payment exceeds the remaining balance of the debt it belongs to.',
          ),
        );
        continue;
      }
      paidByDebt[row.debtId] = alreadyPaid + row.amount;
      paymentIds.add(row.paymentId);
      newPayments.add(row);
    }

    return _ImportPlan(
      newCustomers: newCustomers,
      newDebts: newDebts,
      newPayments: newPayments,
      skipped: skipped,
      issues: issues,
    );
  }
}

class _PlannedDebt {
  const _PlannedDebt({required this.row, required this.customerId});

  final ImportDebtRow row;
  final String customerId;
}

class _ImportPlan {
  const _ImportPlan({
    required this.newCustomers,
    required this.newDebts,
    required this.newPayments,
    required this.skipped,
    required this.issues,
  });

  final List<ImportCustomerRow> newCustomers;
  final List<_PlannedDebt> newDebts;
  final List<ImportPaymentRow> newPayments;
  final int skipped;
  final List<ImportIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}
