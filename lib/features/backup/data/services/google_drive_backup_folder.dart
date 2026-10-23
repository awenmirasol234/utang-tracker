import 'package:googleapis/drive/v3.dart' as drive;
import 'package:utang_tracker/core/error/app_exception.dart';

class GoogleDriveBackupFolder {
  const GoogleDriveBackupFolder();

  static const legacyBackupFileName = 'utang_tracker_latest.sqlite';
  static const backupFilePrefix = 'utang_tracker_backup_';
  static const backupFolderName = 'Utang Tracker Backups';
  static const _folderMimeType = 'application/vnd.google-apps.folder';

  String backupQuery(String folderId) {
    return "'$folderId' in parents and trashed = false and "
        "(name = '$legacyBackupFileName' or name contains '$backupFilePrefix')";
  }

  bool isBackupFileName(String name) {
    return name == legacyBackupFileName || name.startsWith(backupFilePrefix);
  }

  Future<String> ensure(drive.DriveApi api) async {
    final result = await api.files.list(
      q:
          "mimeType = '$_folderMimeType' and name = '$backupFolderName' and "
          "'root' in parents and trashed = false",
      spaces: 'drive',
      pageSize: 10,
      $fields: 'files(id)',
    );
    for (final file in result.files ?? const <drive.File>[]) {
      final folderId = file.id;
      if (folderId != null) {
        await _moveRootBackups(api, folderId);
        return folderId;
      }
    }

    final folder = await api.files.create(
      drive.File()
        ..name = backupFolderName
        ..mimeType = _folderMimeType
        ..parents = ['root'],
      $fields: 'id',
    );
    final folderId = folder.id;
    if (folderId == null) {
      throw const AppException(
        'The Google Drive backup folder could not be created.',
      );
    }
    await _moveRootBackups(api, folderId);
    return folderId;
  }

  Future<void> _moveRootBackups(drive.DriveApi api, String folderId) async {
    final backupIds = <String>[];
    String? pageToken;
    do {
      final result = await api.files.list(
        q:
            "'root' in parents and trashed = false and "
            "(name = '$legacyBackupFileName' or name contains '$backupFilePrefix')",
        spaces: 'drive',
        pageSize: 100,
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,name)',
      );
      for (final file in result.files ?? const <drive.File>[]) {
        final backupId = file.id;
        final name = file.name;
        if (backupId != null && name != null && isBackupFileName(name)) {
          backupIds.add(backupId);
        }
      }
      pageToken = result.nextPageToken;
    } while (pageToken != null);

    for (final backupId in backupIds) {
      await api.files.update(
        drive.File(),
        backupId,
        addParents: folderId,
        removeParents: 'root',
      );
    }
  }
}
