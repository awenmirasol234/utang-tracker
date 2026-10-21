import 'package:equatable/equatable.dart';
import 'package:utang_tracker/features/import/domain/entities/import_issue.dart';

/// The outcome of validating or applying an import.
class ImportSummary extends Equatable {
  const ImportSummary({
    this.customers = 0,
    this.debts = 0,
    this.payments = 0,
    this.skipped = 0,
    this.issues = const [],
  });

  /// Records that will be created.
  final int customers;
  final int debts;
  final int payments;

  /// Rows skipped because the record already exists.
  final int skipped;

  /// Rows that could not be imported. A non-empty list blocks the import.
  final List<ImportIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
  int get records => customers + debts + payments;

  @override
  List<Object?> get props => [customers, debts, payments, skipped, issues];
}
