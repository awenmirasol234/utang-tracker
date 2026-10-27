import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/features/audit/data/repositories/audit_log_repository_impl.dart';
import 'package:utang_tracker/features/audit/domain/repositories/audit_log_repository.dart';
import 'package:utang_tracker/features/backup/data/repositories/cloud_backup_repository_impl.dart';
import 'package:utang_tracker/features/backup/data/services/database_backup_service.dart';
import 'package:utang_tracker/features/backup/domain/repositories/cloud_backup_repository.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:utang_tracker/features/customers/domain/repositories/customer_repository.dart';
import 'package:utang_tracker/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:utang_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';
import 'package:utang_tracker/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';
import 'package:utang_tracker/features/updater/data/repositories/update_repository_impl.dart';
import 'package:utang_tracker/features/updater/domain/repositories/update_repository.dart';

/// Bumped after any business write; business providers watch it to refresh.
class DataVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataVersionProvider = NotifierProvider<DataVersionNotifier, int>(
  DataVersionNotifier.new,
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final appDatabase = AppDatabase();
  ref.onDispose(appDatabase.close);
  return appDatabase;
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl(ref.watch(databaseProvider));
});

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepositoryImpl(ref.watch(databaseProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(ref.watch(databaseProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    ref.watch(customerRepositoryProvider),
    ref.watch(debtRepositoryProvider),
    ref.watch(paymentRepositoryProvider),
  );
});

final updateRepositoryProvider = Provider<UpdateRepository>(
  (ref) => UpdateRepositoryImpl(),
);

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepositoryImpl(ref.watch(databaseProvider));
});

final cloudBackupRepositoryProvider = Provider<CloudBackupRepository>((ref) {
  return CloudBackupRepositoryImpl(
    DatabaseBackupService(ref.watch(databaseProvider)),
  );
});
