import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/utils/local_date_time.dart';

void main() {
  group('combineLocalDateAndTime', () {
    test('uses the selected local day and supplied local clock time', () {
      final result = combineLocalDateAndTime(
        DateTime(2026, 5, 3),
        DateTime(2026, 7, 19, 14, 25, 36, 789, 123),
      );

      expect(result, DateTime(2026, 5, 3, 14, 25, 36, 789, 123));
      expect(result.isUtc, isFalse);
    });

    test('normalizes UTC inputs to local calendar and clock fields', () {
      final date = DateTime.utc(2026, 5, 3, 18);
      final time = DateTime.utc(2026, 7, 19, 6, 25, 36, 789, 123);
      final localDate = date.toLocal();
      final localTime = time.toLocal();

      final result = combineLocalDateAndTime(date, time);

      expect(
        result,
        DateTime(
          localDate.year,
          localDate.month,
          localDate.day,
          localTime.hour,
          localTime.minute,
          localTime.second,
          localTime.millisecond,
          localTime.microsecond,
        ),
      );
    });
  });
}
