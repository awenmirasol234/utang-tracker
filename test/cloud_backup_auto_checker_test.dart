import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
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
}

class _LifecycleBackupRepository implements CloudBackupRepository {
  int statusCalls = 0;
  int backupCalls = 0;

  @override
  Future<BackupStatus> getStatus() async {
    statusCalls++;
    return BackupStatus(
      isSignedIn: true,
      lastBackupAt: DateTime.now().subtract(const Duration(days: 1)),
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
  Future<BackupStatus> restore() async => _status;

  BackupStatus get _status =>
      BackupStatus(isSignedIn: true, lastBackupAt: DateTime.now());
}
