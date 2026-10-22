import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/domain/repositories/update_repository.dart';

const _keyLastCheck = 'updater_last_check_ms';
const _keyDismissedVersion = 'updater_dismissed_version';

class UpdateRepositoryImpl implements UpdateRepository {
  UpdateRepositoryImpl({
    http.Client? httpClient,
    this.updateDirectory,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = httpClient ?? http.Client();

  final http.Client _client;
  final Future<Directory> Function()? updateDirectory;
  final Duration requestTimeout;
  static const _channel = MethodChannel(AppConstants.updaterChannel);

  @override
  Future<AppRelease?> fetchLatestRelease() async {
    final latestUri = Uri.parse(AppConstants.githubLatestReleaseUrl);
    final String tag;
    try {
      final request = http.Request('GET', latestUri);
      request.followRedirects = false;
      final streamed = await _client.send(request).timeout(requestTimeout);
      final location = streamed.headers['location'];
      if (streamed.statusCode >= 300 &&
          streamed.statusCode < 400 &&
          location != null) {
        String normalizedLocation;
        if (location.startsWith('/')) {
          normalizedLocation = 'https://github.com$location';
        } else {
          normalizedLocation = location;
        }
        final locUri = Uri.parse(normalizedLocation);
        final segments = locUri.pathSegments;
        if (segments.isNotEmpty) {
          tag = segments.last;
        } else {
          tag = '';
        }
        await streamed.stream.drain();
      } else if (streamed.statusCode == 200) {
        await streamed.stream.drain();
        return await _fetchFromRawMain();
      } else if (streamed.statusCode == 404) {
        return null;
      } else {
        throw AppException(
          'GitHub error ${streamed.statusCode}. Please try again later.',
        );
      }
    } on SocketException {
      throw const AppException('No internet connection.');
    } on TimeoutException {
      throw const AppException('Network request timed out.');
    } on http.ClientException catch (clientException) {
      throw AppException('Network error: ${clientException.message}');
    }

    if (tag.isEmpty || !tag.startsWith('v')) {
      return _fetchFromRawMain();
    }

    var version = tag;
    if (tag.startsWith('v')) {
      version = tag.substring(1);
    }
    if (version.isEmpty) return null;

    final rawTagUri = Uri.parse(
      'https://raw.githubusercontent.com/${AppConstants.githubOwner}/${AppConstants.githubRepo}/$tag/assets/release_notes/current.json',
    );
    final http.Response rawResponse;
    try {
      rawResponse = await _client
          .get(rawTagUri, headers: {'Accept': 'application/json'})
          .timeout(requestTimeout);
    } on SocketException {
      throw const AppException('No internet connection.');
    } on TimeoutException {
      throw const AppException('Network request timed out.');
    } on http.ClientException catch (clientException) {
      throw AppException('Network error: ${clientException.message}');
    }

    if (rawResponse.statusCode == 404) {
      final tagOnlyNotes = "What's new in v$version";
      final base = '${AppConstants.githubReleasesBaseUrl}/$tag';
      final assets = [
        ReleaseAsset(
          name: '${AppConstants.apkAssetPrefix}-arm64-v8a-$tag.apk',
          browserDownloadUrl:
              '$base/${AppConstants.apkAssetPrefix}-arm64-v8a-$tag.apk',
          sizeBytes: 0,
        ),
        ReleaseAsset(
          name: '${AppConstants.apkAssetPrefix}-armeabi-v7a-$tag.apk',
          browserDownloadUrl:
              '$base/${AppConstants.apkAssetPrefix}-armeabi-v7a-$tag.apk',
          sizeBytes: 0,
        ),
      ];
      return AppRelease(
        version: version,
        releaseNotes: tagOnlyNotes,
        isDraft: false,
        isPrerelease: false,
        assets: assets,
      );
    }
    if (rawResponse.statusCode != 200) {
      throw AppException(
        'GitHub error ${rawResponse.statusCode}. Please try again later.',
      );
    }

    final decoded = jsonDecode(rawResponse.body) as Map<String, dynamic>;
    final effectiveVersion = version;
    final date = decoded['date'] as String? ?? '';
    final notesRaw = decoded['notes'] as Map<String, dynamic>?;

    List<String> stringList(dynamic value) {
      if (value is List) {
        return value.whereType<String>().where((item) => item.isNotEmpty).toList();
      }
      return const [];
    }

    final added = stringList(notesRaw?['added']);
    final changed = stringList(notesRaw?['changed']);
    final fixed = stringList(notesRaw?['fixed']);

    final buffer = StringBuffer()..writeln("What's new in v$effectiveVersion");
    buffer.writeln();
    if (date.isNotEmpty) {
      buffer.writeln('Release date: $date');
      buffer.writeln();
    }

    void writeSection(String title, List<String> items) {
      if (items.isEmpty) return;
      buffer.writeln('## $title');
      for (final item in items) {
        buffer.writeln('- $item');
      }
    }

    writeSection('Added', added);
    writeSection('Changed', changed);
    writeSection('Fixed', fixed);

    final releaseNotes = buffer.toString().trim();

    final base = '${AppConstants.githubReleasesBaseUrl}/$tag';
    final assets = [
      ReleaseAsset(
        name: '${AppConstants.apkAssetPrefix}-arm64-v8a-$tag.apk',
        browserDownloadUrl:
            '$base/${AppConstants.apkAssetPrefix}-arm64-v8a-$tag.apk',
        sizeBytes: 0,
      ),
      ReleaseAsset(
        name: '${AppConstants.apkAssetPrefix}-armeabi-v7a-$tag.apk',
        browserDownloadUrl:
            '$base/${AppConstants.apkAssetPrefix}-armeabi-v7a-$tag.apk',
        sizeBytes: 0,
      ),
    ];

    return AppRelease(
      version: effectiveVersion,
      releaseNotes: releaseNotes,
      isDraft: false,
      isPrerelease: false,
      assets: assets,
    );
  }

  Future<AppRelease?> _fetchFromRawMain() async {
    final uri = Uri.parse(AppConstants.rawReleaseNotesUrl);

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(requestTimeout);
    } on SocketException {
      throw const AppException('No internet connection.');
    } on TimeoutException {
      throw const AppException('Network request timed out.');
    } on http.ClientException catch (clientException) {
      throw AppException('Network error: ${clientException.message}');
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AppException(
        'GitHub error ${response.statusCode}. Please try again later.',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final version = decoded['version'] as String? ?? '';
    if (version.isEmpty) {
      throw const AppException('Invalid release data: missing version.');
    }

    final date = decoded['date'] as String? ?? '';
    final notesRaw = decoded['notes'] as Map<String, dynamic>?;

    List<String> stringList(dynamic value) {
      if (value is List) {
        return value.whereType<String>().where((item) => item.isNotEmpty).toList();
      }
      return const [];
    }

    final added = stringList(notesRaw?['added']);
    final changed = stringList(notesRaw?['changed']);
    final fixed = stringList(notesRaw?['fixed']);

    final buffer = StringBuffer()..writeln("What's new in v$version");
    buffer.writeln();
    if (date.isNotEmpty) {
      buffer.writeln('Release date: $date');
      buffer.writeln();
    }

    void writeSection(String title, List<String> items) {
      if (items.isEmpty) return;
      buffer.writeln('## $title');
      for (final item in items) {
        buffer.writeln('- $item');
      }
    }

    writeSection('Added', added);
    writeSection('Changed', changed);
    writeSection('Fixed', fixed);

    final releaseNotes = buffer.toString().trim();

    final tag = 'v$version';
    final base = '${AppConstants.githubReleasesBaseUrl}/$tag';
    final assets = [
      ReleaseAsset(
        name: '${AppConstants.apkAssetPrefix}-arm64-v8a-$tag.apk',
        browserDownloadUrl:
            '$base/${AppConstants.apkAssetPrefix}-arm64-v8a-$tag.apk',
        sizeBytes: 0,
      ),
      ReleaseAsset(
        name: '${AppConstants.apkAssetPrefix}-armeabi-v7a-$tag.apk',
        browserDownloadUrl:
            '$base/${AppConstants.apkAssetPrefix}-armeabi-v7a-$tag.apk',
        sizeBytes: 0,
      ),
    ];

    return AppRelease(
      version: version,
      releaseNotes: releaseNotes,
      isDraft: false,
      isPrerelease: false,
      assets: assets,
    );
  }

  @override
  Future<String> downloadApk(
    ReleaseAsset asset,
    void Function(double progress) onProgress,
  ) async {
    _validateAsset(asset);
    final dir = await _updateDir();
    final file = File('${dir.path}/${asset.name}');

    if (await file.exists() && await file.length() == asset.sizeBytes) {
      try {
        await _validateApk(file);
        onProgress(1.0);
        return file.path;
      } on AppException {
        // Invalid cached APK; download a fresh copy.
      }
    }

    final uri = Uri.parse(asset.browserDownloadUrl);
    final http.StreamedResponse response;
    try {
      response = await _client
          .send(http.Request('GET', uri))
          .timeout(requestTimeout);
    } on SocketException {
      throw const AppException('No internet connection.');
    } on TimeoutException {
      throw const AppException('Download timed out.');
    } on http.ClientException catch (clientException) {
      throw AppException('Download failed: ${clientException.message}');
    }

    if (response.statusCode != 200) {
      throw AppException('Download error ${response.statusCode}.');
    }

    final totalBytes = response.contentLength ?? asset.sizeBytes;
    var received = 0;
    final sink = file.openWrite();

    try {
      await for (final chunk in response.stream.timeout(requestTimeout)) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) onProgress(received / totalBytes);
      }
    } catch (caughtError) {
      await sink.close();
      if (await file.exists()) await file.delete();
      throw AppException('Download interrupted: $caughtError');
    }

    await sink.close();

    await _validateApk(file);
    return file.path;
  }

  @override
  Future<void> saveLastCheckTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastCheck, time.millisecondsSinceEpoch);
  }

  @override
  Future<DateTime?> loadLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final milliseconds = prefs.getInt(_keyLastCheck);
    if (milliseconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  @override
  Future<void> saveDismissedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDismissedVersion, version);
  }

  @override
  Future<String?> loadDismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDismissedVersion);
  }

  @override
  Future<void> cleanupOldApks() async {
    final dir = await _updateDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.apk')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<Directory> _updateDir() async {
    final injected = updateDirectory;
    if (injected != null) return injected();
    final base = await getExternalStorageDirectory();
    if (base == null) {
      throw const AppException('Update storage is unavailable.');
    }
    final dir = Directory('${base.path}/utang_tracker_updates');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _validateApk(File file) async {
    if (!file.path.endsWith('.apk')) {
      throw const AppException('Downloaded file is not a valid APK.');
    }
    final bytes = await file.openRead(0, 4).expand((byte) => byte).toList();
    if (bytes.length < 4 ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4B ||
        bytes[2] != 0x03 ||
        bytes[3] != 0x04) {
      await file.delete();
      throw const AppException(
        'Downloaded file is not a valid APK (bad magic bytes).',
      );
    }
  }

  void _validateAsset(ReleaseAsset asset) {
    if (!RegExp(r'^[A-Za-z0-9._-]+\.apk$').hasMatch(asset.name)) {
      throw const AppException('Invalid APK filename.');
    }

    final uri = Uri.tryParse(asset.browserDownloadUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.pathSegments.isEmpty) {
      throw const AppException('Invalid APK download URL.');
    }
  }

  @override
  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  @override
  Future<List<String>> getSupportedAbis() async {
    try {
      return await _channel.invokeListMethod<String>('getSupportedAbis') ??
          const [];
    } on PlatformException catch (platformException) {
      throw AppException(
        platformException.message ?? 'Could not determine device compatibility.',
      );
    }
  }

  @override
  Future<String> loadReleaseNotes() async {
    try {
      return await rootBundle.loadString('assets/release_notes/current.json');
    } catch (_) {
      return '{}';
    }
  }

  @override
  Future<bool> isAssetAvailable(ReleaseAsset asset) async {
    try {
      _validateAsset(asset);
      final uri = Uri.parse(asset.browserDownloadUrl);
      final response = await _client.head(uri).timeout(requestTimeout);
      return response.statusCode == 200 || response.statusCode == 302;
    } on SocketException {
      throw const AppException('No internet connection.');
    } on TimeoutException {
      throw const AppException('Network request timed out.');
    } catch (_) {
      return false;
    }
  }
}
