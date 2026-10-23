import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/backup/data/services/database_backup_service.dart';
import 'package:utang_tracker/features/backup/data/services/google_drive_client.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';
import 'package:utang_tracker/features/backup/domain/repositories/cloud_backup_repository.dart';

class GoogleDriveBackupRepository implements CloudBackupRepository {
  GoogleDriveBackupRepository(
    this._databaseBackupService, {
    GoogleDriveClient? client,
    Future<Directory> Function()? temporaryDirectory,
  }) : _client = client ?? GoogleDriveClientImpl(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const _maxBackups = 5;
  static const _lastBackupKeyPrefix = 'cloud_backup_last_';
  static const _hasBackupKeyPrefix = 'cloud_backup_exists_';
  static const _intervalKeyPrefix = 'cloud_backup_interval_';
  static const _lastErrorKeyPrefix = 'cloud_backup_error_';

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
      await _client.upload(
        snapshot,
        fileName: _backupFileName(),
        interactive: interactive,
      );
      await _saveBackupSuccess(account.id);
      await _removeOldBackups();
      return await _status(account);
    } catch (error) {
      await _saveBackupFailure(account.id, error);
      rethrow;
    } finally {
      if (await snapshot.exists()) {
        await snapshot.delete();
      }
    }
  }

  @override
  Future<BackupStatus> restore(BackupRecord backup) async {
    final account = await _client.currentAccount();
    if (account == null) {
      throw const AppException('Sign in to Google Drive before restoring.');
    }

    final availableBackups = await _client.listBackups();
    final selectedBackup = _findBackup(availableBackups, backup.id);
    if (selectedBackup == null) {
      throw const AppException(
        'The selected cloud backup is no longer available.',
      );
    }

    final temporaryRoot = await _temporaryDirectory();
    final temporaryDirectory = await temporaryRoot.createTemp(
      'utang_tracker_restore_',
    );
    final snapshot = File('${temporaryDirectory.path}/backup.sqlite');
    try {
      await _client.download(
        snapshot,
        backupId: selectedBackup.id,
        interactive: true,
      );
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

  @override
  Future<BackupStatus> setInterval(BackupInterval interval) async {
    final account = await _client.currentAccount();
    if (account == null) {
      throw const AppException(
        'Sign in to Google Drive before changing backup settings.',
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_intervalKey(account.id), interval.name);
    return _status(account);
  }

  Future<BackupStatus> _status(GoogleDriveAccount? account) async {
    if (account == null) {
      return const BackupStatus(isSignedIn: false);
    }
    final preferences = await SharedPreferences.getInstance();
    final cloudFiles = await _client.listBackups();
    cloudFiles.sort(_compareFiles);
    final backups = cloudFiles
        .map(
          (file) => BackupRecord(
            id: file.id,
            name: file.name,
            modifiedAt: file.modifiedAt,
            sizeBytes: file.sizeBytes,
          ),
        )
        .toList(growable: false);
    final lastBackupAt = _lastBackupAt(account.id, backups, preferences);
    return BackupStatus(
      isSignedIn: true,
      email: account.email,
      lastBackupAt: lastBackupAt,
      hasCloudBackup: backups.isNotEmpty,
      backups: backups,
      interval: _readInterval(preferences.getString(_intervalKey(account.id))),
      lastBackupError: preferences.getString(_lastErrorKey(account.id)),
    );
  }

  Future<void> _removeOldBackups() async {
    final backups = await _client.listBackups();
    backups.sort(_compareFiles);
    if (backups.length <= _maxBackups) return;

    for (var index = _maxBackups; index < backups.length; index++) {
      await _client.delete(backups[index].id);
    }
  }

  Future<void> _saveBackupSuccess(String accountId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastBackupKey(accountId),
      DateTime.now().toIso8601String(),
    );
    await preferences.setBool(_hasBackupKey(accountId), true);
    await preferences.remove(_lastErrorKey(accountId));
  }

  Future<void> _saveBackupFailure(String accountId, Object error) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      String message;
      if (error is AppException) {
        message = error.message;
      } else {
        message = 'Backup failed. Please try again.';
      }
      await preferences.setString(_lastErrorKey(accountId), message);
    } catch (_) {
      // Preserve the original backup error if local status storage fails.
    }
  }

  DateTime? _lastBackupAt(
    String accountId,
    List<BackupRecord> backups,
    SharedPreferences preferences,
  ) {
    for (final backup in backups) {
      final modifiedAt = backup.modifiedAt;
      if (modifiedAt != null) return modifiedAt;
    }
    final savedValue = preferences.getString(_lastBackupKey(accountId));
    if (savedValue == null) return null;
    return DateTime.tryParse(savedValue);
  }

  BackupInterval _readInterval(String? value) {
    for (final interval in BackupInterval.values) {
      if (interval.name == value) return interval;
    }
    return BackupInterval.daily;
  }

  BackupRecord? _findBackup(
    List<GoogleDriveBackupFile> backups,
    String backupId,
  ) {
    for (final backup in backups) {
      if (backup.id == backupId) {
        return BackupRecord(
          id: backup.id,
          name: backup.name,
          modifiedAt: backup.modifiedAt,
          sizeBytes: backup.sizeBytes,
        );
      }
    }
    return null;
  }

  int _compareFiles(GoogleDriveBackupFile left, GoogleDriveBackupFile right) {
    final leftTime = left.modifiedAt;
    final rightTime = right.modifiedAt;
    if (leftTime == null && rightTime == null) return 0;
    if (leftTime == null) return 1;
    if (rightTime == null) return -1;
    return rightTime.compareTo(leftTime);
  }

  String _backupFileName() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'utang_tracker_backup_$timestamp.sqlite';
  }

  String _lastBackupKey(String accountId) => '$_lastBackupKeyPrefix$accountId';

  String _hasBackupKey(String accountId) => '$_hasBackupKeyPrefix$accountId';

  String _intervalKey(String accountId) => '$_intervalKeyPrefix$accountId';

  String _lastErrorKey(String accountId) => '$_lastErrorKeyPrefix$accountId';
}
