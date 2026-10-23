import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/backup/data/services/database_backup_service.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';
import 'package:utang_tracker/features/backup/domain/repositories/cloud_backup_repository.dart';

class GoogleDriveBackupRepository implements CloudBackupRepository {
  GoogleDriveBackupRepository(this._databaseBackupService);

  static const _backupFileName = 'utang_tracker_latest.sqlite';
  static const _lastBackupKeyPrefix = 'cloud_backup_last_';
  static const _hasBackupKeyPrefix = 'cloud_backup_exists_';
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];

  static Future<void>? _initialization;

  final DatabaseBackupService _databaseBackupService;
  final GoogleSignIn _signIn = GoogleSignIn.instance;

  GoogleSignInAccount? _account;
  bool _attemptedLightweightAuthentication = false;

  Future<void> _ensureInitialized() async {
    if (_initialization == null) {
      final serverClientId = AppConstants.googleDriveServerClientId;
      if (serverClientId.isEmpty) {
        _initialization = _signIn.initialize();
      } else {
        _initialization = _signIn.initialize(serverClientId: serverClientId);
      }
    }
    await _initialization;

    if (_attemptedLightweightAuthentication) {
      return;
    }
    _attemptedLightweightAuthentication = true;
    final authentication = _signIn.attemptLightweightAuthentication();
    if (authentication != null) {
      _account = await authentication;
    }
  }

  @override
  Future<BackupStatus> getStatus() async {
    await _ensureInitialized();
    return _status();
  }

  @override
  Future<BackupStatus> signIn() async {
    await _ensureInitialized();
    final account = await _signIn.authenticate(scopeHint: _scopes);
    _account = account;
    await account.authorizationClient.authorizeScopes(_scopes);
    return _status();
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _signIn.signOut();
    _account = null;
  }

  @override
  Future<BackupStatus> backup({required bool interactive}) async {
    await _ensureInitialized();
    final account = _account;
    if (account == null) {
      throw const AppException('Sign in to Google Drive before backing up.');
    }

    final snapshot = await _databaseBackupService.createSnapshot();
    try {
      await _withDriveApi(
        account,
        interactive: interactive,
        action: (api) async {
          final existingFile = await _findBackup(api);
          final media = drive.Media(
            snapshot.openRead(),
            await snapshot.length(),
            contentType: 'application/x-sqlite3',
          );
          if (existingFile == null) {
            final metadata = drive.File()
              ..name = _backupFileName
              ..description = 'Utang Tracker database backup';
            await api.files.create(metadata, uploadMedia: media);
          } else {
            await api.files.update(
              drive.File(),
              existingFile.id!,
              uploadMedia: media,
            );
          }
        },
      );
      await _saveBackupTime(account.id);
      return await _status();
    } finally {
      if (await snapshot.exists()) {
        await snapshot.delete();
      }
    }
  }

  @override
  Future<BackupStatus> restore() async {
    await _ensureInitialized();
    final account = _account;
    if (account == null) {
      throw const AppException('Sign in to Google Drive before restoring.');
    }

    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'utang_tracker_restore_',
    );
    final snapshot = File('${temporaryDirectory.path}/backup.sqlite');
    try {
      await _withDriveApi(
        account,
        interactive: true,
        action: (api) async {
          final backupFile = await _findBackup(api);
          if (backupFile == null || backupFile.id == null) {
            throw const AppException('No Utang Tracker backup was found.');
          }
          final response = await api.files.get(
            backupFile.id!,
            downloadOptions: drive.DownloadOptions.fullMedia,
          );
          if (response is! drive.Media) {
            throw const AppException(
              'The cloud backup could not be downloaded.',
            );
          }
          final sink = snapshot.openWrite();
          await response.stream.pipe(sink);
          await sink.close();
        },
      );
      await _databaseBackupService.validate(snapshot);
      await _databaseBackupService.closeDatabase();
      await _databaseBackupService.replaceLiveDatabase(snapshot);
      return await _status();
    } finally {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  }

  Future<BackupStatus> _status() async {
    final account = _account;
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

  Future<drive.File?> _findBackup(drive.DriveApi api) async {
    final result = await api.files.list(
      q: "name = '$_backupFileName' and trashed = false",
      spaces: 'drive',
      pageSize: 1,
      $fields: 'files(id,name,modifiedTime,size)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) {
      return null;
    }
    return files.first;
  }

  Future<T> _withDriveApi<T>(
    GoogleSignInAccount account, {
    required bool interactive,
    required Future<T> Function(drive.DriveApi api) action,
  }) async {
    final client = _AuthorizedClient(() async {
      final headers = await account.authorizationClient.authorizationHeaders(
        _scopes,
        promptIfNecessary: interactive,
      );
      if (headers == null) {
        throw const AppException(
          'Google Drive permission is required to access backups.',
        );
      }
      return headers;
    });
    try {
      return await action(drive.DriveApi(client));
    } finally {
      client.close();
    }
  }
}

class _AuthorizedClient extends http.BaseClient {
  _AuthorizedClient(this._headers);

  final Future<Map<String, String>> Function() _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(await _headers());
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
