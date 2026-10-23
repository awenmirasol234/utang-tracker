import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/backup/data/repositories/google_drive_backup_repository.dart';
import 'package:utang_tracker/features/backup/data/services/database_backup_service.dart';
import 'package:utang_tracker/features/backup/data/services/google_drive_client.dart';

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

  test('downloads and replaces the local database', () async {
    final cloudSnapshot = await backupService.createSnapshot();
    final liveFile = File('${temporaryDirectory.path}/live.sqlite');
    await cloudSnapshot.copy(liveFile.path);
    final client = _FakeGoogleDriveClient(
      account: const GoogleDriveAccount(
        id: 'account-1',
        email: 'owner@example.com',
      ),
      downloadSource: cloudSnapshot,
    );
    final repository = GoogleDriveBackupRepository(
      backupService,
      client: client,
      temporaryDirectory: () async => temporaryDirectory,
    );

    final status = await repository.restore();

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
  });

  final GoogleDriveAccount account;
  final AppException? uploadError;
  final File? downloadSource;
  String? uploadedSnapshotPath;
  bool uploadedSnapshotExisted = false;
  bool? lastInteractive;
  bool? downloadInteractive;

  @override
  Future<GoogleDriveAccount?> currentAccount() async => account;

  @override
  Future<GoogleDriveAccount> signIn() async => account;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> upload(File snapshot, {required bool interactive}) async {
    uploadedSnapshotPath = snapshot.path;
    uploadedSnapshotExisted = await snapshot.exists();
    lastInteractive = interactive;
    final error = uploadError;
    if (error != null) throw error;
  }

  @override
  Future<void> download(File destination, {required bool interactive}) async {
    downloadInteractive = interactive;
    await downloadSource!.copy(destination.path);
  }
}
