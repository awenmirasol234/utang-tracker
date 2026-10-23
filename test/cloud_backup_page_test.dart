import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_theme.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';
import 'package:utang_tracker/features/backup/domain/repositories/cloud_backup_repository.dart';
import 'package:utang_tracker/features/backup/presentation/pages/cloud_backup_page.dart';

void main() {
  testWidgets('cloud backup page shows Google sign-in when disconnected', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(
            const _FakeCloudBackupRepository(BackupStatus(isSignedIn: false)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CloudBackupPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protect your ledger'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('cloud backup page shows backup actions when connected', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(
            _FakeCloudBackupRepository(
              BackupStatus(
                isSignedIn: true,
                email: 'owner@example.com',
                lastBackupAt: DateTime(2026, 10, 23, 10),
                backups: [
                  BackupRecord(
                    id: 'backup-1',
                    name: 'backup.sqlite',
                    modifiedAt: DateTime(2026, 10, 23, 10),
                    sizeBytes: 1024,
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CloudBackupPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Google Drive connected'), findsOneWidget);
    expect(find.text('Backup health'), findsOneWidget);
    expect(find.text('Backups stored: 1 of 5'), findsOneWidget);
    expect(find.text('Backup history'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Back up now'), findsOneWidget);
    expect(find.text('Restore selected backup'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}

class _FakeCloudBackupRepository implements CloudBackupRepository {
  const _FakeCloudBackupRepository(this.status);

  final BackupStatus status;

  @override
  Future<BackupStatus> getStatus() async => status;

  @override
  Future<BackupStatus> signIn() async => status;

  @override
  Future<void> signOut() async {}

  @override
  Future<BackupStatus> backup({required bool interactive}) async => status;

  @override
  Future<BackupStatus> restore(BackupRecord backup) async => status;

  @override
  Future<BackupStatus> setInterval(BackupInterval interval) async => status;
}
