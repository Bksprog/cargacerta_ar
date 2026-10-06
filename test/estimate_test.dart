import 'package:cargacerta_ar/domain/estimate.dart';
import 'package:cargacerta_ar/domain/furniture.dart';
import 'package:cargacerta_ar/domain/piece.dart';
import 'package:cargacerta_ar/domain/presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final example = buildExampleItems();

  test('volume do exemplo (V = C × L × A, somado)', () {
    final est = estimateVolume(example, reserveRatio: 0.20);
    // 1,53 + 1,08 + 0,882 + 1,2 + 1,131 + 0,6486 + 0,64 + 0,055125
    expect(est.geometricM3, closeTo(7.166725, 1e-6));
    expect(est.minCapacityM3, closeTo(8.60007, 1e-5));
    expect(est.totalWeightKg, closeTo(379, 1e-9));
    expect(est.unitCount, 15);
  });

  test('reserva fora dos limites é contida', () {
    expect(estimateVolume(example, reserveRatio: 5).reserveRatio, 0.40);
    expect(estimateVolume(example, reserveRatio: -1).reserveRatio, 0.05);
  });

  test('desmontável vira duas peças com o maior lado dividido', () {
    final armario = FurnitureItem(
      id: 'a1a1a1a1',
      name: 'Armário',
      lengthM: 1.2,
      widthM: 0.5,
      heightM: 2.0,
      weightKg: 60,
      properties: {ItemProperty.disassemblable},
    );
    final pieces = expandPieces([armario]);
    expect(pieces.length, 2);
    expect(pieces.first.h, closeTo(1.0, 1e-9));
    expect(pieces.first.weightKg, closeTo(30, 1e-9));
    expect(estimateVolume([armario]).largestPieceM, closeTo(1.2, 1e-9));
  });

  test('quantidade gera uma peça por unidade', () {
    final caixas = FurnitureItem(
      id: 'b2b2b2b2',
      name: 'Caixas',
      lengthM: 0.5,
      widthM: 0.4,
      heightM: 0.4,
      weightKg: 12,
      quantity: 3,
    );
    final pieces = expandPieces([caixas]);
    expect(pieces.map((p) => p.label).toList(), ['Caixas #1', 'Caixas #2', 'Caixas #3']);
  });

  test('item muito pesado vira "pesado" automaticamente', () {
    final cofre = FurnitureItem(
      id: 'c3c3c3c3',
      name: 'Cofre',
      lengthM: 0.5,
      widthM: 0.5,
      heightM: 0.5,
      weightKg: 120,
    );
    expect(expandPieces([cofre]).single.heavy, isTrue);
  });
}
