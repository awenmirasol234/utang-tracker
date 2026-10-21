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

  /// Parses CSV text into rows of cells. Quoted cells may contain commas,
  /// line breaks and escaped double quotes.
  static List<List<String>> parse(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    var index = 0;

    while (index < content.length) {
      final char = content[index];
      if (inQuotes) {
        if (char == '"') {
          final next = index + 1 < content.length ? content[index + 1] : '';
          if (next == '"') {
            cell.write('"');
            index += 1;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (char == '\n') {
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else if (char != '\r') {
        cell.write(char);
      }
      index += 1;
    }

    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  /// Maps the column names of a header row to their position. Names are
  /// trimmed and lowercased; the first occurrence of a name wins.
  static Map<String, int> headerIndex(List<String> header) {
    final index = <String, int>{};
    for (var position = 0; position < header.length; position += 1) {
      final name = header[position].trim().toLowerCase();
      if (name.isEmpty) {
        continue;
      }
      if (!index.containsKey(name)) {
        index[name] = position;
      }
    }
    return index;
  }
}
