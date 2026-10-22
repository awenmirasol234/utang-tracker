import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/app.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/widgets/app_modal_bottom_sheet.dart';

void main() {
  testWidgets('app shell shows dashboard title', (tester) async {
    final appDatabase = AppDatabase.forTesting();
    addTearDown(appDatabase.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(appDatabase),
          updateRepositoryProvider.overrideWith(
            (_) => throw StateError(
              'The update repository must not be read during app startup.',
            ),
          ),
        ],
        child: const UtangTrackerApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Home')),
      findsOneWidget,
    );
    expect(find.text('Store overview'), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Due reminders'));
    await tester.pumpAndSettle();

    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));

    expect(find.text('Due reminders'), findsOneWidget);
    expect(find.text('No reminders'), findsOneWidget);
    expect(find.byType(AppModalBottomSheet), findsOneWidget);
    expect(bottomSheet.showDragHandle, isTrue);
  });
}
