import 'package:equatable/equatable.dart';

/// A problem found in one row of an imported file.
class ImportIssue extends Equatable {
  const ImportIssue({
    required this.fileName,
    required this.rowNumber,
    required this.message,
  });

  final String fileName;

  /// 1-based line number in the file, where the header row is line 1.
  final int rowNumber;
  final String message;

  @override
  List<Object?> get props => [fileName, rowNumber, message];

  @override
  String toString() => '$fileName row $rowNumber: $message';
}
