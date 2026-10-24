import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/presentation/providers/update_providers.dart';

import 'support/update_repository_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('install permission round trip', () {
    const channel = MethodChannel(AppConstants.updaterChannel);
    late ProviderContainer container;
    late FakeUpdateRepository repository;
    late List<MethodCall> calls;
    var canInstall = false;

    setUp(() async {
      canInstall = false;
      repository = FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: releaseWithAssets(const [
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

    ProviderContainer buildContainer(FakeUpdateRepository repository) {
      final container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'an already-downloaded APK is offered without downloading again',
      () async {
        final repository = FakeUpdateRepository(
          currentVersion: '1.0.0',
          release: releaseWithAssets(const [asset]),
          downloadPath: apkPath,
          downloadedApkPath: apkPath,
        );
        final container = buildContainer(repository);

        await container.read(updateNotifierProvider.notifier).checkForUpdates();

        final state = container.read(updateNotifierProvider);
        expect(state, isA<UpdateDownloaded>());
        expect((state as UpdateDownloaded).apkPath, apkPath);
        expect(repository.downloadCount, 0);
      },
    );

    test(
      'the downloaded APK stays available after the installer is launched',
      () async {
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
        final repository = FakeUpdateRepository(
          currentVersion: '1.0.0',
          release: releaseWithAssets(const [asset]),
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
      },
    );
  });

  group('pending APK persistence across app restart', () {
    const asset = ReleaseAsset(
      name: 'utang-tracker-arm64-v8a-v1.1.0.apk',
      browserDownloadUrl: 'https://example.com/update.apk',
      sizeBytes: 1000,
    );
    const apkPath = '/updates/utang-tracker-v1.1.0.apk';

    test('pending APK is saved when permission is required', () async {
      var canInstall = false;
      const channel = MethodChannel(AppConstants.updaterChannel);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'canInstallUnknownApps') return canInstall;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final repository = FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: releaseWithAssets(const [asset]),
        downloadPath: apkPath,
      );
      final container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(updateNotifierProvider.notifier);
      await notifier.checkForUpdates();
      await notifier.download();
      await notifier.install();

      expect(repository.pendingVersion, '1.1.0');
      expect(repository.pendingPath, apkPath);
    });

    test('pending APK is restored after app restart', () async {
      const channel = MethodChannel(AppConstants.updaterChannel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'canInstallUnknownApps') return false;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      // First app session: download and reach permission required
      final repository = FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: releaseWithAssets(const [asset]),
        downloadPath: apkPath,
      );
      var container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repository)],
      );
      var notifier = container.read(updateNotifierProvider.notifier);
      await notifier.checkForUpdates();
      await notifier.download();
      await notifier.install();
      expect(
        container.read(updateNotifierProvider),
        isA<UpdatePermissionRequired>(),
      );
      container.dispose();

      // Simulate app restart: new container with same repository (persisted data)
      container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repository)],
      );
      notifier = container.read(updateNotifierProvider.notifier);
      // Allow async restore to complete
      await Future<void>.delayed(Duration.zero);
      // build() should restore the pending APK
      expect(
        container.read(updateNotifierProvider),
        isA<UpdatePermissionRequired>(),
      );
      final restored =
          container.read(updateNotifierProvider) as UpdatePermissionRequired;
      expect(restored.apkPath, apkPath);
      expect(restored.release.version, '1.1.0');
      container.dispose();
    });

    test(
      'pending APK is cleared after successful install from settings',
      () async {
        var canInstall = false;
        const channel = MethodChannel(AppConstants.updaterChannel);
        final calls = <MethodCall>[];
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
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final repository = FakeUpdateRepository(
          currentVersion: '1.0.0',
          release: releaseWithAssets(const [asset]),
          downloadPath: apkPath,
        );
        final container = ProviderContainer(
          overrides: [updateRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(updateNotifierProvider.notifier);
        await notifier.checkForUpdates();
        await notifier.download();
        await notifier.install();

        // Verify pending APK was saved
        expect(repository.pendingVersion, '1.1.0');
        expect(repository.pendingPath, apkPath);

        // Open settings, permission granted, install succeeds
        await notifier.openInstallSettings();

        // Pending APK should be cleared
        expect(repository.pendingVersion, isNull);
        expect(repository.pendingPath, isNull);
      },
    );

    test('pending APK is cleared on dismiss', () async {
      var canInstall = false;
      const channel = MethodChannel(AppConstants.updaterChannel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'canInstallUnknownApps') return canInstall;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final repository = FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: releaseWithAssets(const [asset]),
        downloadPath: apkPath,
      );
      final container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(updateNotifierProvider.notifier);
      await notifier.checkForUpdates();
      await notifier.download();
      await notifier.install();

      // Verify pending APK was saved
      expect(repository.pendingVersion, '1.1.0');
      expect(repository.pendingPath, apkPath);

      // Dismiss the update
      await notifier.dismiss();

      // Pending APK should be cleared
      expect(repository.pendingVersion, isNull);
      expect(repository.pendingPath, isNull);
      // Dismissed version should be saved
      expect(repository.dismissedVersion, '1.1.0');
    });
  });
}
