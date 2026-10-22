import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/presentation/providers/update_providers.dart';
import 'package:utang_tracker/features/updater/presentation/widgets/update_auto_checker.dart';

import 'support/update_repository_fake.dart';

void main() {
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
      FakeUpdateRepository repository,
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
      final repository = FakeUpdateRepository(currentVersion: '1.0.0');

      await pumpAutoChecker(tester, repository);
      await tester.pump();

      expect(repository.lastCheckReads, 0);
      expect(repository.fetchCount, 0);

      await disposeTree(tester);
    });

    testWidgets('checks when no previous check is recorded', (tester) async {
      final repository = FakeUpdateRepository(currentVersion: '1.0.0');

      await pumpAutoChecker(tester, repository);
      await runFirstPass(tester);

      expect(repository.fetchCount, 1);

      await disposeTree(tester);
    });

    testWidgets('skips the check when the last one is within the interval', (
      tester,
    ) async {
      final repository = FakeUpdateRepository(currentVersion: '1.0.0')
        ..savedCheckTime = DateTime.now().subtract(const Duration(hours: 2));

      await pumpAutoChecker(tester, repository);
      await runFirstPass(tester);

      expect(repository.fetchCount, 0);

      await disposeTree(tester);
    });

    testWidgets('checks when the last one is older than the interval', (
      tester,
    ) async {
      final repository = FakeUpdateRepository(currentVersion: '1.0.0')
        ..savedCheckTime = DateTime.now().subtract(const Duration(hours: 7));

      await pumpAutoChecker(tester, repository);
      await runFirstPass(tester);

      expect(repository.fetchCount, 1);

      await disposeTree(tester);
    });

    testWidgets('opens the update sheet when an update is available', (
      tester,
    ) async {
      final repository = FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: releaseWithAssets(const [updateAsset]),
      );

      await pumpAutoChecker(tester, repository);
      await runFirstPass(tester);

      expect(find.text('Update now'), findsOneWidget);

      await disposeTree(tester);
    });

    testWidgets(
      'a dismissed version suppresses the auto prompt but not a manual check',
      (tester) async {
        final repository = FakeUpdateRepository(
          currentVersion: '1.0.0',
          release: releaseWithAssets(const [updateAsset]),
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
      final repository = FakeUpdateRepository(
        currentVersion: '1.0.0',
        release: releaseWithAssets(const [updateAsset]),
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
