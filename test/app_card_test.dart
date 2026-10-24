import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/theme/app_theme.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';

void main() {
  testWidgets('interactive cards use animated depth and settle after press', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppCard(onTap: () {}, child: const Text('Ledger entry')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surfaceFinder = find
        .descendant(
          of: find.byType(AppCard),
          matching: find.byType(AnimatedPhysicalModel),
        )
        .first;
    AnimatedPhysicalModel surface() =>
        tester.widget<AnimatedPhysicalModel>(surfaceFinder);

    expect(surface().elevation, 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppCard)),
    );
    await tester.pump();
    expect(surface().elevation, 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(surface().elevation, 1);
  });
}
