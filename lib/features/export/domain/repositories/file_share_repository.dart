import 'package:utang_tracker/features/export/domain/entities/export_file.dart';

abstract class FileShareRepository {
  /// Writes the files to disk and hands them to the platform share sheet.
  Future<void> shareFiles(List<ExportFile> files);
}
