import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/backup/data/services/database_backup_service.dart';
import 'package:utang_tracker/features/backup/data/services/google_drive_client.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';
import 'package:utang_tracker/features/backup/domain/repositories/cloud_backup_repository.dart';

class GoogleDriveBackupRepository implements CloudBackupRepository {
  GoogleDriveBackupRepository(
    this._databaseBackupService, {
    GoogleDriveClient? client,
    Future<Directory> Function()? temporaryDirectory,
  }) : _client = client ?? GoogleDriveClientImpl(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const _lastBackupKeyPrefix = 'cloud_backup_last_';
  static const _hasBackupKeyPrefix = 'cloud_backup_exists_';

  final DatabaseBackupService _databaseBackupService;
  final GoogleDriveClient _client;
  final Future<Directory> Function() _temporaryDirectory;

  @override
  Future<BackupStatus> getStatus() async {
    final account = await _client.currentAccount();
    return _status(account);
  }

  @override
  Future<BackupStatus> signIn() async {
    final account = await _client.signIn();
    return _status(account);
  }

  @override
  Future<void> signOut() => _client.signOut();

  @override
  Future<BackupStatus> backup({required bool interactive}) async {
    final account = await _client.currentAccount();
    if (account == null) {
      throw const AppException('Sign in to Google Drive before backing up.');
    }

    final snapshot = await _databaseBackupService.createSnapshot();
    try {
      await _client.upload(snapshot, interactive: interactive);
      await _saveBackupTime(account.id);
      return await _status(account);
    } finally {
      if (await snapshot.exists()) {
        await snapshot.delete();
      }
    }
  }

  @override
  Future<BackupStatus> restore() async {
    final account = await _client.currentAccount();
    if (account == null) {
      throw const AppException('Sign in to Google Drive before restoring.');
    }

    final temporaryRoot = await _temporaryDirectory();
    final temporaryDirectory = await temporaryRoot.createTemp(
      'utang_tracker_restore_',
    );
    final snapshot = File('${temporaryDirectory.path}/backup.sqlite');
    try {
      await _client.download(snapshot, interactive: true);
      await _databaseBackupService.validate(snapshot);
      await _databaseBackupService.closeDatabase();
      await _databaseBackupService.replaceLiveDatabase(snapshot);
      return await _status(account);
    } finally {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  }

  Future<BackupStatus> _status(GoogleDriveAccount? account) async {
    if (account == null) {
      return const BackupStatus(isSignedIn: false);
    }
    final preferences = await SharedPreferences.getInstance();
    final lastBackupValue = preferences.getString(_lastBackupKey(account.id));
    DateTime? lastBackupAt;
    if (lastBackupValue != null) {
      lastBackupAt = DateTime.tryParse(lastBackupValue);
    }
    return BackupStatus(
      isSignedIn: true,
      email: account.email,
      lastBackupAt: lastBackupAt,
      hasCloudBackup: preferences.getBool(_hasBackupKey(account.id)) ?? false,
    );
  }

  Future<void> _saveBackupTime(String accountId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastBackupKey(accountId),
      DateTime.now().toIso8601String(),
    );
    await preferences.setBool(_hasBackupKey(accountId), true);
  }

  String _lastBackupKey(String accountId) => '$_lastBackupKeyPrefix$accountId';

  String _hasBackupKey(String accountId) => '$_hasBackupKeyPrefix$accountId';
}
