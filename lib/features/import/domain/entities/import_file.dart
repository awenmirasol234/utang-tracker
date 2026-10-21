import 'package:equatable/equatable.dart';

/// A CSV file the user picked for import.
class ImportFile extends Equatable {
  const ImportFile({required this.name, required this.content});

  final String name;
  final String content;

  @override
  List<Object?> get props => [name, content];
}
