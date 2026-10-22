import 'package:intl/intl.dart';

class Money {
  const Money._(this.centavos);

  factory Money.fromCentavos(int centavos) => Money._(centavos);

  factory Money.fromPesoString(String value) {
    final cleaned = value.trim().replaceAll(',', '');
    if (cleaned.isEmpty) {
      throw const FormatException('Empty amount');
    }
    final match = RegExp(
      r'^(?:(\d+)(?:\.(\d{0,2}))?|\.(\d{1,2}))$',
    ).firstMatch(cleaned);
    if (match == null) {
      throw FormatException('Invalid amount: $value');
    }
    final pesos = int.tryParse(match.group(1) ?? '') ?? 0;
    final centavosText = match.group(2) ?? match.group(3);
    var centavos = pesos * 100;
    if (centavosText != null) {
      centavos += int.parse(centavosText.padRight(2, '0'));
    }
    return Money._(centavos);
  }

  factory Money.fromPesos(double pesos) {
    return Money._((pesos * 100).round());
  }

  factory Money.zero() => const Money._(0);

  final int centavos;

  double get pesos => centavos / 100.0;

  bool get isZero => centavos == 0;
  bool get isPositive => centavos > 0;
  bool get isNegative => centavos < 0;

  Money operator +(Money other) => Money._(centavos + other.centavos);
  Money operator -(Money other) => Money._(centavos - other.centavos);

  bool operator >(Money other) => centavos > other.centavos;
  bool operator <(Money other) => centavos < other.centavos;
  bool operator >=(Money other) => centavos >= other.centavos;
  bool operator <=(Money other) => centavos <= other.centavos;

  static final _format = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  String format() => _format.format(pesos);

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Money && other.centavos == centavos;

  @override
  int get hashCode => centavos.hashCode;
}
