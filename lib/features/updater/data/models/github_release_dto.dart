import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';

class GithubReleaseDto {
  static AppRelease fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    var version = tagName;
    if (tagName.startsWith('v')) {
      version = tagName.substring(1);
    }
    final assets = (json['assets'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_assetFromJson)
        .toList(growable: false);

    return AppRelease(
      version: version,
      releaseNotes: json['body'] as String? ?? '',
      isDraft: json['draft'] as bool? ?? false,
      isPrerelease: json['prerelease'] as bool? ?? false,
      assets: assets,
    );
  }

  static ReleaseAsset _assetFromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      sizeBytes: json['size'] as int? ?? 0,
    );
  }
}
