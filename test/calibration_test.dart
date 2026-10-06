import 'package:cargacerta_ar/domain/calibration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distância em pixels', () {
    expect(pixelDistance(0, 0, 300, 400), closeTo(500, 1e-9));
  });

  test('escala e conversão para metros', () {
    // Porta de 0,80 m ocupando 400 px => 500 px/m.
    final scale = scalePxPerMeter(referencePx: 400, referenceMeters: 0.8);
    expect(scale, isNotNull);
    expect(scale!, closeTo(500, 1e-9));
    expect(metersFromPx(750, scale), closeTo(1.5, 1e-9));
  });

  test('referência pequena demais ou inválida não gera escala', () {
    expect(scalePxPerMeter(referencePx: 2, referenceMeters: 0.8), isNull);
    expect(scalePxPerMeter(referencePx: 400, referenceMeters: 0), isNull);
    expect(scalePxPerMeter(referencePx: double.nan, referenceMeters: 0.8), isNull);
    expect(
      scalePxPerMeter(referencePx: double.infinity, referenceMeters: 0.8),
      isNull,
    );
  });

  test('fração da imagem ocupada pela referência', () {
    expect(referenceShare(300, 1000), closeTo(0.3, 1e-9));
    expect(referenceShare(300, 0), 0);
  });
}
