import 'package:utang_tracker/features/import/domain/entities/import_file.dart';

/// Reads CSV files chosen by the user.
abstract class CsvFilePicker {
  /// Returns the picked files, or an empty list when the user cancelled.
  Future<List<ImportFile>> pickCsvFiles();
}
