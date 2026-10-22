import 'package:intl/intl.dart';

class DateFormatters {
  DateFormatters._();

  static final _dayKey = DateFormat('yyyy-MM-dd');
  static const _timestampSeparator = ' • ';
  static const _rangeSeparator = ' - ';

  static String smartTimestamp(
    DateTime value, {
    required DateTime relativeTo,
    required String locale,
    required bool use24HourFormat,
  }) {
    final localValue = value.toLocal();
    final date = _smartDateLabel(
      localValue,
      relativeTo: relativeTo,
      locale: locale,
    );
    final canonicalLocale = Intl.canonicalizedLocale(locale);
    final localizedTime = use24HourFormat
        ? DateFormat.Hm(canonicalLocale).format(localValue)
        : DateFormat.jm(canonicalLocale).format(localValue);
    final time = localizedTime
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ');
    return '$date$_timestampSeparator$time';
  }

  static String smartDate(
    DateTime value, {
    required DateTime relativeTo,
    required String locale,
  }) {
    return _smartDateLabel(
      value.toLocal(),
      relativeTo: relativeTo,
      locale: locale,
    );
  }

  static String smartDateRange(
    DateTime start,
    DateTime end, {
    required DateTime relativeTo,
    required String locale,
  }) {
    final startLabel = smartDate(start, relativeTo: relativeTo, locale: locale);
    if (isSameLocalDay(start, end)) return startLabel;
    final endLabel = smartDate(end, relativeTo: relativeTo, locale: locale);
    return '$startLabel$_rangeSeparator$endLabel';
  }

  static String dayKey(DateTime date) => _dayKey.format(date.toLocal());

  static String fullDate(DateTime date, {required String locale}) {
    final canonicalLocale = Intl.canonicalizedLocale(locale);
    return DateFormat.yMMMMd(canonicalLocale).format(date.toLocal());
  }

  static bool isSameLocalDay(DateTime first, DateTime second) {
    final localA = first.toLocal();
    final localB = second.toLocal();
    return localA.year == localB.year && localA.month == localB.month && localA.day == localB.day;
  }

  static DateTime startOfLocalDay(DateTime date) {
    final localDate = date.toLocal();
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  static DateTime endOfLocalDay(DateTime date) {
    final localDate = date.toLocal();
    return DateTime(localDate.year, localDate.month, localDate.day, 23, 59, 59, 999);
  }

  static String _smartDateLabel(
    DateTime localValue, {
    required DateTime relativeTo,
    required String locale,
  }) {
    final localReference = relativeTo.toLocal();
    final valueDay = DateTime.utc(
      localValue.year,
      localValue.month,
      localValue.day,
    );
    final referenceDay = DateTime.utc(
      localReference.year,
      localReference.month,
      localReference.day,
    );
    final daysAgo = referenceDay.difference(valueDay).inDays;

    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';

    final canonicalLocale = Intl.canonicalizedLocale(locale);
    if (daysAgo >= 2 && daysAgo <= 6) {
      return DateFormat.E(canonicalLocale).format(localValue);
    }
    if (localValue.year == localReference.year) {
      return DateFormat.MMMd(canonicalLocale).format(localValue);
    }
    return DateFormat.yMMMd(canonicalLocale).format(localValue);
  }
}
