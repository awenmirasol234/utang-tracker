import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/updater/data/repositories/update_repository_impl.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/domain/repositories/update_repository.dart';
import 'package:utang_tracker/features/updater/domain/usecases/check_for_updates.dart';
import 'package:utang_tracker/features/updater/presentation/providers/update_providers.dart';
import 'package:utang_tracker/features/updater/presentation/widgets/update_auto_checker.dart';
import 'package:utang_tracker/features/updater/presentation/widgets/update_bottom_sheet.dart';

const _supportedAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('updater targets the current GitHub repository', () {
    expect(AppConstants.githubOwner, 'awenmirasol234');
    expect(AppConstants.githubRepo, 'utang-tracker');
    expect(
      AppConstants.githubLatestReleaseUrl,
      'https://github.com/awenmirasol234/utang-tracker/releases/latest',
    );
  });

  group('isNewerVersion', () {
    test('patch bump is newer', () {
      expect(isNewerVersion('1.0.0', '1.0.1'), isTrue);
    });

    test('minor bump is newer', () {
      expect(isNewerVersion('1.0.9', '1.1.0'), isTrue);
    });

    test('major bump is newer', () {
      expect(isNewerVersion('1.9.9', '2.0.0'), isTrue);
    });

    test('same version is not newer', () {
      expect(isNewerVersion('1.2.0', '1.2.0'), isFalse);
    });

    test('older version is not newer', () {
      expect(isNewerVersion('1.2.1', '1.2.0'), isFalse);
    });

    test('double-digit minor comparison is correct', () {
      expect(isNewerVersion('1.9.9', '1.10.0'), isTrue);
      expect(isNewerVersion('1.10.0', '1.9.9'), isFalse);
    });

    test('missing patch segment defaults to 0', () {
      expect(isNewerVersion('1.0', '1.0.1'), isTrue);
    });

    test('malformed versions are treated as not newer', () {
      expect(isNewerVersion('1.0.0', '1.0.0.1'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0-beta'), isFalse);
      expect(isNewerVersion('1.0.0', ''), isFalse);
      expect(isNewerVersion('garbage', '1.2.3'), isFalse);
    });
  });

  group('draft and prerelease filtering', () {
    ReleaseAsset dummyAsset() => const ReleaseAsset(
      name: 'utang-tracker-universal-v1.0.0.apk',
      browserDownloadUrl: 'https://example.com/universal.apk',
      sizeBytes: 1000,
    );

    AppRelease makeRelease({bool isDraft = false, bool isPrerelease = false}) =>
        AppRelease(
          version: '1.0.0',
          releaseNotes: '',
          isDraft: isDraft,
          isPrerelease: isPrerelease,
          assets: [dummyAsset()],
        );

    test('draft release is filtered out (isDraft = true)', () {
      final release = makeRelease(isDraft: true);
      expect(release.isDraft, isTrue);
    });

    test('prerelease is filtered out (isPrerelease = true)', () {
      final release = makeRelease(isPrerelease: true);
      expect(release.isPrerelease, isTrue);
    });

    test('normal release passes through', () {
      final release = makeRelease();
      expect(release.isDraft, isFalse);
      expect(release.isPrerelease, isFalse);
    });
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
      final repo = _FakeUpdateRepository(
        currentVersion: '1.0.0',
        supportedAbis: const ['x86_64'],
        release: _releaseWithAssets([
          asset('utang-tracker-arm64-v8a-v1.1.0.apk'),
          asset('utang-tracker-x86_64-v1.1.0.apk'),
        ]),
      );

      final result = await CheckForUpdates(repo)();

      expect(result.asset?.name, 'utang-tracker-x86_64-v1.1.0.apk');
    });
  });

  group('update availability logic', () {
    test('no update when versions are equal', () {
      expect(isNewerVersion('1.2.0', '1.2.0'), isFalse);
    });

    test('no update when installed is newer (rollback scenario)', () {
      expect(isNewerVersion('1.3.0', '1.2.0'), isFalse);
    });

    test('update available when latest is newer', () {
      expect(isNewerVersion('1.1.0', '1.2.0'), isTrue);
    });

    test('update available with major version jump', () {
      expect(isNewerVersion('1.99.99', '2.0.0'), isTrue);
    });
  });

  testWidgets('update sheet renders markdown release notes as sections', (
    tester,
  ) async {
    final repo = _FakeUpdateRepository(
      currentVersion: '1.0.0',
      release: _releaseWithAssets(
        const [
          ReleaseAsset(
            name: 'utang-tracker-arm64-v8a-v1.1.0.apk',
            browserDownloadUrl: 'https://example.com/update.apk',
            sizeBytes: 1000,
          ),
        ],
        releaseNotes: '''What's new in v1.1.0

Release date: 2026-08-10

## Changed

- Improved update notes display

## Fixed

- Removed raw markdown markers
''',
      ),
    );
    final container = ProviderContainer(
      overrides: [updateRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(updateNotifierProvider.notifier).checkForUpdates();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUpdateBottomSheet(context),
              child: const Text('Show update'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show update'));
    await tester.pumpAndSettle();

    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('Changed'), findsOneWidget);
    expect(find.text('Improved update notes display'), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('Removed raw markdown markers'), findsOneWidget);
    expect(find.textContaining('##'), findsNothing);
  });

  test(
    'failed release fetch does not throttle the next update check',
    () async {
      final repo = _FakeUpdateRepository(
        currentVersion: '1.0.0',
        fetchError: const AppException('No internet connection.'),
      );

      await expectLater(CheckForUpdates(repo)(), throwsA(isA<AppException>()));

      expect(repo.savedCheckTime, isNull);
    },
  );

  test('successful release fetch stores the last check time', () async {
    final repo = _FakeUpdateRepository(currentVersion: '1.0.0');

    await CheckForUpdates(repo)();

    expect(repo.savedCheckTime, isNotNull);
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

  group('install permission round trip', () {
    const channel = MethodChannel(AppConstants.updaterChannel);
    late ProviderContainer container;
    late _FakeUpdateRepository repository;
    late List<MethodCall> calls;
    var canInstall = false;

    setUp(() async {
      canInstall = false;
      repository = _FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: _releaseWithAssets(const [
          ReleaseAsset(
            name: 'utang-tracker-arm64-v8a-v1.1.0.apk',
            browserDownloadUrl: 'https://example.com/update.apk',
            sizeBytes: 1000,
          ),
        ]),
        downloadPath: '/updates/utang-tracker-v1.1.0.apk',
      );
      container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repository)],
      );
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'canInstallUnknownApps') return canInstall;
            return null;
          });

      final notifier = container.read(updateNotifierProvider.notifier);
      await notifier.checkForUpdates();
      await notifier.download();
      await notifier.install();
      expect(
        container.read(updateNotifierProvider),
        isA<UpdatePermissionRequired>(),
      );
      calls.clear();
    });

    tearDown(() async {
      container.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('granted permission installs the already-downloaded APK', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'openInstallSettings') {
              canInstall = true;
              return null;
            }
            if (call.method == 'canInstallUnknownApps') return canInstall;
            return null;
          });

      await container
          .read(updateNotifierProvider.notifier)
          .openInstallSettings();

      final installCall = calls.singleWhere(
        (call) => call.method == 'installApk',
      );
      expect(installCall.arguments, {
        'path': '/updates/utang-tracker-v1.1.0.apk',
      });
      expect(container.read(updateNotifierProvider), isA<UpdateDownloaded>());
    });

    test('denied permission retains the downloaded APK state', () async {
      await container
          .read(updateNotifierProvider.notifier)
          .openInstallSettings();

      expect(calls.where((call) => call.method == 'installApk'), isEmpty);
      final state = container.read(updateNotifierProvider);
      expect(state, isA<UpdatePermissionRequired>());
      expect(
        (state as UpdatePermissionRequired).apkPath,
        '/updates/utang-tracker-v1.1.0.apk',
      );
    });

    test('settings failure becomes an error without installing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'openInstallSettings') {
              throw PlatformException(
                code: 'SETTINGS_FAILED',
                message: 'No settings',
              );
            }
            return false;
          });

      await container
          .read(updateNotifierProvider.notifier)
          .openInstallSettings();

      expect(calls.where((call) => call.method == 'installApk'), isEmpty);
      final state = container.read(updateNotifierProvider);
      expect(state, isA<UpdateError>());
      expect((state as UpdateError).message, 'No settings');
    });

    test('repeated taps do not open overlapping settings requests', () async {
      final settingsReturned = Completer<void>();
      var settingsCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'openInstallSettings') {
              settingsCalls++;
              await settingsReturned.future;
              return null;
            }
            if (call.method == 'canInstallUnknownApps') return false;
            return null;
          });
      final notifier = container.read(updateNotifierProvider.notifier);

      final first = notifier.openInstallSettings();
      await Future<void>.delayed(Duration.zero);
      await notifier.openInstallSettings();

      expect(settingsCalls, 1);
      settingsReturned.complete();
      await first;
    });
  });

  group('downloaded APK preservation', () {
    const channel = MethodChannel(AppConstants.updaterChannel);
    const asset = ReleaseAsset(
      name: 'utang-tracker-arm64-v8a-v1.1.0.apk',
      browserDownloadUrl: 'https://example.com/update.apk',
      sizeBytes: 1000,
    );
    const apkPath = '/updates/utang-tracker-v1.1.0.apk';

    ProviderContainer buildContainer(_FakeUpdateRepository repository) {
      final container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('an already-downloaded APK is offered without downloading again', () async {
      final repository = _FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: _releaseWithAssets(const [asset]),
        downloadPath: apkPath,
        downloadedApkPath: apkPath,
      );
      final container = buildContainer(repository);

      await container.read(updateNotifierProvider.notifier).checkForUpdates();

      final state = container.read(updateNotifierProvider);
      expect(state, isA<UpdateDownloaded>());
      expect((state as UpdateDownloaded).apkPath, apkPath);
      expect(repository.downloadCount, 0);
    });

    test('the downloaded APK stays available after the installer is launched', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'canInstallUnknownApps') return true;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final repository = _FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: _releaseWithAssets(const [asset]),
        downloadPath: apkPath,
        downloadedApkPath: apkPath,
      );
      final container = buildContainer(repository);
      final notifier = container.read(updateNotifierProvider.notifier);

      await notifier.checkForUpdates();
      await notifier.install();

      final installCall = calls.singleWhere(
        (call) => call.method == 'installApk',
      );
      expect(installCall.arguments, {'path': apkPath});
      final state = container.read(updateNotifierProvider);
      expect(state, isA<UpdateDownloaded>());
      expect((state as UpdateDownloaded).apkPath, apkPath);
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

  group('auto update check', () {
    const updateAsset = ReleaseAsset(
      name: 'utang-tracker-arm64-v8a-v1.1.0.apk',
      browserDownloadUrl:
          'https://github.com/awenmirasol234/utang-tracker/releases/download/'
          'v1.1.0/utang-tracker-arm64-v8a-v1.1.0.apk',
      sizeBytes: 1000,
    );

    Future<ProviderContainer> pumpAutoChecker(
      WidgetTester tester,
      _FakeUpdateRepository repository,
    ) async {
      final container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: UpdateAutoChecker(child: SizedBox.shrink()),
          ),
        ),
      );
      return container;
    }

    /// Tears the tree down so the checker's pending timer is cancelled.
    Future<void> disposeTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
    }

    /// Advances past the startup grace period so the first pass runs.
    Future<void> runFirstPass(WidgetTester tester) async {
      await tester.pump(
        AppConstants.updateCheckStartupGrace + const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('does not read the repository while the app is starting up', (
      tester,
    ) async {
      final repository = _FakeUpdateRepository(currentVersion: '1.0.0');

      await pumpAutoChecker(tester, repository);
      await tester.pump();

      expect(repository.lastCheckReads, 0);
      expect(repository.fetchCount, 0);

      await disposeTree(tester);
    });

    testWidgets('checks when no previous check is recorded', (tester) async {
      final repository = _FakeUpdateRepository(currentVersion: '1.0.0');

      await pumpAutoChecker(tester, repository);
      await runFirstPass(tester);

      expect(repository.fetchCount, 1);

      await disposeTree(tester);
    });

    testWidgets('skips the check when the last one is within the interval', (
      tester,
    ) async {
      final repository = _FakeUpdateRepository(currentVersion: '1.0.0')
        ..savedCheckTime = DateTime.now().subtract(const Duration(hours: 2));

      await pumpAutoChecker(tester, repository);
      await runFirstPass(tester);

      expect(repository.fetchCount, 0);

      await disposeTree(tester);
    });

    testWidgets('checks when the last one is older than the interval', (
      tester,
    ) async {
      final repository = _FakeUpdateRepository(currentVersion: '1.0.0')
        ..savedCheckTime = DateTime.now().subtract(const Duration(hours: 7));

      await pumpAutoChecker(tester, repository);
      await runFirstPass(tester);

      expect(repository.fetchCount, 1);

      await disposeTree(tester);
    });

    testWidgets('opens the update sheet when an update is available', (
      tester,
    ) async {
      final repository = _FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: _releaseWithAssets(const [updateAsset]),
      );

      await pumpAutoChecker(tester, repository);
      await runFirstPass(tester);

      expect(find.text('Update now'), findsOneWidget);

      await disposeTree(tester);
    });

    testWidgets(
      'a dismissed version suppresses the auto prompt but not a manual check',
      (tester) async {
        final repository = _FakeUpdateRepository(
          currentVersion: '1.0.0',
          release: _releaseWithAssets(const [updateAsset]),
        )..dismissedVersion = '1.1.0';

        final container = await pumpAutoChecker(tester, repository);
        await runFirstPass(tester);

        expect(repository.fetchCount, 1);
        expect(find.text('Update now'), findsNothing);
        expect(container.read(updateNotifierProvider), isA<UpdateIdle>());

        // A manual check still offers the dismissed version.
        await container.read(updateNotifierProvider.notifier).checkForUpdates();
        await tester.pumpAndSettle();

        expect(container.read(updateNotifierProvider), isA<UpdateAvailable>());

        await disposeTree(tester);
      },
    );

    testWidgets('dismissing the sheet stores the version for later checks', (
      tester,
    ) async {
      final repository = _FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: _releaseWithAssets(const [updateAsset]),
      );

      await pumpAutoChecker(tester, repository);
      await runFirstPass(tester);

      expect(find.text('Update now'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(repository.dismissedVersion, '1.1.0');

      await disposeTree(tester);
    });
  });
}

AppRelease _releaseWithAssets(
  List<ReleaseAsset> assets, {
  String releaseNotes = '',
}) => AppRelease(
  version: '1.1.0',
  releaseNotes: releaseNotes,
  isDraft: false,
  isPrerelease: false,
  assets: assets,
);

class _FakeUpdateRepository implements UpdateRepository {
  _FakeUpdateRepository({
    required this.currentVersion,
    this.supportedAbis = const ['arm64-v8a'],
    this.release,
    this.fetchError,
    this.downloadPath,
    this.downloadedApkPath,
  });

  final String currentVersion;
  final List<String> supportedAbis;
  final AppRelease? release;
  final AppException? fetchError;
  final String? downloadPath;
  final String? downloadedApkPath;
  DateTime? savedCheckTime;
  String? dismissedVersion;
  int fetchCount = 0;
  int lastCheckReads = 0;
  int downloadCount = 0;

  @override
  Future<AppRelease?> fetchLatestRelease() async {
    fetchCount++;
    if (fetchError case final error?) throw error;
    return release;
  }

  @override
  Future<String> getCurrentVersion() async => currentVersion;

  @override
  Future<List<String>> getSupportedAbis() async => supportedAbis;

  @override
  Future<void> saveLastCheckTime(DateTime time) async {
    savedCheckTime = time;
  }

  @override
  Future<DateTime?> loadLastCheckTime() async {
    lastCheckReads++;
    return savedCheckTime;
  }

  @override
  Future<String?> loadDismissedVersion() async => dismissedVersion;

  @override
  Future<void> saveDismissedVersion(String version) async {
    dismissedVersion = version;
  }

  @override
  Future<void> cleanupOldApks() async {}

  @override
  Future<String?> findDownloadedApk(ReleaseAsset asset) async =>
      downloadedApkPath;

  @override
  Future<String> downloadApk(
    ReleaseAsset asset,
    void Function(double progress) onProgress,
  ) async {
    final path = downloadPath;
    if (path == null) throw UnimplementedError();
    downloadCount++;
    onProgress(1);
    return path;
  }

  @override
  Future<String> loadReleaseNotes() async => '{}';

  @override
  Future<bool> isAssetAvailable(ReleaseAsset asset) async => true;
}
