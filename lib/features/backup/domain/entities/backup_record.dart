import 'package:equatable/equatable.dart';

class BackupRecord extends Equatable {
  const BackupRecord({
    required this.id,
    required this.name,
    this.modifiedAt,
    this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime? modifiedAt;
  final int? sizeBytes;

  @override
  List<Object?> get props => [id, name, modifiedAt, sizeBytes];
}
