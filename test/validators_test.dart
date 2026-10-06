import 'package:cargacerta_ar/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMeters', () {
    test('aceita vírgula e ponto', () {
      expect(parseMeters('1,20'), closeTo(1.2, 1e-9));
      expect(parseMeters('0.8'), closeTo(0.8, 1e-9));
      expect(parseMeters(' 2 '), closeTo(2.0, 1e-9));
    });

    test('rejeita entradas maliciosas ou inválidas', () {
      const bad = <String>[
        '',
        'abc',
        '1e3',
        '-1',
        '1,2,3',
        '0',
        '13',
        'NaN',
        'Infinity',
        '1 m',
        '١٢',
        '1.2345',
        '99999',
      ];
      for (final s in bad) {
        expect(parseMeters(s), isNull, reason: 'deveria rejeitar "$s"');
      }
      expect(parseMeters(null), isNull);
    });

    test('limites inclusivos', () {
      expect(parseMeters('0,05'), isNotNull);
      expect(parseMeters('12'), isNotNull);
      expect(parseMeters('0,04'), isNull);
    });
  });

  group('parseKg / parseQuantity', () {
    test('peso', () {
      expect(parseKg('45'), 45.0);
      expect(parseKg('0'), isNull);
      expect(parseKg('3001'), isNull);
    });

    test('quantidade', () {
      expect(parseQuantity('8'), 8);
      expect(parseQuantity('0'), isNull);
      expect(parseQuantity('100'), isNull);
      expect(parseQuantity('1.5'), isNull);
      expect(parseQuantity('abc'), isNull);
    });
  });

  group('sanitizeName', () {
    test('remove controle, colapsa espaços e apara', () {
      expect(sanitizeName('  Sofá\n\t  3 lugares  '), 'Sofá 3 lugares');
    });

    test('remove caracteres de direção invisíveis', () {
      expect(sanitizeName('ab\u202Ecd'), 'ab cd');
    });

    test('limita o tamanho', () {
      expect(sanitizeName('A' * 100).length, Limits.maxNameLength);
    });

    test('só espaços vira vazio e é inválido', () {
      expect(sanitizeName('   \n '), isEmpty);
      expect(validateName('   '), isNotNull);
    });
  });
}
