/// Runs a unit of work atomically.
abstract class TransactionRunner {
  Future<T> run<T>(Future<T> Function() action);
}
