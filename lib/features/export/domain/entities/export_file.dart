/// A file produced by an export, ready to be written and shared.
class ExportFile {
  const ExportFile({required this.fileName, required this.content});

  final String fileName;
  final String content;
}
