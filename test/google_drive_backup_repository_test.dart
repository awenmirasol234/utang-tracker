import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/backup/data/repositories/google_drive_backup_repository.dart';
import 'package:utang_tracker/features/backup/data/services/database_backup_service.dart';
import 'package:utang_tracker/features/backup/data/services/google_drive_client.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';

void main() {
  late Directory temporaryDirectory;
  late AppDatabase database;
  late DatabaseBackupService backupService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'utang_tracker_backup_test_',
    );
    database = AppDatabase.forTesting();
    backupService = DatabaseBackupService(
      database,
      temporaryDirectory: () async => temporaryDirectory,
      liveDatabaseFile: () async =>
          File('${temporaryDirectory.path}/live.sqlite'),
    );
  });

  tearDown(() async {
    await database.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('uploads a snapshot and records the backup time', () async {
    final client = _FakeGoogleDriveClient(
      account: const GoogleDriveAccount(
        id: 'account-1',
        email: 'owner@example.com',
      ),
    );
    final repository = GoogleDriveBackupRepository(
      backupService,
      client: client,
      temporaryDirectory: () async => temporaryDirectory,
    );

    final status = await repository.backup(interactive: false);

    expect(client.uploadedSnapshotExisted, isTrue);
    expect(client.lastInteractive, isFalse);
    expect(status.isSignedIn, isTrue);
    expect(status.hasCloudBackup, isTrue);
    expect(status.lastBackupAt, isNotNull);
  });

  test('cleans up a snapshot when upload fails', () async {
    final client = _FakeGoogleDriveClient(
      account: const GoogleDriveAccount(
        id: 'account-1',
        email: 'owner@example.com',
      ),
      uploadError: const AppException('upload failed'),
    );
    final repository = GoogleDriveBackupRepository(
      backupService,
      client: client,
      temporaryDirectory: () async => temporaryDirectory,
    );

    await expectLater(
      repository.backup(interactive: true),
      throwsA(isA<AppException>()),
    );
    expect(client.uploadedSnapshotPath, isNotNull);
    expect(await File(client.uploadedSnapshotPath!).exists(), isFalse);
  });

  test('keeps the five newest cloud backups', () async {
    final now = DateTime.now();
    final client = _FakeGoogleDriveClient(
      account: const GoogleDriveAccount(
        id: 'account-1',
        email: 'owner@example.com',
      ),
      backups: List<GoogleDriveBackupFile>.generate(
        5,
        (index) => GoogleDriveBackupFile(
          id: 'backup-$index',
          name: 'utang_tracker_backup_$index.sqlite',
          modifiedAt: now.subtract(Duration(days: 5 - index)),
          sizeBytes: 1024,
        ),
      ),
    );
    final repository = GoogleDriveBackupRepository(
      backupService,
      client: client,
      temporaryDirectory: () async => temporaryDirectory,
    );

    final status = await repository.backup(interactive: false);

    expect(status.backups, hasLength(5));
    expect(status.backups.any((backup) => backup.id == 'backup-0'), isFalse);
    expect(status.backups.any((backup) => backup.id == 'backup-4'), isTrue);
  });

  test('persists the selected backup interval', () async {
    final client = _FakeGoogleDriveClient(
      account: const GoogleDriveAccount(
        id: 'account-1',
        email: 'owner@example.com',
      ),
    );
    final repository = GoogleDriveBackupRepository(
      backupService,
      client: client,
      temporaryDirectory: () async => temporaryDirectory,
    );

    final status = await repository.setInterval(BackupInterval.weekly);

    expect(status.interval, BackupInterval.weekly);
  });

  test('includes the existing latest backup in history', () async {
    final client = _FakeGoogleDriveClient(
      account: const GoogleDriveAccount(
        id: 'account-1',
        email: 'owner@example.com',
      ),
      backups: [
        GoogleDriveBackupFile(
          id: 'legacy-backup',
          name: 'utang_tracker_latest.sqlite',
          modifiedAt: DateTime(2026, 10, 20),
          sizeBytes: 2048,
        ),
      ],
    );
    final repository = GoogleDriveBackupRepository(
      backupService,
      client: client,
      temporaryDirectory: () async => temporaryDirectory,
    );

    final status = await repository.getStatus();

    expect(status.backups.single.name, 'utang_tracker_latest.sqlite');
  });

  test('downloads and replaces the local database', () async {
    final cloudSnapshot = await backupService.createSnapshot();
    final liveFile = File('${temporaryDirectory.path}/live.sqlite');
    await cloudSnapshot.copy(liveFile.path);
    final backup = GoogleDriveBackupFile(
      id: 'backup-1',
      name: 'utang_tracker_backup_1.sqlite',
      modifiedAt: DateTime.now(),
      sizeBytes: await cloudSnapshot.length(),
    );
    final client = _FakeGoogleDriveClient(
      account: const GoogleDriveAccount(
        id: 'account-1',
        email: 'owner@example.com',
      ),
      downloadSource: cloudSnapshot,
      backups: [backup],
    );
    final repository = GoogleDriveBackupRepository(
      backupService,
      client: client,
      temporaryDirectory: () async => temporaryDirectory,
    );

    final status = await repository.restore(
      BackupRecord(
        id: backup.id,
        name: backup.name,
        modifiedAt: backup.modifiedAt,
        sizeBytes: backup.sizeBytes,
      ),
    );

    expect(status.isSignedIn, isTrue);
    expect(client.downloadInteractive, isTrue);
    expect(await liveFile.exists(), isTrue);
    await backupService.validate(liveFile);
  });
}

class _FakeGoogleDriveClient implements GoogleDriveClient {
  _FakeGoogleDriveClient({
    required this.account,
    this.uploadError,
    this.downloadSource,
    List<GoogleDriveBackupFile>? backups,
  }) : backups = backups ?? [];

  final GoogleDriveAccount account;
  final AppException? uploadError;
  final File? downloadSource;
  final List<GoogleDriveBackupFile> backups;
  String? uploadedSnapshotPath;
  bool uploadedSnapshotExisted = false;
  bool? lastInteractive;
  bool? downloadInteractive;

  @override
  Future<List<GoogleDriveBackupFile>> listBackups() async => backups;

  @override
  Future<GoogleDriveAccount?> currentAccount() async => account;

  @override
  Future<GoogleDriveAccount> signIn() async => account;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> upload(
    File snapshot, {
    required String fileName,
    required bool interactive,
  }) async {
    uploadedSnapshotPath = snapshot.path;
    uploadedSnapshotExisted = await snapshot.exists();
    lastInteractive = interactive;
    final error = uploadError;
    if (error != null) throw error;
    backups.add(
      GoogleDriveBackupFile(
        id: 'backup-${backups.length + 1}',
        name: fileName,
        modifiedAt: DateTime.now(),
        sizeBytes: await snapshot.length(),
      ),
    );
  }

  @override
  Future<void> download(
    File destination, {
    required String backupId,
    required bool interactive,
  }) async {
    downloadInteractive = interactive;
    await downloadSource!.copy(destination.path);
  }

  @override
  Future<void> delete(String backupId) async {
    backups.removeWhere((backup) => backup.id == backupId);
  }
}
