import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/theme/app_theme.dart';
import 'package:utang_tracker/core/widgets/app_text_field.dart';
import 'package:utang_tracker/features/payments/presentation/pages/record_payment_page.dart';

void main() {
  testWidgets('required payment fields show and clear inline errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RecordPaymentPage(),
        ),
      ),
    );

    final confirmRow = find.byKey(const Key('confirm-payment-row'));
    final notesLabel = find.text('Notes');
    expect(notesLabel, findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    await tester.ensureVisible(confirmRow);
    await tester.pump();

    final spacing =
        tester.getTopLeft(confirmRow).dy - tester.getBottomLeft(notesLabel).dy;
    expect(spacing, greaterThanOrEqualTo(AppSpacing.lg));

    final confirmCheckbox = find.byType(Checkbox);
    expect(confirmCheckbox, findsOneWidget);
    await tester.tap(confirmCheckbox);
    await tester.pump();

    final save = find.text('Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();

    expect(find.text('Select debt'), findsAtLeastNWidgets(1));
    expect(find.text('Amount is required.'), findsOneWidget);

    final debtDecorator = find
        .ancestor(
          of: find.text('Select debt'),
          matching: find.byType(InputDecorator),
        )
        .first;
    expect(
      tester.widget<InputDecorator>(debtDecorator).decoration.errorText,
      'Select debt',
    );

    final amountField = find.byWidgetPredicate(
      (widget) => widget is AppTextField && widget.label == 'Amount *',
    );
    final amountInput = find.descendant(
      of: amountField,
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(amountInput).decoration?.errorText,
      'Amount is required.',
    );

    await tester.enterText(amountInput, '100');
    await tester.pump();
    expect(tester.widget<TextField>(amountInput).decoration?.errorText, isNull);
    expect(tester.takeException(), isNull);
    expect(find.text('Save ₱100.00'), findsOneWidget);
  });
}
