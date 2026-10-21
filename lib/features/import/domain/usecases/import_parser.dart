import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/utils/csv.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';
import 'package:utang_tracker/features/import/domain/entities/import_file.dart';
import 'package:utang_tracker/features/import/domain/entities/import_issue.dart';
import 'package:utang_tracker/features/import/domain/entities/import_rows.dart';

/// The rows read from the picked files, together with the problems found.
class ImportParseResult {
  const ImportParseResult({
    required this.customers,
    required this.debts,
    required this.payments,
    required this.issues,
  });

  final List<ImportCustomerRow> customers;
  final List<ImportDebtRow> debts;
  final List<ImportPaymentRow> payments;
  final List<ImportIssue> issues;
}

/// Reads the CSV files the app exports and turns them into import rows.
class ImportParser {
  const ImportParser();

  static const List<String> _customerColumns = ['id', 'name'];
  static const List<String> _debtColumns = [
    'debt_id',
    'customer_name',
    'transaction_date',
    'items',
  ];
  static const List<String> _paymentColumns = [
    'payment_id',
    'debt_id',
    'payment_date',
    'amount',
  ];

  ImportParseResult parse(List<ImportFile> files) {
    final customers = <ImportCustomerRow>[];
    final debts = <ImportDebtRow>[];
    final payments = <ImportPaymentRow>[];
    final issues = <ImportIssue>[];

    for (final file in files) {
      final rows = Csv.parse(file.content);
      if (rows.isEmpty) {
        issues.add(
          ImportIssue(
            fileName: file.name,
            rowNumber: 0,
            message: 'The file is empty.',
          ),
        );
        continue;
      }

      final header = Csv.headerIndex(rows.first);
      final type = _detectType(header);
      if (type == null) {
        issues.add(
          ImportIssue(
            fileName: file.name,
            rowNumber: 1,
            message:
                'Unrecognized CSV header. Expected a customers, debts or payments export.',
          ),
        );
        continue;
      }

      switch (type) {
        case _FileType.customers:
          _parseCustomers(file, rows, header, customers, issues);
        case _FileType.debts:
          _parseDebts(file, rows, header, debts, issues);
        case _FileType.payments:
          _parsePayments(file, rows, header, payments, issues);
      }
    }

    return ImportParseResult(
      customers: customers,
      debts: debts,
      payments: payments,
      issues: issues,
    );
  }

  _FileType? _detectType(Map<String, int> header) {
    if (_hasColumns(header, _customerColumns)) {
      return _FileType.customers;
    }
    if (_hasColumns(header, _debtColumns)) {
      return _FileType.debts;
    }
    if (_hasColumns(header, _paymentColumns)) {
      return _FileType.payments;
    }
    return null;
  }

  bool _hasColumns(Map<String, int> header, List<String> columns) {
    for (final column in columns) {
      if (!header.containsKey(column)) {
        return false;
      }
    }
    return true;
  }

  void _parseCustomers(
    ImportFile file,
    List<List<String>> rows,
    Map<String, int> header,
    List<ImportCustomerRow> out,
    List<ImportIssue> issues,
  ) {
    for (var index = 1; index < rows.length; index += 1) {
      final row = rows[index];
      final rowNumber = index + 1;
      if (_isBlank(row)) {
        continue;
      }

      final id = _cell(row, header, 'id');
      if (id == null || id.isEmpty) {
        issues.add(_issue(file, rowNumber, 'Customer id is required.'));
        continue;
      }
      final name = _cell(row, header, 'name');
      if (name == null || name.isEmpty) {
        issues.add(_issue(file, rowNumber, 'Customer name is required.'));
        continue;
      }

      out.add(
        ImportCustomerRow(
          fileName: file.name,
          rowNumber: rowNumber,
          id: id,
          name: name,
          phone: _cell(row, header, 'phone') ?? '',
          notes: _cell(row, header, 'notes') ?? '',
        ),
      );
    }
  }

  void _parseDebts(
    ImportFile file,
    List<List<String>> rows,
    Map<String, int> header,
    List<ImportDebtRow> out,
    List<ImportIssue> issues,
  ) {
    for (var index = 1; index < rows.length; index += 1) {
      final row = rows[index];
      final rowNumber = index + 1;
      if (_isBlank(row)) {
        continue;
      }

      final debtId = _cell(row, header, 'debt_id');
      if (debtId == null || debtId.isEmpty) {
        issues.add(_issue(file, rowNumber, 'Debt id is required.'));
        continue;
      }
      final customerName = _cell(row, header, 'customer_name');
      if (customerName == null || customerName.isEmpty) {
        issues.add(_issue(file, rowNumber, 'Customer name is required.'));
        continue;
      }
      final transactionDate = _parseDate(
        _cell(row, header, 'transaction_date'),
      );
      if (transactionDate == null) {
        issues.add(
          _issue(
            file,
            rowNumber,
            'Invalid transaction date. Expected yyyy-MM-dd.',
          ),
        );
        continue;
      }

      DateTime? dueDate;
      final dueDateText = _cell(row, header, 'due_date') ?? '';
      if (dueDateText.isNotEmpty) {
        final parsedDueDate = _parseDate(dueDateText);
        if (parsedDueDate == null) {
          issues.add(
            _issue(file, rowNumber, 'Invalid due date. Expected yyyy-MM-dd.'),
          );
          continue;
        }
        dueDate = parsedDueDate;
      }

      final items = _parseItems(
        _cell(row, header, 'items') ?? '',
        file,
        rowNumber,
        issues,
      );
      if (items == null) {
        continue;
      }

      final totalText = _cell(row, header, 'total_amount') ?? '';
      if (totalText.isNotEmpty) {
        final total = _parseMoney(totalText);
        if (total == null) {
          issues.add(_issue(file, rowNumber, 'Invalid total amount.'));
          continue;
        }
        final itemTotal = items
            .map((item) => item.price)
            .fold(Money.zero(), (sum, price) => sum + price);
        if (itemTotal != total) {
          issues.add(
            _issue(
              file,
              rowNumber,
              'Total does not match the sum of the item amounts.',
            ),
          );
          continue;
        }
      }

      out.add(
        ImportDebtRow(
          fileName: file.name,
          rowNumber: rowNumber,
          debtId: debtId,
          customerName: customerName,
          transactionDate: transactionDate,
          dueDate: dueDate,
          items: items,
          notes: _cell(row, header, 'notes') ?? '',
        ),
      );
    }
  }

  void _parsePayments(
    ImportFile file,
    List<List<String>> rows,
    Map<String, int> header,
    List<ImportPaymentRow> out,
    List<ImportIssue> issues,
  ) {
    for (var index = 1; index < rows.length; index += 1) {
      final row = rows[index];
      final rowNumber = index + 1;
      if (_isBlank(row)) {
        continue;
      }

      final paymentId = _cell(row, header, 'payment_id');
      if (paymentId == null || paymentId.isEmpty) {
        issues.add(_issue(file, rowNumber, 'Payment id is required.'));
        continue;
      }
      final debtId = _cell(row, header, 'debt_id');
      if (debtId == null || debtId.isEmpty) {
        issues.add(_issue(file, rowNumber, 'Debt id is required.'));
        continue;
      }
      final paymentDate = _parseDate(_cell(row, header, 'payment_date'));
      if (paymentDate == null) {
        issues.add(
          _issue(file, rowNumber, 'Invalid payment date. Expected yyyy-MM-dd.'),
        );
        continue;
      }
      final amount = _parseMoney(_cell(row, header, 'amount') ?? '');
      if (amount == null) {
        issues.add(_issue(file, rowNumber, 'Invalid payment amount.'));
        continue;
      }
      if (!amount.isPositive) {
        issues.add(
          _issue(file, rowNumber, 'Payment amount must be greater than zero.'),
        );
        continue;
      }

      final methodText = _cell(row, header, 'payment_method');
      final paymentMethod = methodText ?? AppConstants.defaultPaymentMethod;
      if (paymentMethod.isEmpty) {
        issues.add(_issue(file, rowNumber, 'Payment method is required.'));
        continue;
      }

      out.add(
        ImportPaymentRow(
          fileName: file.name,
          rowNumber: rowNumber,
          paymentId: paymentId,
          debtId: debtId,
          paymentDate: paymentDate,
          amount: amount,
          paymentMethod: paymentMethod,
          notes: _cell(row, header, 'notes') ?? '',
        ),
      );
    }
  }

  /// Parses the packed items cell: `Product x2 kg @50.00; Other x1 piece @10.00`.
  List<ImportItemRow>? _parseItems(
    String cell,
    ImportFile file,
    int rowNumber,
    List<ImportIssue> issues,
  ) {
    final trimmed = cell.trim();
    if (trimmed.isEmpty) {
      issues.add(_issue(file, rowNumber, 'Add at least one debt item.'));
      return null;
    }

    final items = <ImportItemRow>[];
    for (final segment in trimmed.split('; ')) {
      final part = segment.trim();
      if (part.isEmpty) {
        continue;
      }

      final priceSeparator = part.lastIndexOf('@');
      if (priceSeparator < 0) {
        issues.add(_issue(file, rowNumber, 'Invalid item: $part'));
        return null;
      }
      final head = part.substring(0, priceSeparator).trim();
      final priceText = part.substring(priceSeparator + 1).trim();

      final quantitySeparator = head.lastIndexOf(' x');
      if (quantitySeparator < 0) {
        issues.add(_issue(file, rowNumber, 'Invalid item: $part'));
        return null;
      }
      final productName = head.substring(0, quantitySeparator).trim();
      final rest = head.substring(quantitySeparator + 2).trim();

      var quantityText = rest;
      var unit = '';
      final unitSeparator = rest.indexOf(' ');
      if (unitSeparator >= 0) {
        quantityText = rest.substring(0, unitSeparator).trim();
        unit = rest.substring(unitSeparator + 1).trim();
      }

      if (productName.isEmpty) {
        issues.add(_issue(file, rowNumber, 'Product name is required.'));
        return null;
      }
      final quantity = double.tryParse(quantityText);
      if (quantity == null) {
        issues.add(_issue(file, rowNumber, 'Invalid quantity: $quantityText'));
        return null;
      }
      if (quantity <= 0) {
        issues.add(
          _issue(file, rowNumber, 'Quantity must be greater than zero.'),
        );
        return null;
      }
      if (unit.isEmpty) {
        issues.add(_issue(file, rowNumber, 'Unit is required.'));
        return null;
      }
      if (unit.length > 24) {
        issues.add(
          _issue(file, rowNumber, 'Unit must be 24 characters or fewer.'),
        );
        return null;
      }
      final price = _parseMoney(priceText);
      if (price == null) {
        issues.add(_issue(file, rowNumber, 'Invalid price: $priceText'));
        return null;
      }
      if (!price.isPositive) {
        issues.add(_issue(file, rowNumber, 'Price must be greater than zero.'));
        return null;
      }

      items.add(
        ImportItemRow(
          productName: productName,
          quantity: quantity,
          unit: DebtItemUnits.normalize(unit),
          price: price,
        ),
      );
    }

    if (items.isEmpty) {
      issues.add(_issue(file, rowNumber, 'Add at least one debt item.'));
      return null;
    }
    return items;
  }

  String? _cell(List<String> row, Map<String, int> header, String column) {
    final position = header[column];
    if (position == null || position >= row.length) {
      return null;
    }
    return row[position].trim();
  }

  bool _isBlank(List<String> row) {
    for (final value in row) {
      if (value.trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateFormatters.parseDayKey(value);
  }

  Money? _parseMoney(String value) {
    if (value.isEmpty) {
      return null;
    }
    try {
      return Money.fromPesoString(value);
    } on FormatException {
      return null;
    }
  }

  ImportIssue _issue(ImportFile file, int rowNumber, String message) {
    return ImportIssue(
      fileName: file.name,
      rowNumber: rowNumber,
      message: message,
    );
  }
}

enum _FileType { customers, debts, payments }
