import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';
import 'package:utang_tracker/features/backup/domain/repositories/cloud_backup_repository.dart';
import 'package:utang_tracker/features/backup/presentation/widgets/cloud_backup_auto_checker.dart';

void main() {
  testWidgets('checks on startup and when the app resumes', (tester) async {
    final repository = _LifecycleBackupRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: CloudBackupAutoChecker(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.statusCalls, 2);
    expect(repository.backupCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repository.statusCalls, 4);
    expect(repository.backupCalls, 2);
  });

  testWidgets('does not back up before the weekly interval is due', (
    tester,
  ) async {
    final repository = _LifecycleBackupRepository(
      interval: BackupInterval.weekly,
      lastBackupAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: CloudBackupAutoChecker(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.backupCalls, 0);
  });

  testWidgets('backs up after the weekly interval is due', (tester) async {
    final repository = _LifecycleBackupRepository(
      interval: BackupInterval.weekly,
      lastBackupAt: DateTime.now().subtract(const Duration(days: 8)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: CloudBackupAutoChecker(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.backupCalls, 1);
  });
}

class _LifecycleBackupRepository implements CloudBackupRepository {
  _LifecycleBackupRepository({
    this.interval = BackupInterval.daily,
    DateTime? lastBackupAt,
  }) : lastBackupAt =
           lastBackupAt ?? DateTime.now().subtract(const Duration(days: 1));

  int statusCalls = 0;
  int backupCalls = 0;
  final BackupInterval interval;
  final DateTime lastBackupAt;

  @override
  Future<BackupStatus> getStatus() async {
    statusCalls++;
    return BackupStatus(
      isSignedIn: true,
      lastBackupAt: lastBackupAt,
      interval: interval,
    );
  }

  @override
  Future<BackupStatus> signIn() async => _status;

  @override
  Future<void> signOut() async {}

  @override
  Future<BackupStatus> backup({required bool interactive}) async {
    backupCalls++;
    return _status;
  }

  @override
  Future<BackupStatus> restore(BackupRecord backup) async => _status;

  @override
  Future<BackupStatus> setInterval(BackupInterval interval) async => _status;

  BackupStatus get _status => BackupStatus(
    isSignedIn: true,
    lastBackupAt: DateTime.now(),
    interval: interval,
  );
}
