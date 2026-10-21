/// Minimal CSV helpers following RFC 4180 quoting rules.
class Csv {
  Csv._();

  /// Escapes a single cell. Values containing a comma, quote, or line break
  /// are wrapped in double quotes and inner quotes are doubled.
  static String cell(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  /// Joins the cells of a single row.
  static String line(List<String> cells) => cells.map(cell).join(',');
}
