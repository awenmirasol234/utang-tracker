import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:utang_tracker/features/backup/data/services/google_drive_backup_folder.dart';

void main() {
  test('moves existing root backups into the existing backup folder', () async {
    final client = _FakeDriveHttpClient();
    final folder = const GoogleDriveBackupFolder();

    final folderId = await folder.ensure(drive.DriveApi(client));

    expect(folderId, 'folder-1');
    final updateRequests = client.requests
        .where((request) => request.method == 'PATCH')
        .toList();
    expect(updateRequests, hasLength(2));
    for (final request in updateRequests) {
      expect(request.query['addParents'], 'folder-1');
      expect(request.query['removeParents'], 'root');
    }
  });

  test('creates the backup folder in the Drive root', () async {
    final client = _FakeDriveHttpClient(folderExists: false, rootBackups: []);
    final folder = const GoogleDriveBackupFolder();

    final folderId = await folder.ensure(drive.DriveApi(client));

    expect(folderId, 'folder-created');
    final createRequest = client.requests.firstWhere(
      (request) => request.method == 'POST',
    );
    expect(createRequest.body['name'], 'Utang Tracker Backups');
    expect(
      createRequest.body['mimeType'],
      'application/vnd.google-apps.folder',
    );
    expect(createRequest.body['parents'], ['root']);
  });
}

class _FakeDriveHttpClient extends http.BaseClient {
  _FakeDriveHttpClient({
    this.folderExists = true,
    this.rootBackups = const [
      {'id': 'backup-1', 'name': 'utang_tracker_latest.sqlite'},
      {'id': 'backup-2', 'name': 'utang_tracker_backup_2.sqlite'},
    ],
  });

  final bool folderExists;
  final List<Map<String, dynamic>> rootBackups;
  final requests = <_DriveRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().bytesToString();
    final requestRecord = _DriveRequest(
      method: request.method,
      query: request.url.queryParameters,
      body: body.isEmpty ? <String, dynamic>{} : jsonDecode(body),
    );
    requests.add(requestRecord);

    Map<String, dynamic> responseBody;
    if (request.method == 'GET') {
      final query = request.url.queryParameters['q'] ?? '';
      if (query.contains('mimeType')) {
        responseBody = {
          'files': folderExists
              ? [
                  {'id': 'folder-1'},
                ]
              : [],
        };
      } else {
        responseBody = {'files': rootBackups};
      }
    } else if (request.method == 'POST') {
      responseBody = {'id': 'folder-created'};
    } else {
      responseBody = {'id': 'updated'};
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(responseBody))),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _DriveRequest {
  const _DriveRequest({
    required this.method,
    required this.query,
    required this.body,
  });

  final String method;
  final Map<String, String> query;
  final Map<String, dynamic> body;
}
