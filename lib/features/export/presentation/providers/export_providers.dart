import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/export/domain/usecases/export_data.dart';

final exportDataUseCaseProvider = Provider((ref) {
  return ExportData(
    customers: ref.watch(customerRepositoryProvider),
    debts: ref.watch(debtRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
    fileShare: ref.watch(fileShareRepositoryProvider),
  );
});
