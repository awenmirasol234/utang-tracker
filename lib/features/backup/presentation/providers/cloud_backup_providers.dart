import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/utils/user_facing_error.dart';
import 'package:utang_tracker/features/audit/presentation/providers/audit_log_providers.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';
import 'package:utang_tracker/features/backup/domain/repositories/cloud_backup_repository.dart';
import 'package:utang_tracker/features/customers/presentation/providers/customer_providers.dart';
import 'package:utang_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:utang_tracker/features/debts/presentation/providers/debt_providers.dart';
import 'package:utang_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:utang_tracker/features/payments/presentation/providers/payment_providers.dart';

enum BackupOperation { signingIn, backingUp, restoring, signingOut }

class CloudBackupState {
  const CloudBackupState({
    this.status = const BackupStatus(isSignedIn: false),
    this.operation,
    this.error,
  });

  final BackupStatus status;
  final BackupOperation? operation;
  final String? error;

  bool get isBusy => operation != null;

  CloudBackupState copyWith({
    BackupStatus? status,
    BackupOperation? operation,
    bool clearOperation = false,
    String? error,
    bool clearError = false,
  }) {
    BackupOperation? nextOperation = this.operation;
    if (clearOperation) {
      nextOperation = null;
    } else if (operation != null) {
      nextOperation = operation;
    }

    String? nextError = this.error;
    if (clearError) {
      nextError = null;
    } else if (error != null) {
      nextError = error;
    }

    return CloudBackupState(
      status: status ?? this.status,
      operation: nextOperation,
      error: nextError,
    );
  }
}

final cloudBackupNotifierProvider =
    NotifierProvider<CloudBackupNotifier, CloudBackupState>(
      CloudBackupNotifier.new,
    );

class CloudBackupNotifier extends Notifier<CloudBackupState> {
  CloudBackupRepository get _repository =>
      ref.read(cloudBackupRepositoryProvider);

  @override
  CloudBackupState build() => const CloudBackupState();

  Future<void> load() async {
    try {
      final status = await _repository.getStatus();
      state = state.copyWith(status: status, clearError: true);
    } catch (error) {
      state = state.copyWith(error: userFacingError(error));
    }
  }

  Future<bool> signIn() async {
    if (state.isBusy) return false;
    state = state.copyWith(
      operation: BackupOperation.signingIn,
      clearError: true,
    );
    try {
      final status = await _repository.signIn();
      state = state.copyWith(status: status, clearOperation: true);
      return true;
    } catch (error) {
      state = state.copyWith(
        error: userFacingError(error),
        clearOperation: true,
      );
      return false;
    }
  }

  Future<bool> backup({required bool interactive}) async {
    if (state.isBusy) return false;
    state = state.copyWith(
      operation: BackupOperation.backingUp,
      clearError: true,
    );
    try {
      final status = await _repository.backup(interactive: interactive);
      state = state.copyWith(status: status, clearOperation: true);
      return true;
    } catch (error) {
      state = state.copyWith(
        error: userFacingError(error),
        clearOperation: true,
      );
      return false;
    }
  }

  Future<bool> restore() async {
    if (state.isBusy) return false;
    state = state.copyWith(
      operation: BackupOperation.restoring,
      clearError: true,
    );
    try {
      final status = await _repository.restore();
      ref.invalidate(databaseProvider);
      _invalidateBusinessData();
      state = state.copyWith(status: status, clearOperation: true);
      return true;
    } catch (error) {
      ref.invalidate(databaseProvider);
      state = state.copyWith(
        error: userFacingError(error),
        clearOperation: true,
      );
      return false;
    }
  }

  Future<bool> signOut() async {
    if (state.isBusy) return false;
    state = state.copyWith(
      operation: BackupOperation.signingOut,
      clearError: true,
    );
    try {
      await _repository.signOut();
      state = state.copyWith(
        status: const BackupStatus(isSignedIn: false),
        clearOperation: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        error: userFacingError(error),
        clearOperation: true,
      );
      return false;
    }
  }

  Future<void> backupIfDue() async {
    try {
      final status = await _repository.getStatus();
      state = state.copyWith(status: status);
      if (!status.isSignedIn || _wasBackedUpToday(status.lastBackupAt)) {
        return;
      }
      await _repository.backup(interactive: false);
      final updatedStatus = await _repository.getStatus();
      state = state.copyWith(status: updatedStatus);
    } catch (_) {
      // Automatic backups must never block app startup or interrupt the user.
    }
  }

  bool _wasBackedUpToday(DateTime? lastBackupAt) {
    if (lastBackupAt == null) return false;
    final now = DateTime.now();
    final localBackupTime = lastBackupAt.toLocal();
    return localBackupTime.year == now.year &&
        localBackupTime.month == now.month &&
        localBackupTime.day == now.day;
  }

  void _invalidateBusinessData() {
    ref.invalidate(customersListProvider);
    ref.invalidate(debtsListProvider);
    ref.invalidate(paymentsListProvider);
    ref.invalidate(paymentFilterOptionsProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(debtNotificationsProvider);
    ref.invalidate(auditLogEntriesProvider);
  }
}
