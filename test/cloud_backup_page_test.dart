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
    final repository = _FakeCloudBackupRepository(
      const BackupStatus(isSignedIn: false),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CloudBackupPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Protect your ledger'), findsNothing);
    expect(
      find.text(
        'Choose your Google account, then allow Drive access for backups.',
      ),
      findsOneWidget,
    );
    expect(find.text('Connect Google Drive'), findsOneWidget);
    expect(find.bySemanticsLabel('Google'), findsOneWidget);
    expect(repository.statusCalls, 1);
  });

  testWidgets('cloud backup page loads a saved connection on open', (
    tester,
  ) async {
    final repository = _FakeCloudBackupRepository(
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
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CloudBackupPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Google Drive connected'), findsOneWidget);
    expect(find.text('Not connected'), findsNothing);
    expect(find.text('Connect Google Drive'), findsNothing);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Back up now'), findsOneWidget);
    expect(repository.statusCalls, 1);
  });

  testWidgets('cloud backup page shows backup actions after sign-in', (
    tester,
  ) async {
    final repository = _FakeCloudBackupRepository(
      const BackupStatus(isSignedIn: false),
      signInStatus: BackupStatus(
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
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CloudBackupPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect Google Drive'));
    await tester.pumpAndSettle();

    expect(find.text('Google Drive connected'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Google Drive'), findsOneWidget);
    expect(
      tester.getSize(find.byType(InputDecorator)).height,
      closeTo(56, 0.1),
    );
    expect(find.text('Last backup'), findsOneWidget);
    expect(find.text('Backup health'), findsNothing);
    expect(find.text('Backup history'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Back up now'), findsOneWidget);
    expect(find.text('Restore selected backup'), findsNothing);

    await tester.tap(find.text('Backup history'));
    await tester.pumpAndSettle();

    expect(find.text('Restore selected backup'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}

class _FakeCloudBackupRepository implements CloudBackupRepository {
  _FakeCloudBackupRepository(this.status, {this.signInStatus});

  final BackupStatus status;
  final BackupStatus? signInStatus;
  int statusCalls = 0;

  @override
  Future<BackupStatus> getStatus() async {
    statusCalls++;
    return status;
  }

  @override
  Future<BackupStatus> signIn() async => signInStatus ?? status;

  @override
  Future<void> signOut() async {}

  @override
  Future<BackupStatus> backup({required bool interactive}) async => status;

  @override
  Future<BackupStatus> restore(BackupRecord backup) async => status;

  @override
  Future<BackupStatus> setInterval(BackupInterval interval) async => status;
}
