import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/features/import/domain/repositories/transaction_runner.dart';

class DriftTransactionRunnerImpl implements TransactionRunner {
  const DriftTransactionRunnerImpl(this._db);

  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() action) => _db.transaction(action);
}
