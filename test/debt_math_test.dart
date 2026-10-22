import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/utils/debt_math.dart';

void main() {
  group('debt math', () {
    test('total is sum of custom item prices', () {
      final total = computeTotal([Money.fromPesos(50), Money.fromPesos(25.50)]);
      expect(total.centavos, 7550);
    });

    test('status derivation', () {
      expect(
        deriveStatus(
          totalAmount: Money.fromPesos(100),
          paidAmount: Money.zero(),
        ),
        DebtStatus.unpaid,
      );
      expect(
        deriveStatus(
          totalAmount: Money.fromPesos(100),
          paidAmount: Money.fromPesos(40),
        ),
        DebtStatus.partial,
      );
      expect(
        deriveStatus(
          totalAmount: Money.fromPesos(100),
          paidAmount: Money.fromPesos(100),
        ),
        DebtStatus.paid,
      );
    });
  });

  group('Money', () {
    test('parses peso strings', () {
      expect(Money.fromPesoString('12.50').centavos, 1250);
      expect(Money.fromPesoString('12').centavos, 1200);
      expect(Money.fromPesoString('1,234.56').centavos, 123456);
      expect(Money.fromPesoString('12.').centavos, 1200);
      expect(Money.fromPesoString('.50').centavos, 50);
      expect(Money.fromPesoString('0').centavos, 0);
    });

    test('rejects invalid peso strings', () {
      for (final value in [
        '',
        'abc',
        'NaN',
        'Infinity',
        '1e3',
        '1.999',
        '-5',
      ]) {
        expect(
          () => Money.fromPesoString(value),
          throwsA(isA<FormatException>()),
          reason: value,
        );
      }
    });

    test('formats with peso symbol', () {
      final formatted = Money.fromPesos(1500).format();
      expect(formatted.contains('1,500'), isTrue);
    });
  });
}
