import 'package:equatable/equatable.dart';

class ReleaseAsset extends Equatable {
  const ReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.sizeBytes,
  });

  final String name;
  final String browserDownloadUrl;
  final int sizeBytes;

  @override
  List<Object?> get props => [name, browserDownloadUrl, sizeBytes];
}

class AppRelease extends Equatable {
  const AppRelease({
    required this.version,
    required this.releaseNotes,
    required this.isDraft,
    required this.isPrerelease,
    required this.assets,
  });

  final String version;
  final String releaseNotes;
  final bool isDraft;
  final bool isPrerelease;
  final List<ReleaseAsset> assets;

  @override
  List<Object?> get props => [
    version,
    releaseNotes,
    isDraft,
    isPrerelease,
    assets,
  ];
}

class PendingApk extends Equatable {
  const PendingApk({required this.version, required this.apkPath});

  final String version;
  final String apkPath;

  @override
  List<Object?> get props => [version, apkPath];
}
