import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/theme/app_theme.dart';
import 'package:utang_tracker/core/widgets/app_filter_chip.dart';

void main() {
  testWidgets('selected filters use color and restrained depth', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppFilterChip(
            label: 'Unpaid',
            selected: true,
            onSelected: () {},
          ),
        ),
      ),
    );

    final chip = tester.widget<FilterChip>(find.byType(FilterChip));

    expect(chip.elevation, 1);
    expect(chip.pressElevation, 2);
  });
}
