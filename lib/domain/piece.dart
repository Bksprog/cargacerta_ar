import 'dart:math' as math;

import 'furniture.dart';

/// Acima deste peso o item é tratado como pesado mesmo sem a marca.
const double autoHeavyThresholdKg = 80;

/// Carga máxima permitida sobre um item macio (“só carga leve”).
const double softMaxLoadKg = 15;

/// Menor unidade que o empacotador posiciona: um móvel ou, se desmontável,
/// uma de suas partes.
class Piece {
  const Piece({
    required this.itemId,
    required this.label,
    required this.l,
    required this.w,
    required this.h,
    required this.weightKg,
    required this.properties,
    required this.essential,
  });

  final String itemId;
  final String label;
  final double l;
  final double w;
  final double h;
  final double weightKg;
  final Set<ItemProperty> properties;
  final bool essential;

  bool get fragile => properties.contains(ItemProperty.fragile);
  bool get soft => properties.contains(ItemProperty.soft);
  bool get stackable => properties.contains(ItemProperty.stackable);
  bool get heavy =>
      properties.contains(ItemProperty.heavy) || weightKg >= autoHeavyThresholdKg;

  /// Peças frágeis, pesadas ou com “orientação” nunca são deitadas.
  bool get keepUpright =>
      properties.contains(ItemProperty.orientation) || fragile || heavy;

  /// Pode receber carga por cima (macio apenas carga leve, ver [softMaxLoadKg]).
  bool get canCarry => !fragile && (stackable || soft);

  double get volumeM3 => l * w * h;
  double get longestSide => math.max(l, math.max(w, h));
}

/// Expande móveis em peças: uma por unidade e, se “desmontável”, duas partes
/// com o maior lado dividido ao meio (recalcula como peças menores).
List<Piece> expandPieces(Iterable<FurnitureItem> items) {
  final out = <Piece>[];
  for (final it in items) {
    final props = <ItemProperty>{
      ...it.properties,
      if (it.weightKg >= autoHeavyThresholdKg) ItemProperty.heavy,
    };
    for (var q = 1; q <= it.quantity; q++) {
      final suffix = it.quantity > 1 ? ' #$q' : '';
      if (it.has(ItemProperty.disassemblable)) {
        final dims = <double>[it.lengthM, it.widthM, it.heightM];
        var idx = 0;
        for (var i = 1; i < 3; i++) {
          if (dims[i] > dims[idx]) idx = i;
        }
        for (var part = 1; part <= 2; part++) {
          final d = List<double>.of(dims);
          d[idx] = dims[idx] / 2;
          out.add(Piece(
            itemId: it.id,
            label: '${it.name}$suffix (parte $part/2)',
            l: d[0],
            w: d[1],
            h: d[2],
            weightKg: it.weightKg / 2,
            properties: props,
            essential: it.essential,
          ));
        }
      } else {
        out.add(Piece(
          itemId: it.id,
          label: '${it.name}$suffix',
          l: it.lengthM,
          w: it.widthM,
          h: it.heightM,
          weightKg: it.weightKg,
          properties: props,
          essential: it.essential,
        ));
      }
    }
  }
  return out;
}
