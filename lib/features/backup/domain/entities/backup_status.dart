import 'package:equatable/equatable.dart';

class BackupStatus extends Equatable {
  const BackupStatus({
    required this.isSignedIn,
    this.email,
    this.lastBackupAt,
    this.hasCloudBackup = false,
  });

  final bool isSignedIn;
  final String? email;
  final DateTime? lastBackupAt;
  final bool hasCloudBackup;

  @override
  List<Object?> get props => [isSignedIn, email, lastBackupAt, hasCloudBackup];
}
