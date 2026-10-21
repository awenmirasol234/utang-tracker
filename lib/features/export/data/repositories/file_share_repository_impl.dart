import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/export/domain/entities/export_file.dart';
import 'package:utang_tracker/features/export/domain/repositories/file_share_repository.dart';

class FileShareRepositoryImpl implements FileShareRepository {
  const FileShareRepositoryImpl();

  @override
  Future<void> shareFiles(List<ExportFile> files) async {
    if (files.isEmpty) {
      throw const ValidationException('Nothing to export.');
    }

    final storage = await getExternalStorageDirectory();
    if (storage == null) {
      throw const AppException('Could not access device storage.');
    }

    // The FileProvider in the manifest maps the whole external storage root,
    // so files written here can be shared without extra manifest changes.
    final exportDirectory = Directory('${storage.path}/exports');
    await exportDirectory.create(recursive: true);

    final paths = <String>[];
    for (final file in files) {
      final target = File('${exportDirectory.path}/${file.fileName}');
      await target.writeAsString(file.content);
      paths.add(target.path);
    }

    await const MethodChannel(AppConstants.exportChannel).invokeMethod<void>(
      'shareFiles',
      {'paths': paths, 'mimeType': 'text/csv'},
    );
  }
}
