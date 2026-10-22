import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/updater/data/repositories/update_repository_impl.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/domain/usecases/check_for_updates.dart';

import 'support/update_repository_fake.dart';

const _supportedAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

void main() {
  test('updater targets the current GitHub repository', () {
    expect(AppConstants.githubOwner, 'awenmirasol234');
    expect(AppConstants.githubRepo, 'utang-tracker');
    expect(
      AppConstants.githubLatestReleaseUrl,
      'https://github.com/awenmirasol234/utang-tracker/releases/latest',
    );
  });

  group('selectApkAsset', () {
    ReleaseAsset asset(String name) => ReleaseAsset(
      name: name,
      browserDownloadUrl: 'https://example.com/$name',
      sizeBytes: 1000,
    );

    test('selects arm64-v8a when available (highest priority)', () {
      final assets = [
        asset('utang-tracker-armeabi-v7a-v1.0.0.apk'),
        asset('utang-tracker-arm64-v8a-v1.0.0.apk'),
        asset('utang-tracker-x86_64-v1.0.0.apk'),
        asset('utang-tracker-universal-v1.0.0.apk'),
      ];
      final selected = selectApkAsset(assets, _supportedAbis);
      expect(selected?.name, 'utang-tracker-arm64-v8a-v1.0.0.apk');
    });

    test('falls back to armeabi-v7a when arm64 absent', () {
      final assets = [
        asset('utang-tracker-armeabi-v7a-v1.0.0.apk'),
        asset('utang-tracker-universal-v1.0.0.apk'),
      ];
      final selected = selectApkAsset(assets, _supportedAbis);
      expect(selected?.name, 'utang-tracker-armeabi-v7a-v1.0.0.apk');
    });

    test('falls back to x86_64 when arm variants absent', () {
      final assets = [
        asset('utang-tracker-x86_64-v1.0.0.apk'),
        asset('utang-tracker-universal-v1.0.0.apk'),
      ];
      final selected = selectApkAsset(assets, ['x86_64']);
      expect(selected?.name, 'utang-tracker-x86_64-v1.0.0.apk');
    });

    test('universal APK fallback when no ABI-specific asset exists', () {
      final assets = [asset('utang-tracker-universal-v1.0.0.apk')];
      final selected = selectApkAsset(assets, _supportedAbis);
      expect(selected?.name, 'utang-tracker-universal-v1.0.0.apk');
    });

    test('returns null when no matching asset found', () {
      final assets = [asset('some-other-app-arm64.apk')];
      final selected = selectApkAsset(assets, _supportedAbis);
      expect(selected, isNull);
    });

    test('ignores checksum files that share the APK prefix', () {
      final assets = [
        asset('utang-tracker-arm64-v8a-v1.0.0.apk.sha256'),
        asset('utang-tracker-arm64-v8a-v1.0.0.apk'),
      ];

      final selected = selectApkAsset(assets, ['arm64-v8a']);

      expect(selected?.name, 'utang-tracker-arm64-v8a-v1.0.0.apk');
    });

    test('uses only the ABIs reported by the current device', () async {
      final repo = FakeUpdateRepository(
        currentVersion: '1.0.0',
        supportedAbis: const ['x86_64'],
        release: releaseWithAssets([
          asset('utang-tracker-arm64-v8a-v1.1.0.apk'),
          asset('utang-tracker-x86_64-v1.1.0.apk'),
        ]),
      );

      final result = await CheckForUpdates(repo)();

      expect(result.asset?.name, 'utang-tracker-x86_64-v1.1.0.apk');
    });
  });

  test(
    'invalid same-length cached APK is validated and downloaded again',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'utang-updater-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      const asset = ReleaseAsset(
        name: 'utang-tracker-universal-v1.1.0.apk',
        browserDownloadUrl:
            'https://github.com/awenmirasol234/utang-tracker/releases/download/v1.1.0/update.apk',
        sizeBytes: 8,
      );
      final cached = File('${directory.path}/${asset.name}');
      await cached.writeAsBytes(List<int>.filled(asset.sizeBytes, 0));
      var requests = 0;
      final validApk = <int>[0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4];
      final repository = UpdateRepositoryImpl(
        httpClient: MockClient((request) async {
          requests++;
          return http.Response.bytes(validApk, 200);
        }),
        updateDirectory: () async => directory,
      );

      final path = await repository.downloadApk(asset, (_) {});

      expect(requests, 1);
      expect(await File(path).readAsBytes(), validApk);
    },
  );

  group('APK download safety', () {
    const validUrl =
        'https://github.com/awenmirasol234/utang-tracker/releases/download/v1.1.0/update.apk';

    test('rejects path separators in the asset filename', () async {
      final repository = UpdateRepositoryImpl(
        updateDirectory: () async => Directory.systemTemp,
      );

      await expectLater(
        repository.downloadApk(
          const ReleaseAsset(
            name: '../update.apk',
            browserDownloadUrl: validUrl,
            sizeBytes: 0,
          ),
          (_) {},
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('rejects non-GitHub download URLs', () async {
      final repository = UpdateRepositoryImpl(
        updateDirectory: () async => Directory.systemTemp,
      );

      await expectLater(
        repository.downloadApk(
          const ReleaseAsset(
            name: 'update.apk',
            browserDownloadUrl: 'https://example.com/update.apk',
            sizeBytes: 0,
          ),
          (_) {},
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('times out stalled release requests', () async {
      final repository = UpdateRepositoryImpl(
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response('{}', 200);
        }),
        requestTimeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.fetchLatestRelease(),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('findDownloadedApk', () {
    const asset = ReleaseAsset(
      name: 'utang-tracker-universal-v1.1.0.apk',
      browserDownloadUrl:
          'https://github.com/awenmirasol234/utang-tracker/releases/download/v1.1.0/update.apk',
      sizeBytes: 8,
    );

    Future<Directory> tempDir() async {
      final directory = await Directory.systemTemp.createTemp(
        'utang-updater-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      return directory;
    }

    test('returns the path of a valid downloaded APK', () async {
      final directory = await tempDir();
      final file = File('${directory.path}/${asset.name}');
      await file.writeAsBytes([0x50, 0x4B, 0x03, 0x04, 1, 2, 3, 4]);
      final repository = UpdateRepositoryImpl(
        updateDirectory: () async => directory,
      );

      expect(await repository.findDownloadedApk(asset), file.path);
    });

    test('returns null when the APK is missing', () async {
      final directory = await tempDir();
      final repository = UpdateRepositoryImpl(
        updateDirectory: () async => directory,
      );

      expect(await repository.findDownloadedApk(asset), isNull);
    });

    test('returns null when the file is not an APK', () async {
      final directory = await tempDir();
      final file = File('${directory.path}/${asset.name}');
      await file.writeAsBytes(List<int>.filled(asset.sizeBytes, 0));
      final repository = UpdateRepositoryImpl(
        updateDirectory: () async => directory,
      );

      expect(await repository.findDownloadedApk(asset), isNull);
      expect(await file.exists(), isTrue);
    });
  });
}
