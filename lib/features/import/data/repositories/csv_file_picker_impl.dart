import 'package:flutter/services.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/features/import/domain/entities/import_file.dart';
import 'package:utang_tracker/features/import/domain/repositories/csv_file_picker.dart';

class MethodChannelCsvFilePickerImpl implements CsvFilePicker {
  const MethodChannelCsvFilePickerImpl();

  @override
  Future<List<ImportFile>> pickCsvFiles() async {
    final result = await const MethodChannel(
      AppConstants.importChannel,
    ).invokeMethod<List<Object?>>('pickCsvFiles');
    if (result == null) {
      return const [];
    }

    final files = <ImportFile>[];
    for (final entry in result) {
      if (entry is! Map) {
        continue;
      }
      var name = 'import.csv';
      final entryName = entry['name'];
      if (entryName is String) {
        name = entryName;
      }
      var content = '';
      final entryContent = entry['content'];
      if (entryContent is String) {
        content = entryContent;
      }
      files.add(ImportFile(name: name, content: content));
    }
    return files;
  }
}
