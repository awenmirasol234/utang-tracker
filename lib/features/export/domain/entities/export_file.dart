import 'package:equatable/equatable.dart';

/// A file produced by an export, ready to be written and shared.
class ExportFile extends Equatable {
  const ExportFile({required this.fileName, required this.content});

  final String fileName;
  final String content;

  @override
  List<Object?> get props => [fileName, content];
}
