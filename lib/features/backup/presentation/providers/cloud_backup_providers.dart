import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/utils/user_facing_error.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';
import 'package:utang_tracker/features/backup/domain/repositories/cloud_backup_repository.dart';

enum BackupOperation {
  signingIn,
  backingUp,
  restoring,
  signingOut,
  updatingInterval,
}

class CloudBackupState {
  const CloudBackupState({
    this.status = const BackupStatus(isSignedIn: false),
    this.operation,
    this.error,
    this.selectedBackupId,
  });

  final BackupStatus status;
  final BackupOperation? operation;
  final String? error;
  final String? selectedBackupId;

  bool get isBusy => operation != null;

  BackupRecord? get selectedBackup {
    if (status.backups.isEmpty) return null;
    final selectedId = selectedBackupId;
    if (selectedId != null) {
      for (final backup in status.backups) {
        if (backup.id == selectedId) return backup;
      }
    }
    return status.backups.first;
  }

  CloudBackupState copyWith({
    BackupStatus? status,
    BackupOperation? operation,
    bool clearOperation = false,
    String? error,
    bool clearError = false,
    String? selectedBackupId,
    bool clearSelectedBackup = false,
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

    String? nextSelectedBackupId = this.selectedBackupId;
    if (clearSelectedBackup) {
      nextSelectedBackupId = null;
    } else if (selectedBackupId != null) {
      nextSelectedBackupId = selectedBackupId;
    }

    return CloudBackupState(
      status: status ?? this.status,
      operation: nextOperation,
      error: nextError,
      selectedBackupId: nextSelectedBackupId,
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

  Future<bool> signIn() async {
    if (state.isBusy) return false;
    state = state.copyWith(
      operation: BackupOperation.signingIn,
      clearError: true,
    );
    try {
      final status = await _repository.signIn();
      state = state.copyWith(
        status: status,
        clearOperation: true,
        clearSelectedBackup: true,
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

  Future<bool> backup({required bool interactive}) async {
    if (state.isBusy) return false;
    state = state.copyWith(
      operation: BackupOperation.backingUp,
      clearError: true,
    );
    try {
      final status = await _repository.backup(interactive: interactive);
      state = state.copyWith(
        status: status,
        clearOperation: true,
        clearSelectedBackup: true,
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

  Future<bool> restore() async {
    if (state.isBusy) return false;
    final backup = state.selectedBackup;
    if (backup == null) return false;
    state = state.copyWith(
      operation: BackupOperation.restoring,
      clearError: true,
    );
    try {
      final status = await _repository.restore(backup);
      ref.invalidate(databaseProvider);
      ref.read(dataVersionProvider.notifier).bump();
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
        clearSelectedBackup: true,
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

  Future<bool> setInterval(BackupInterval interval) async {
    if (state.isBusy || state.status.interval == interval) return false;
    state = state.copyWith(
      operation: BackupOperation.updatingInterval,
      clearError: true,
    );
    try {
      final status = await _repository.setInterval(interval);
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

  void selectBackup(String backupId) {
    if (state.isBusy) return;
    for (final backup in state.status.backups) {
      if (backup.id == backupId) {
        state = state.copyWith(selectedBackupId: backupId);
        return;
      }
    }
  }

  Future<void> loadStatus() async {
    if (state.isBusy) return;
    try {
      final status = await _repository.getStatus();
      state = state.copyWith(status: status, clearSelectedBackup: true);
    } catch (_) {
      // A passive check on page open must not show an error.
    }
  }

  Future<void> backupIfDue() async {
    try {
      final status = await _repository.getStatus();
      state = state.copyWith(status: status, clearSelectedBackup: true);
      if (!status.isSignedIn || !_isBackupDue(status)) {
        return;
      }
      await _repository.backup(interactive: false);
      final updatedStatus = await _repository.getStatus();
      state = state.copyWith(status: updatedStatus, clearSelectedBackup: true);
    } catch (_) {
      // Automatic backups must never block the app or interrupt the user.
      try {
        final status = await _repository.getStatus();
        state = state.copyWith(status: status, clearSelectedBackup: true);
      } catch (_) {
        // Keep the previous status if the refresh also fails.
      }
    }
  }

  bool _isBackupDue(BackupStatus status) {
    final window = status.interval.window;
    if (window == null) return false;
    final lastBackupAt = status.lastBackupAt;
    if (lastBackupAt == null) return true;
    return !DateTime.now().isBefore(lastBackupAt.add(window));
  }
}
