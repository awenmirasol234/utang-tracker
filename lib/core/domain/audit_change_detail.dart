import 'package:equatable/equatable.dart';

/// One field-level change recorded in an audit log entry.
///
/// [before] is null when the field had no value yet or when the value was
/// removed. [after] is null when the field was removed.
class AuditChangeDetail extends Equatable {
  const AuditChangeDetail({
    required this.field,
    this.before,
    this.after,
  });

  final String field;
  final String? before;
  final String? after;

  @override
  List<Object?> get props => [field, before, after];
}
