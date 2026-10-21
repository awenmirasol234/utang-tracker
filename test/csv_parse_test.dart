import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/utils/csv.dart';

void main() {
  test('parses plain rows', () {
    final rows = Csv.parse('a,b,c\n1,2,3');

    expect(rows, [
      ['a', 'b', 'c'],
      ['1', '2', '3'],
    ]);
  });

  test('parses quoted cells with commas and line breaks', () {
    final rows = Csv.parse('name,notes\n"Doe, Juan","line one\nline two"');

    expect(rows.length, 2);
    expect(rows[1][0], 'Doe, Juan');
    expect(rows[1][1], 'line one\nline two');
  });

  test('parses escaped double quotes', () {
    final rows = Csv.parse('notes\n"Says ""hi"""');

    expect(rows[1][0], 'Says "hi"');
  });

  test('parses windows line endings and trailing newlines', () {
    final rows = Csv.parse('a,b\r\n1,2\r\n');

    expect(rows, [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  test('keeps empty cells', () {
    final rows = Csv.parse('a,b,c\n1,,3');

    expect(rows[1], ['1', '', '3']);
  });

  test('maps header names to positions', () {
    final index = Csv.headerIndex(['Debt_ID', 'Customer Name', 'items']);

    expect(index['debt_id'], 0);
    expect(index['customer name'], 1);
    expect(index['items'], 2);
    expect(index['missing'], isNull);
  });
}
