import 'dart:math' as math;

import 'package:cargacerta_ar/domain/furniture.dart';
import 'package:cargacerta_ar/domain/load_planner.dart';
import 'package:cargacerta_ar/domain/piece.dart';
import 'package:cargacerta_ar/domain/plan.dart';
import 'package:cargacerta_ar/domain/presets.dart';
import 'package:cargacerta_ar/domain/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

const double _e = 1e-6;

bool _overlapXY(Placement a, Placement b) {
  final ox = math.min(a.x2, b.x2) - math.max(a.x, b.x);
  final oy = math.min(a.y2, b.y2) - math.max(a.y, b.y);
  return ox > _e && oy > _e;
}

double _loadOn(PackResult r, Placement q) {
  var sum = 0.0;
  for (final p in r.placements) {
    if (p.z <= _e || (q.z2 - p.z).abs() > _e) continue;
    if (!_overlapXY(p, q)) continue;
    sum += p.piece.weightKg + _loadOn(r, p);
  }
  return sum;
}

/// Invariantes que TODA disposição deve respeitar, mesmo quando sobram peças.
void expectValid(PackResult r) {
  final v = r.vehicle;
  final ps = r.placements;

  for (final p in ps) {
    final id = p.piece.label;
    expect(p.x, greaterThanOrEqualTo(-_e), reason: id);
    expect(p.y, greaterThanOrEqualTo(-_e), reason: id);
    expect(p.z, greaterThanOrEqualTo(-_e), reason: id);
    expect(p.x2, lessThanOrEqualTo(v.lengthM + _e), reason: id);
    expect(p.y2, lessThanOrEqualTo(v.widthM + _e), reason: id);
    expect(p.z2, lessThanOrEqualTo(v.heightM + _e), reason: id);
    if (p.piece.heavy) {
      expect(p.z, lessThanOrEqualTo(_e), reason: 'pesado no piso: $id');
    }
    if (p.piece.keepUpright) {
      expect(p.tilted, isFalse, reason: 'não deitar: $id');
    }
  }

  for (var i = 0; i < ps.length; i++) {
    for (var j = i + 1; j < ps.length; j++) {
      final a = ps[i];
      final b = ps[j];
      final overlap = _overlapXY(a, b) &&
          a.z < b.z2 - _e &&
          a.z2 > b.z + _e;
      if (overlap) {
        fail('Sobreposição: ${a.piece.label} x ${b.piece.label}');
      }
    }
  }

  for (final p in ps) {
    if (p.z <= _e) continue;
    var supported = false;
    for (final q in ps) {
      if ((q.z2 - p.z).abs() > _e || !_overlapXY(p, q)) continue;
      supported = true;
      expect(q.piece.canCarry, isTrue,
          reason: '${q.piece.label} não pode carregar ${p.piece.label}');
      expect(p.piece.weightKg, lessThanOrEqualTo(q.piece.weightKg + _e),
          reason: 'mais pesado sobre mais leve: ${p.piece.label}');
    }
    expect(supported, isTrue, reason: 'peça flutuando: ${p.piece.label}');
  }

  for (final q in ps) {
    if (q.piece.soft) {
      expect(_loadOn(r, q), lessThanOrEqualTo(softMaxLoadKg + _e),
          reason: 'limite sobre macio: ${q.piece.label}');
    }
  }
}

FurnitureItem _item(
  String name,
  double l,
  double w,
  double h,
  double kg, {
  Set<ItemProperty> props = const <ItemProperty>{},
  int qty = 1,
  bool essential = false,
}) {
  return FurnitureItem(
    id: newId(),
    name: name,
    lengthM: l,
    widthM: w,
    heightM: h,
    weightKg: kg,
    quantity: qty,
    properties: props,
    essential: essential,
  );
}

Vehicle _byId(String id) => defaultFleet.firstWhere((v) => v.id == id);

void main() {
  group('exemplo do infográfico', () {
    final items = buildExampleItems();
    final plan = planLoad(items);

    test('sugere o caminhão 3/4 com tudo posicionado', () {
      expect(plan.hasSolution, isTrue);
      expect(plan.chosen!.vehicle.name, 'Caminhão 3/4');
      expect(plan.trips, 1);
      expect(plan.display!.complete, isTrue);
      expect(plan.display!.placements.length, expandPieces(items).length);
    });

    test('veículos menores são recusados pelo motivo certo', () {
      final byId = {for (final e in plan.evaluations) e.vehicle.id: e};
      expect(byId['utilitario']!.volumeOk, isFalse);
      expect(byId['van']!.volumeOk, isFalse);
      expect(byId['caminhao-34']!.fits, isTrue);
    });

    test('disposição respeita todas as regras', () {
      expectValid(plan.display!);
    });

    test('nada fica sobre peça frágil', () {
      final r = plan.display!;
      for (final f in r.placements.where((p) => p.piece.fragile)) {
        for (final p in r.placements) {
          final onTop = p.z > _e && (f.z2 - p.z).abs() <= _e && _overlapXY(p, f);
          expect(onTop, isFalse, reason: '${p.piece.label} sobre ${f.piece.label}');
        }
      }
    });

    test('resumo e alertas são gerados', () {
      expect(plan.alerts, isNotEmpty);
      final text = buildSummaryText(plan, items);
      expect(text, contains('Caminhão 3/4'));
      expect(text, contains('Ordem de carregamento'));
    });
  });

  group('recomendação', () {
    test('lista vazia gera plano vazio', () {
      final plan = planLoad(const <FurnitureItem>[]);
      expect(plan.isEmpty, isTrue);
      expect(plan.hasSolution, isFalse);
    });

    test('peça longa não desmontável pula veículos curtos', () {
      final plan = planLoad([_item('Escada', 5.0, 0.5, 0.5, 30)]);
      expect(plan.chosen!.vehicle.id, 'toco');
      final van = plan.evaluations.firstWhere((e) => e.vehicle.id == 'van');
      expect(van.piecesFit, isFalse);
      expect(van.verdict, 'Há peça maior que o baú');
    });

    test('desmontar resolve peça que não passaria', () {
      final plan = planLoad([
        _item('Escada', 5.0, 0.5, 0.5, 30, props: {ItemProperty.disassemblable}),
      ]);
      // Duas metades de 2,5 m cabem na van de 3,0 m.
      expect(plan.chosen!.vehicle.id, 'van');
    });

    test('peso acima da carga útil exclui o veículo', () {
      final plan = planLoad([_item('Bloco', 1.0, 1.0, 0.5, 700)]);
      final util = plan.evaluations.firstWhere((e) => e.vehicle.id == 'utilitario');
      expect(util.weightOk, isFalse);
      expect(plan.chosen!.vehicle.maxPayloadKg, greaterThanOrEqualTo(700));
    });

    test('quando nada comporta, indica viagens e alerta crítico', () {
      final plan = planLoad([
        _item('Pallet', 1.2, 1.0, 1.0, 100, qty: 99),
      ]);
      expect(plan.hasSolution, isFalse);
      expect(plan.trips, greaterThanOrEqualTo(2));
      expect(
        plan.alerts.any((a) => a.severity == AlertSeverity.critical),
        isTrue,
      );
      expect(plan.display, isNotNull);
      expectValid(plan.display!);
    });

    test('reserva maior pode empurrar para o veículo seguinte', () {
      // 2 cubos de 1,5 m = 6,75 m³ geométricos.
      final items = [_item('Cubo', 1.5, 1.5, 1.5, 20, qty: 2)];
      final tight = planLoad(items, reserveRatio: 0.05); // 7,09 m³ <= 8,17 m³
      final loose = planLoad(items, reserveRatio: 0.40); // 9,45 m³ >  8,17 m³
      expect(tight.chosen!.vehicle.id, 'van');
      expect(loose.chosen!.vehicle.id, 'caminhao-34');
    });
  });

  group('ordem de carregamento', () {
    test('itens essenciais entram primeiro', () {
      final items = [
        _item('Comum', 0.6, 0.6, 0.6, 10),
        _item('Essencial', 0.6, 0.6, 0.6, 10, essential: true),
      ];
      final pack = packPieces(expandPieces(items), _byId('van'));
      expect(pack.placements.first.piece.label, 'Essencial');
    });

    test('pesados vêm antes dos leves', () {
      final items = [
        _item('Caixa', 0.5, 0.5, 0.5, 5),
        _item('Cofre', 0.5, 0.5, 0.5, 90),
      ];
      final pack = packPieces(expandPieces(items), _byId('van'));
      expect(pack.placements.first.piece.label, 'Cofre');
      expect(pack.placements.first.onFloor, isTrue);
    });
  });

  group('regras de empilhamento', () {
    test('macio só recebe carga leve', () {
      final items = [
        _item('Colchão', 1.9, 1.4, 0.25, 25, props: {ItemProperty.soft}),
        _item('Caixas', 0.5, 0.4, 0.4, 12, qty: 6, props: {ItemProperty.stackable}),
      ];
      final pack = packPieces(expandPieces(items), _byId('van'));
      expect(pack.complete, isTrue);
      expectValid(pack);
    });
  });

  group('estresse com cenários pseudoaleatórios', () {
    test('invariantes valem em dezenas de cenários', () {
      final rng = math.Random(42);
      final allProps = ItemProperty.values;
      for (var n = 0; n < 40; n++) {
        final items = <FurnitureItem>[];
        final count = rng.nextInt(12) + 1;
        for (var k = 0; k < count; k++) {
          final props = <ItemProperty>{
            for (final p in allProps)
              if (rng.nextDouble() < 0.22) p,
          };
          items.add(_item(
            'i$k',
            0.2 + rng.nextDouble() * 2.0,
            0.2 + rng.nextDouble() * 1.3,
            0.2 + rng.nextDouble() * 1.8,
            2 + rng.nextDouble() * 88,
            props: props,
            qty: <int>[1, 1, 1, 2, 4, 9][rng.nextInt(6)],
          ));
        }
        final pieces = expandPieces(items);
        for (final v in defaultFleet.skip(1)) {
          expectValid(packPieces(pieces, v));
        }
      }
    });
  });
}
