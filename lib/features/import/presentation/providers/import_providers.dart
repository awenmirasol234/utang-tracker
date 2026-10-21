import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/import/domain/usecases/import_data.dart';

final importDataUseCaseProvider = Provider((ref) {
  return ImportData(
    customers: ref.watch(customerRepositoryProvider),
    debts: ref.watch(debtRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
    transactions: ref.watch(transactionRunnerProvider),
  );
});
