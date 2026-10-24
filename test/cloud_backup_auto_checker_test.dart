import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';
import 'package:utang_tracker/features/backup/domain/repositories/cloud_backup_repository.dart';
import 'package:utang_tracker/features/backup/presentation/providers/cloud_backup_providers.dart';
import 'package:utang_tracker/features/backup/presentation/widgets/cloud_backup_auto_checker.dart';

void main() {
  testWidgets('does not check Google Drive on startup', (tester) async {
    final repository = _LifecycleBackupRepository(isSignedIn: false);
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

    expect(repository.statusCalls, 0);
    expect(repository.backupCalls, 0);
  });

  testWidgets('checks after explicit sign-in and when the app resumes', (
    tester,
  ) async {
    final repository = _LifecycleBackupRepository(isSignedIn: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Column(
            children: [
              CloudBackupAutoChecker(child: SizedBox()),
              _SignInButton(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
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
      isSignedIn: false,
      interval: BackupInterval.weekly,
      lastBackupAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              CloudBackupAutoChecker(child: SizedBox()),
              _SignInButton(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repository.backupCalls, 0);
  });

  testWidgets('backs up after the weekly interval is due', (tester) async {
    final repository = _LifecycleBackupRepository(
      isSignedIn: false,
      interval: BackupInterval.weekly,
      lastBackupAt: DateTime.now().subtract(const Duration(days: 8)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              CloudBackupAutoChecker(child: SizedBox()),
              _SignInButton(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repository.backupCalls, 1);
  });

  testWidgets('does not back up before the 6-hour interval is due', (
    tester,
  ) async {
    final repository = _LifecycleBackupRepository(
      isSignedIn: false,
      interval: BackupInterval.everySixHours,
      lastBackupAt: DateTime.now().subtract(const Duration(hours: 5)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              CloudBackupAutoChecker(child: SizedBox()),
              _SignInButton(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repository.backupCalls, 0);
  });

  testWidgets('backs up after the 6-hour interval is due', (tester) async {
    final repository = _LifecycleBackupRepository(
      isSignedIn: false,
      interval: BackupInterval.everySixHours,
      lastBackupAt: DateTime.now().subtract(const Duration(hours: 7)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              CloudBackupAutoChecker(child: SizedBox()),
              _SignInButton(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repository.backupCalls, 1);
  });

  testWidgets('backs up every 6 hours within the same day', (tester) async {
    final repository = _LifecycleBackupRepository(
      isSignedIn: false,
      interval: BackupInterval.everySixHours,
      lastBackupAt: DateTime.now().subtract(const Duration(hours: 7)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Column(
            children: [
              CloudBackupAutoChecker(child: SizedBox()),
              _SignInButton(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repository.backupCalls, 2);
  });

  testWidgets('waits 24 hours instead of a new calendar day', (tester) async {
    final repository = _LifecycleBackupRepository(
      isSignedIn: false,
      lastBackupAt: DateTime.now().subtract(const Duration(hours: 23)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              CloudBackupAutoChecker(child: SizedBox()),
              _SignInButton(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repository.backupCalls, 0);
  });
}

class _SignInButton extends ConsumerWidget {
  const _SignInButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => ref.read(cloudBackupNotifierProvider.notifier).signIn(),
      child: const Text('Sign in'),
    );
  }
}

class _LifecycleBackupRepository implements CloudBackupRepository {
  _LifecycleBackupRepository({
    required bool isSignedIn,
    this.interval = BackupInterval.daily,
    DateTime? lastBackupAt,
  }) : isSignedIn = isSignedIn,
       lastBackupAt =
           lastBackupAt ?? DateTime.now().subtract(const Duration(days: 1));

  bool isSignedIn;
  int statusCalls = 0;
  int backupCalls = 0;
  final BackupInterval interval;
  final DateTime lastBackupAt;

  @override
  Future<BackupStatus> getStatus() async {
    statusCalls++;
    return _status;
  }

  @override
  Future<BackupStatus> signIn() async {
    isSignedIn = true;
    return _status;
  }

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
    isSignedIn: isSignedIn,
    lastBackupAt: lastBackupAt,
    interval: interval,
  );
}
