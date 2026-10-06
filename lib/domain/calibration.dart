import 'dart:math' as math;

/// Matemática de escala por referência (modo de calibração manual do PDF):
/// o usuário marca as duas pontas de um objeto de comprimento conhecido e o
/// app deriva quantos pixels equivalem a 1 metro NAQUELE plano da foto.
///
/// Limite físico: a escala só vale para pontos à mesma distância da câmera que
/// a referência. Por isso a referência deve estar no mesmo plano do móvel.

/// Referência com menos pixels que isso gera uma escala instável.
const double minReferencePixels = 24;

/// Se a referência ocupa menos que esta fração do maior lado da imagem, o erro
/// relativo cresce e o app avisa para chegar mais perto.
const double minReferenceShare = 0.15;

double pixelDistance(double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  return math.sqrt(dx * dx + dy * dy);
}

/// Pixels por metro, ou `null` se os dados forem inválidos ou instáveis.
double? scalePxPerMeter({
  required double referencePx,
  required double referenceMeters,
}) {
  if (!referencePx.isFinite || !referenceMeters.isFinite) return null;
  if (referencePx < minReferencePixels || referenceMeters <= 0) return null;
  return referencePx / referenceMeters;
}

double metersFromPx(double px, double pxPerMeter) => px / pxPerMeter;

double referenceShare(double referencePx, double imageLongSidePx) =>
    imageLongSidePx <= 0 ? 0 : referencePx / imageLongSidePx;
