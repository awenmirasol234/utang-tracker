import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/utils/csv.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/domain/repositories/customer_repository.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';
import 'package:utang_tracker/features/export/domain/entities/export_file.dart';
import 'package:utang_tracker/features/export/domain/repositories/file_share_repository.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';

/// Builds CSV exports of the active customers, debts and payments.
class ExportDataUseCase {
  ExportDataUseCase({
    required CustomerRepository customers,
    required DebtRepository debts,
    required PaymentRepository payments,
    required FileShareRepository fileShare,
    DateTime Function()? now,
  }) : _customers = customers,
       _debts = debts,
       _payments = payments,
       _fileShare = fileShare,
       _now = now ?? DateTime.now;

  final CustomerRepository _customers;
  final DebtRepository _debts;
  final PaymentRepository _payments;
  final FileShareRepository _fileShare;
  final DateTime Function() _now;

  Future<void> call() async {
    final files = await buildFiles();
    await _fileShare.shareFiles(files);
  }

  Future<List<ExportFile>> buildFiles() async {
    final customers = await _customers.getAll();
    final debts = await _debts.getAllWithItems();
    final payments = await _payments.getAll();
    final stamp = DateFormatters.dayKey(_now());

    return [
      ExportFile(
        fileName: 'utang_customers_$stamp.csv',
        content: _customersCsv(customers),
      ),
      ExportFile(
        fileName: 'utang_debts_$stamp.csv',
        content: _debtsCsv(debts, customers),
      ),
      ExportFile(
        fileName: 'utang_payments_$stamp.csv',
        content: _paymentsCsv(payments),
      ),
    ];
  }

  String _customersCsv(List<Customer> customers) {
    final rows = <List<String>>[
      ['id', 'name', 'phone', 'notes', 'created_at'],
    ];
    for (final customer in customers) {
      rows.add([
        customer.id,
        customer.name,
        customer.phone ?? '',
        customer.notes ?? '',
        DateFormatters.dayKey(customer.createdAt),
      ]);
    }
    return _toCsv(rows);
  }

  String _debtsCsv(List<DebtDetail> debts, List<Customer> customers) {
    final phones = <String, String>{};
    for (final customer in customers) {
      phones[customer.id] = customer.phone ?? '';
    }

    final rows = <List<String>>[
      [
        'debt_id',
        'customer_name',
        'customer_phone',
        'transaction_date',
        'due_date',
        'status',
        'total_amount',
        'paid_amount',
        'balance',
        'items',
        'notes',
      ],
    ];
    for (final detail in debts) {
      final debt = detail.debt;
      final dueDate = debt.dueDate;
      var dueDateValue = '';
      if (dueDate != null) {
        dueDateValue = DateFormatters.dayKey(dueDate);
      }
      rows.add([
        debt.id,
        debt.customerName ?? '',
        phones[debt.customerId] ?? '',
        DateFormatters.dayKey(debt.transactionDate),
        dueDateValue,
        debt.status.value,
        _amount(debt.totalAmount),
        _amount(debt.paidAmount),
        _amount(debt.balance),
        _items(detail.items),
        debt.notes ?? '',
      ]);
    }
    return _toCsv(rows);
  }

  String _paymentsCsv(List<Payment> payments) {
    final rows = <List<String>>[
      [
        'payment_id',
        'debt_id',
        'customer_name',
        'payment_date',
        'amount',
        'payment_method',
        'notes',
      ],
    ];
    for (final payment in payments) {
      rows.add([
        payment.id,
        payment.debtId,
        payment.customerName ?? '',
        DateFormatters.dayKey(payment.paymentDate),
        _amount(payment.amount),
        payment.paymentMethod,
        payment.notes ?? '',
      ]);
    }
    return _toCsv(rows);
  }

  String _items(List<DebtItem> items) {
    final parts = <String>[];
    for (final item in items) {
      parts.add(
        '${item.productName} x${_quantity(item.quantity)} ${item.unit} @${_amount(item.price)}',
      );
    }
    return parts.join('; ');
  }

  String _amount(Money money) => (money.centavos / 100).toStringAsFixed(2);

  String _quantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }
    return quantity.toString();
  }

  String _toCsv(List<List<String>> rows) {
    final lines = <String>[];
    for (final row in rows) {
      lines.add(Csv.line(row));
    }
    return '${lines.join('\n')}\n';
  }
}
