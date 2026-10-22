import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/database/app_database.dart';
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
    customers: ref.watch(customerRepositoryProvider),
    debts: ref.watch(debtRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
  );
});

final updateRepositoryProvider = Provider<UpdateRepository>(
  (_) => UpdateRepositoryImpl(),
);
