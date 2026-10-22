class DebtItemUnits {
  DebtItemUnits._();

  static const String piece = 'piece';
  static const String pack = 'pack';
  static const String box = 'box';
  static const String bottle = 'bottle';
  static const String kilogram = 'kg';
  static const String gram = 'g';
  static const String liter = 'liter';
  static const String milliliter = 'ml';
  static const String can = 'can';
  static const String sachet = 'sachet';
  static const String bag = 'bag';
  static const String dozen = 'dozen';
  static const String tray = 'tray';
  static const String bundle = 'bundle';

  static const List<({String value, String label, String pluralLabel})> common =
      [
        (value: piece, label: 'piece', pluralLabel: 'pieces'),
        (value: pack, label: 'pack', pluralLabel: 'packs'),
        (value: box, label: 'box', pluralLabel: 'boxes'),
        (value: bottle, label: 'bottle', pluralLabel: 'bottles'),
        (value: kilogram, label: 'kg', pluralLabel: 'kg'),
        (value: gram, label: 'gram', pluralLabel: 'grams'),
        (value: liter, label: 'liter', pluralLabel: 'liters'),
        (value: milliliter, label: 'ml', pluralLabel: 'ml'),
        (value: can, label: 'can', pluralLabel: 'cans'),
        (value: sachet, label: 'sachet', pluralLabel: 'sachets'),
        (value: bag, label: 'bag', pluralLabel: 'bags'),
        (value: dozen, label: 'dozen', pluralLabel: 'dozens'),
        (value: tray, label: 'tray', pluralLabel: 'trays'),
        (value: bundle, label: 'bundle', pluralLabel: 'bundles'),
      ];

  static bool isCommon(String value) {
    return common.any((option) => option.value == value);
  }

  static String displayName(String value) {
    final normalized = normalize(value);
    for (final option in common) {
      if (option.value == normalized) return option.label;
    }
    return value.trim();
  }

  static String displayNameForQuantity(String value, double quantity) {
    final normalized = normalize(value);
    for (final option in common) {
      if (option.value == normalized) {
        if (quantity == 1) return option.label;
        return option.pluralLabel;
      }
    }
    return value.trim();
  }

  /// Formats a quantity without a trailing decimal when it is a whole number.
  static String formatQuantity(double quantity) {
    if (quantity % 1 == 0) return quantity.toInt().toString();
    return quantity.toString();
  }

  static String normalize(String value) {
    final trimmed = value.trim();
    for (final option in common) {
      if (option.value.toLowerCase() == trimmed.toLowerCase() ||
          option.label.toLowerCase() == trimmed.toLowerCase()) {
        return option.value;
      }
    }
    return trimmed;
  }
}
