import 'dart:math' as math;

import '../core/format.dart';
import '../core/validators.dart';
import 'estimate.dart';
import 'furniture.dart';
import 'load_planner.dart';
import 'piece.dart';
import 'vehicle.dart';

enum AlertSeverity { info, warning, critical }

class PlanAlert {
  const PlanAlert(this.severity, this.message);
  final AlertSeverity severity;
  final String message;
}

/// Resultado da avaliação de UM veículo do cadastro.
class VehicleEvaluation {
  const VehicleEvaluation({
    required this.vehicle,
    required this.volumeOk,
    required this.weightOk,
    required this.piecesFit,
    this.pack,
  });

  final Vehicle vehicle;
  final bool volumeOk;
  final bool weightOk;
  final bool piecesFit;

  /// Só é calculado quando as checagens baratas passam.
  final PackResult? pack;

  bool get packOk => pack != null && pack!.complete;
  bool get fits => volumeOk && weightOk && piecesFit && packOk;

  String get verdict {
    if (fits) return 'Compatível';
    if (!volumeOk) return 'Volume insuficiente';
    if (!weightOk) return 'Acima da carga útil';
    if (!piecesFit) return 'Há peça maior que o baú';
    return 'Não coube na simulação 3D';
  }
}

class LoadPlan {
  const LoadPlan({
    required this.estimate,
    required this.evaluations,
    required this.chosen,
    required this.display,
    required this.trips,
    required this.alerts,
  });

  factory LoadPlan.empty(VolumeEstimate estimate) => LoadPlan(
        estimate: estimate,
        evaluations: const <VehicleEvaluation>[],
        chosen: null,
        display: null,
        trips: 0,
        alerts: const <PlanAlert>[],
      );

  final VolumeEstimate estimate;
  final List<VehicleEvaluation> evaluations;

  /// Menor veículo que comporta tudo (null se nenhum comportar).
  final VehicleEvaluation? chosen;

  /// Disposição a exibir: a do veículo escolhido ou, se nenhum servir, a do
  /// maior veículo (mostra o que coube).
  final PackResult? display;

  /// 1 quando há veículo único; >= 2 quando nenhum comporta tudo de uma vez.
  final int trips;
  final List<PlanAlert> alerts;

  bool get isEmpty => evaluations.isEmpty;
  bool get hasSolution => chosen != null;
}

/// Cache de empacotamentos por veículo. Vale enquanto os itens não mudam
/// (a reserva não influencia a disposição geométrica).
typedef PackCache = Map<String, PackResult>;

LoadPlan planLoad(
  List<FurnitureItem> items, {
  List<Vehicle> fleet = defaultFleet,
  double reserveRatio = Limits.defaultReserve,
  PackCache? cache,
}) {
  final estimate = estimateVolume(items, reserveRatio: reserveRatio);
  if (items.isEmpty || fleet.isEmpty) return LoadPlan.empty(estimate);

  final pieces = expandPieces(items);
  final sorted = List<Vehicle>.of(fleet)
    ..sort((a, b) => a.volumeM3.compareTo(b.volumeM3));

  PackResult packFor(Vehicle v) {
    final hit = cache?[v.id];
    if (hit != null) return hit;
    final r = packPieces(pieces, v);
    cache?[v.id] = r;
    return r;
  }

  final evaluations = <VehicleEvaluation>[];
  VehicleEvaluation? chosen;
  for (final v in sorted) {
    final volumeOk = estimate.minCapacityM3 <= v.volumeM3 + 1e-9;
    final weightOk = estimate.totalWeightKg <= v.maxPayloadKg + 1e-9;
    final piecesFit = pieces.every((p) => pieceFitsVehicle(p, v));
    final pack = (volumeOk && weightOk && piecesFit) ? packFor(v) : null;
    final e = VehicleEvaluation(
      vehicle: v,
      volumeOk: volumeOk,
      weightOk: weightOk,
      piecesFit: piecesFit,
      pack: pack,
    );
    evaluations.add(e);
    if (chosen == null && e.fits) chosen = e;
  }

  final largest = sorted.last;
  PackResult? display;
  var trips = 1;
  if (chosen != null) {
    display = chosen.pack;
  } else {
    display = packFor(largest);
    final byVolume = (estimate.minCapacityM3 / largest.volumeM3).ceil();
    final byWeight = (estimate.totalWeightKg / largest.maxPayloadKg).ceil();
    trips = math.max(2, math.max(byVolume, byWeight));
  }

  return LoadPlan(
    estimate: estimate,
    evaluations: evaluations,
    chosen: chosen,
    display: display,
    trips: trips,
    alerts: _buildAlerts(items, pieces, estimate, chosen, largest, trips),
  );
}

String _names(Iterable<FurnitureItem> its) =>
    its.map((e) => e.name).toSet().join(', ');

List<PlanAlert> _buildAlerts(
  List<FurnitureItem> items,
  List<Piece> pieces,
  VolumeEstimate est,
  VehicleEvaluation? chosen,
  Vehicle largest,
  int trips,
) {
  final alerts = <PlanAlert>[];

  if (chosen == null) {
    alerts.add(PlanAlert(
      AlertSeverity.critical,
      'Nenhum veículo do cadastro comporta tudo de uma vez. '
      'Estimativa: $trips viagens com ${largest.name}.',
    ));
    final oversize = pieces.where((p) => !pieceFitsVehicle(p, largest)).toList();
    if (oversize.isNotEmpty) {
      alerts.add(PlanAlert(
        AlertSeverity.critical,
        'Não cabe nem no maior veículo: '
        '${oversize.map((p) => p.label).toSet().join(', ')}. '
        'Confira as medidas ou marque como Desmontável.',
      ));
    }
  } else {
    final pack = chosen.pack;
    if (pack != null && pack.fillRatio > 0.9) {
      alerts.add(PlanAlert(
        AlertSeverity.warning,
        'Carga muito justa (${fmtPercent(pack.fillRatio)} do baú). '
        'Considere o veículo seguinte.',
      ));
    }
    if (est.totalWeightKg > chosen.vehicle.maxPayloadKg * 0.85) {
      alerts.add(PlanAlert(
        AlertSeverity.warning,
        'Peso total (${fmtKg(est.totalWeightKg)}) perto do limite de '
        '${fmtKg(chosen.vehicle.maxPayloadKg)} do veículo.',
      ));
    }
  }

  final fragile = items.where((i) => i.has(ItemProperty.fragile));
  if (fragile.isNotEmpty) {
    alerts.add(PlanAlert(
      AlertSeverity.warning,
      'Frágil: sem peso por cima e com proteção extra (cobertores, cintas): '
      '${_names(fragile)}.',
    ));
  }
  final heavy = items.where(
    (i) => i.has(ItemProperty.heavy) || i.weightKg >= autoHeavyThresholdKg,
  );
  if (heavy.isNotEmpty) {
    alerts.add(PlanAlert(
      AlertSeverity.warning,
      'Pesado: carregar primeiro, no piso, com duas ou mais pessoas: '
      '${_names(heavy)}.',
    ));
  }
  final upright = items.where((i) => i.has(ItemProperty.orientation));
  if (upright.isNotEmpty) {
    alerts.add(PlanAlert(
      AlertSeverity.info,
      'Manter “este lado para cima” (não deitar): ${_names(upright)}.',
    ));
  }
  final soft = items.where((i) => i.has(ItemProperty.soft));
  if (soft.isNotEmpty) {
    alerts.add(PlanAlert(
      AlertSeverity.info,
      'Macio: só carga leve por cima (até ${fmtKg(softMaxLoadKg)}): '
      '${_names(soft)}.',
    ));
  }
  final dis = items.where((i) => i.has(ItemProperty.disassemblable));
  if (dis.isNotEmpty) {
    alerts.add(PlanAlert(
      AlertSeverity.info,
      'Desmontar antes e guardar parafusos em saco identificado: '
      '${_names(dis)}.',
    ));
  }
  final essentials = items.where((i) => i.essential);
  if (essentials.isNotEmpty) {
    alerts.add(PlanAlert(
      AlertSeverity.info,
      'Itens essenciais são carregados primeiro: ${_names(essentials)}.',
    ));
  }
  alerts.add(const PlanAlert(
    AlertSeverity.info,
    'Medidas feitas pela câmera são estimativas. Confirme as peças grandes '
    'com uma trena antes de fechar o orçamento.',
  ));
  return alerts;
}

/// Texto curto da posição da peça no baú.
String describePosition(Placement p, Vehicle v) {
  final restsOn = p.restsOn;
  if (restsOn != null) return 'Sobre $restsOn';
  final frac = v.lengthM <= 0 ? 0.0 : (p.x + p.dx / 2) / v.lengthM;
  final zone = frac < 0.34
      ? 'junto à cabine'
      : (frac < 0.67 ? 'meio do baú' : 'junto à porta');
  return 'Piso, $zone${p.tilted ? ' (deitado)' : ''}';
}

/// Resumo em texto puro para copiar/compartilhar.
String buildSummaryText(LoadPlan plan, List<FurnitureItem> items) {
  final b = StringBuffer()
    ..writeln('CargaCerta AR - resumo da mudança')
    ..writeln()
    ..writeln('Móveis:');
  for (final it in items) {
    b.writeln(
      '- ${it.name}${it.quantity > 1 ? ' x${it.quantity}' : ''}: '
      '${fmtDims(it.lengthM, it.widthM, it.heightM)}, ${fmtKg(it.weightKg)}',
    );
  }
  final e = plan.estimate;
  b
    ..writeln()
    ..writeln('Volume geométrico: ${fmtM3(e.geometricM3)}')
    ..writeln('Reserva (${fmtPercent(e.reserveRatio)}): ${fmtM3(e.reserveM3)}')
    ..writeln('Capacidade mínima estimada: ${fmtM3(e.minCapacityM3)}')
    ..writeln('Peso total: ${fmtKg(e.totalWeightKg)}');
  final chosen = plan.chosen;
  b.writeln(
    chosen != null
        ? 'Veículo sugerido: ${chosen.vehicle.name}'
        : 'Veículo sugerido: nenhum comporta tudo (${plan.trips} viagens)',
  );
  final display = plan.display;
  if (display != null && display.placements.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Ordem de carregamento:');
    for (final p in display.placements) {
      b.writeln(
        '${p.order}. ${p.piece.label} - ${describePosition(p, display.vehicle)}',
      );
    }
  }
  b
    ..writeln()
    ..writeln('Alertas:');
  for (final a in plan.alerts) {
    b.writeln('- ${a.message}');
  }
  return b.toString();
}
