DateTime combineLocalDateAndTime(DateTime date, DateTime time) {
  final localDate = date.toLocal();
  final localTime = time.toLocal();

  return DateTime(
    localDate.year,
    localDate.month,
    localDate.day,
    localTime.hour,
    localTime.minute,
    localTime.second,
    localTime.millisecond,
    localTime.microsecond,
  );
}

/// The first moment of the local calendar day the given moment falls on.
DateTime startOfLocalDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The last moment of the local calendar day the given moment falls on.
DateTime endOfLocalDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day, 23, 59, 59, 999);
}
