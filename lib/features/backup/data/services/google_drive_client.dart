import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/backup/data/services/google_drive_backup_folder.dart';

class GoogleDriveAccount {
  const GoogleDriveAccount({required this.id, required this.email});

  final String id;
  final String email;
}

class GoogleDriveBackupFile {
  const GoogleDriveBackupFile({
    required this.id,
    required this.name,
    this.modifiedAt,
    this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime? modifiedAt;
  final int? sizeBytes;
}

abstract class GoogleDriveClient {
  Future<GoogleDriveAccount?> currentAccount();

  Future<GoogleDriveAccount> signIn();

  Future<void> signOut();

  Future<List<GoogleDriveBackupFile>> listBackups();

  Future<void> upload(
    File snapshot, {
    required String fileName,
    required bool interactive,
  });

  Future<void> download(
    File destination, {
    required String backupId,
    required bool interactive,
  });

  Future<void> delete(String backupId);
}

class GoogleDriveClientImpl implements GoogleDriveClient {
  GoogleDriveClientImpl({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];
  final GoogleSignIn _signIn;
  final _backupFolder = const GoogleDriveBackupFolder();
  Future<void>? _initialization;
  GoogleSignInAccount? _account;
  bool _attemptedLightweightAuthentication = false;

  @override
  Future<GoogleDriveAccount?> currentAccount() async {
    try {
      await _ensureInitialized();
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    }
    final account = _account;
    if (account == null) return null;
    return GoogleDriveAccount(id: account.id, email: account.email);
  }

  @override
  Future<GoogleDriveAccount> signIn() async {
    await _ensureInitialized();
    try {
      final account = await _authenticate();
      _account = account;
      await account.authorizationClient.authorizeScopes(_scopes);
      return GoogleDriveAccount(id: account.id, email: account.email);
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    }
    await _signIn.signOut();
    _account = null;
  }

  @override
  Future<List<GoogleDriveBackupFile>> listBackups() async {
    final account = await _requireAccount();
    return _withDriveApi(
      account,
      interactive: false,
      action: (api) async {
        final folderId = await _backupFolder.ensure(api);
        final backupFiles = <GoogleDriveBackupFile>[];
        String? pageToken;
        do {
          final result = await api.files.list(
            q: _backupFolder.backupQuery(folderId),
            spaces: 'drive',
            pageSize: 100,
            pageToken: pageToken,
            $fields: 'nextPageToken,files(id,name,modifiedTime,size)',
          );
          final files = result.files ?? const <drive.File>[];
          for (final file in files) {
            final id = file.id;
            final name = file.name;
            if (id == null ||
                name == null ||
                !_backupFolder.isBackupFileName(name)) {
              continue;
            }
            backupFiles.add(
              GoogleDriveBackupFile(
                id: id,
                name: name,
                modifiedAt: file.modifiedTime,
                sizeBytes: int.tryParse(file.size ?? ''),
              ),
            );
          }
          pageToken = result.nextPageToken;
        } while (pageToken != null);
        return backupFiles;
      },
    );
  }

  @override
  Future<void> upload(
    File snapshot, {
    required String fileName,
    required bool interactive,
  }) async {
    final account = await _requireAccount();
    await _withDriveApi(
      account,
      interactive: interactive,
      action: (api) async {
        final folderId = await _backupFolder.ensure(api);
        final media = drive.Media(
          snapshot.openRead(),
          await snapshot.length(),
          contentType: 'application/x-sqlite3',
        );
        final metadata = drive.File()
          ..name = fileName
          ..parents = [folderId]
          ..description = 'Utang Tracker database backup';
        await api.files.create(metadata, uploadMedia: media);
      },
    );
  }

  @override
  Future<void> download(
    File destination, {
    required String backupId,
    required bool interactive,
  }) async {
    final account = await _requireAccount();
    await _withDriveApi(
      account,
      interactive: interactive,
      action: (api) async {
        final response = await api.files.get(
          backupId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        );
        if (response is! drive.Media) {
          throw const AppException('The cloud backup could not be downloaded.');
        }
        final sink = destination.openWrite();
        await response.stream.pipe(sink);
        await sink.close();
      },
    );
  }

  @override
  Future<void> delete(String backupId) async {
    final account = await _requireAccount();
    await _withDriveApi(
      account,
      interactive: false,
      action: (api) => api.files.delete(backupId),
    );
  }

  Future<void> _ensureInitialized() async {
    try {
      if (_initialization == null) {
        final serverClientId = AppConstants.googleDriveServerClientId;
        if (serverClientId.isEmpty) {
          _initialization = _signIn.initialize();
        } else {
          _initialization = _signIn.initialize(serverClientId: serverClientId);
        }
      }
      await _initialization;

      if (_attemptedLightweightAuthentication) return;
      _attemptedLightweightAuthentication = true;
      final authentication = _signIn.attemptLightweightAuthentication();
      if (authentication != null) {
        _account = await authentication;
      }
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    }
  }

  Future<GoogleSignInAccount> _authenticate() async {
    try {
      return await _signIn.authenticate(scopeHint: _scopes);
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    }
  }

  AppException _mapGoogleSignInException(GoogleSignInException error) {
    if (error.code == GoogleSignInExceptionCode.canceled) {
      return const AppException('Google sign-in was cancelled.');
    }
    return const AppException(
      'Google sign-in failed. Check your Google account and try again.',
    );
  }

  Future<GoogleSignInAccount> _requireAccount() async {
    await _ensureInitialized();
    final account = _account;
    if (account == null) {
      throw const AppException('Sign in to Google Drive before continuing.');
    }
    return account;
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
    } on AppException {
      rethrow;
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    } on SocketException {
      throw const AppException('No internet connection.');
    } on TimeoutException {
      throw const AppException('Google Drive request timed out.');
    } on http.ClientException {
      throw const AppException('Google Drive request failed.');
    } catch (_) {
      throw const AppException('Google Drive request failed.');
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
