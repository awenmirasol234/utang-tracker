import 'package:equatable/equatable.dart';
import 'package:utang_tracker/core/domain/money.dart';

/// A customer row read from an imported customers file.
class ImportCustomerRow extends Equatable {
  const ImportCustomerRow({
    required this.fileName,
    required this.rowNumber,
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
  });

  final String fileName;
  final int rowNumber;
  final String id;
  final String name;
  final String phone;
  final String notes;

  @override
  List<Object?> get props => [fileName, rowNumber, id, name, phone, notes];
}

/// A debt row read from an imported debts file.
class ImportDebtRow extends Equatable {
  const ImportDebtRow({
    required this.fileName,
    required this.rowNumber,
    required this.debtId,
    required this.customerName,
    required this.transactionDate,
    required this.dueDate,
    required this.items,
    required this.notes,
  });

  final String fileName;
  final int rowNumber;
  final String debtId;
  final String customerName;
  final DateTime transactionDate;
  final DateTime? dueDate;
  final List<ImportItemRow> items;
  final String notes;

  @override
  List<Object?> get props => [
    fileName,
    rowNumber,
    debtId,
    customerName,
    transactionDate,
    dueDate,
    items,
    notes,
  ];
}

/// A single line item read from the packed items cell of a debt row.
class ImportItemRow extends Equatable {
  const ImportItemRow({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.price,
  });

  final String productName;
  final double quantity;
  final String unit;

  /// The final line amount in centavos. Quantity does not multiply price.
  final Money price;

  @override
  List<Object?> get props => [productName, quantity, unit, price];
}

/// A payment row read from an imported payments file.
class ImportPaymentRow extends Equatable {
  const ImportPaymentRow({
    required this.fileName,
    required this.rowNumber,
    required this.paymentId,
    required this.debtId,
    required this.paymentDate,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
  });

  final String fileName;
  final int rowNumber;
  final String paymentId;
  final String debtId;
  final DateTime paymentDate;
  final Money amount;
  final String paymentMethod;
  final String notes;

  @override
  List<Object?> get props => [
    fileName,
    rowNumber,
    paymentId,
    debtId,
    paymentDate,
    amount,
    paymentMethod,
    notes,
  ];
}
