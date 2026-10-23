import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/error/app_exception.dart';

class GoogleDriveAccount {
  const GoogleDriveAccount({required this.id, required this.email});

  final String id;
  final String email;
}

abstract class GoogleDriveClient {
  Future<GoogleDriveAccount?> currentAccount();

  Future<GoogleDriveAccount> signIn();

  Future<void> signOut();

  Future<void> upload(File snapshot, {required bool interactive});

  Future<void> download(File destination, {required bool interactive});
}

class GoogleDriveClientImpl implements GoogleDriveClient {
  GoogleDriveClientImpl({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  static const _backupFileName = 'utang_tracker_latest.sqlite';
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];
  final GoogleSignIn _signIn;
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
  Future<void> upload(File snapshot, {required bool interactive}) async {
    final account = await _requireAccount();
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
          return;
        }
        await api.files.update(
          drive.File(),
          existingFile.id!,
          uploadMedia: media,
        );
      },
    );
  }

  @override
  Future<void> download(File destination, {required bool interactive}) async {
    final account = await _requireAccount();
    await _withDriveApi(
      account,
      interactive: interactive,
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
          throw const AppException('The cloud backup could not be downloaded.');
        }
        final sink = destination.openWrite();
        await response.stream.pipe(sink);
        await sink.close();
      },
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

  Future<drive.File?> _findBackup(drive.DriveApi api) async {
    final result = await api.files.list(
      q: "name = '$_backupFileName' and trashed = false",
      spaces: 'drive',
      pageSize: 1,
      $fields: 'files(id,name,modifiedTime,size)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
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
