import 'dart:math' as math;

import 'piece.dart';
import 'vehicle.dart';

// Empacotamento 3D por "espaços vazios máximos" (EMS) com restrições:
//  - PESADO: só no piso.
//  - FRÁGIL / sem marca de empilhável: nada fica por cima.
//  - MACIO: só carga leve por cima (até [softMaxLoadKg]).
//  - Nada mais pesado sobre algo mais leve.
//  - ORIENTAÇÃO / FRÁGIL / PESADO: nunca deitados.
//  - Peça apoiada precisa de >= 80% da base sustentada.
// Eixos do baú: x = comprimento (0 = cabine), y = largura, z = altura.
// A ordem de carregamento é a ordem de posicionamento.

const double _eps = 1e-6;
const double _minSpace = 0.05;
const double _minSupportRatio = 0.8;

class Placement {
  const Placement({
    required this.piece,
    required this.order,
    required this.x,
    required this.y,
    required this.z,
    required this.dx,
    required this.dy,
    required this.dz,
    required this.tilted,
    this.restsOn,
  });

  final Piece piece;
  final int order;
  final double x;
  final double y;
  final double z;
  final double dx;
  final double dy;
  final double dz;
  final bool tilted;

  /// Nome da peça que serve de apoio (null se estiver no piso).
  final String? restsOn;

  double get x2 => x + dx;
  double get y2 => y + dy;
  double get z2 => z + dz;
  bool get onFloor => z <= _eps;
}

class PackResult {
  const PackResult({
    required this.vehicle,
    required this.placements,
    required this.unplaced,
  });

  final Vehicle vehicle;
  final List<Placement> placements;
  final List<Piece> unplaced;

  bool get complete => unplaced.isEmpty;
  int get tiltedCount => placements.where((p) => p.tilted).length;

  double get placedVolumeM3 =>
      placements.fold<double>(0, (s, p) => s + p.dx * p.dy * p.dz);

  double get fillRatio =>
      vehicle.volumeM3 <= 0 ? 0 : placedVolumeM3 / vehicle.volumeM3;
}

class _Orient {
  const _Orient(this.dx, this.dy, this.dz, this.tilted);
  final double dx;
  final double dy;
  final double dz;
  final bool tilted;
}

class _Space {
  const _Space(this.x, this.y, this.z, this.dx, this.dy, this.dz);
  final double x;
  final double y;
  final double z;
  final double dx;
  final double dy;
  final double dz;

  double get x2 => x + dx;
  double get y2 => y + dy;
  double get z2 => z + dz;

  bool contains(_Space o) =>
      o.x >= x - _eps &&
      o.y >= y - _eps &&
      o.z >= z - _eps &&
      o.x2 <= x2 + _eps &&
      o.y2 <= y2 + _eps &&
      o.z2 <= z2 + _eps;
}

class _Placed {
  _Placed({
    required this.piece,
    required this.x,
    required this.y,
    required this.z,
    required this.dx,
    required this.dy,
    required this.dz,
    required this.tilted,
    required this.supporters,
  });

  final Piece piece;
  final double x;
  final double y;
  final double z;
  final double dx;
  final double dy;
  final double dz;
  final bool tilted;
  final List<int> supporters;

  /// Peso total apoiado (direta ou indiretamente) sobre esta peça.
  double load = 0;

  double get x2 => x + dx;
  double get y2 => y + dy;
  double get z2 => z + dz;
}

class _Pt {
  const _Pt(this.x, this.y);
  final double x;
  final double y;
}

class _Candidate {
  const _Candidate(this.x, this.y, this.z, this.orient, this.supporters);
  final double x;
  final double y;
  final double z;
  final _Orient orient;
  final List<int> supporters;
}

List<_Orient> _uprightOrients(Piece p) {
  final a = _Orient(p.l, p.w, p.h, false);
  if ((p.l - p.w).abs() < _eps) return <_Orient>[a];
  return <_Orient>[a, _Orient(p.w, p.l, p.h, false)];
}

const List<List<int>> _permutations = <List<int>>[
  <int>[0, 1, 2],
  <int>[1, 0, 2],
  <int>[0, 2, 1],
  <int>[2, 0, 1],
  <int>[1, 2, 0],
  <int>[2, 1, 0],
];

/// Orientações deitadas (a altura deixa de ser a original).
List<_Orient> _tiltedOrients(Piece p) {
  final dims = <double>[p.l, p.w, p.h];
  final out = <_Orient>[];
  for (final pm in _permutations) {
    final dz = dims[pm[2]];
    if ((dz - p.h).abs() <= _eps) continue; // é vertical: já coberto
    final o = _Orient(dims[pm[0]], dims[pm[1]], dz, true);
    final dup = out.any((e) =>
        (e.dx - o.dx).abs() < _eps &&
        (e.dy - o.dy).abs() < _eps &&
        (e.dz - o.dz).abs() < _eps);
    if (!dup) out.add(o);
  }
  return out;
}

/// A peça cabe no compartimento (em alguma orientação permitida)?
bool pieceFitsVehicle(Piece p, Vehicle v) {
  final orients = <_Orient>[
    ..._uprightOrients(p),
    if (!p.keepUpright) ..._tiltedOrients(p),
  ];
  return orients.any((o) =>
      o.dx <= v.lengthM + _eps &&
      o.dy <= v.widthM + _eps &&
      o.dz <= v.heightM + _eps);
}

int _cmp(double a, double b) =>
    (a - b).abs() <= _eps ? 0 : (a < b ? -1 : 1);

int _compareBy(Piece a, Piece b, double Function(Piece) key) {
  // 1) essenciais primeiro  2) pesados  3) frágeis por último no grupo
  // 4) maior primeiro       5) mais pesado  6) nome (desempate estável)
  var c = (b.essential ? 1 : 0).compareTo(a.essential ? 1 : 0);
  if (c != 0) return c;
  c = (b.heavy ? 1 : 0).compareTo(a.heavy ? 1 : 0);
  if (c != 0) return c;
  c = (a.fragile ? 1 : 0).compareTo(b.fragile ? 1 : 0);
  if (c != 0) return c;
  c = key(a).compareTo(key(b));
  if (c != 0) return c;
  c = b.weightKg.compareTo(a.weightKg);
  if (c != 0) return c;
  return a.label.compareTo(b.label);
}

int _byFootprint(Piece a, Piece b) =>
    _compareBy(a, b, (p) => -(p.l * p.w));

int _byVolume(Piece a, Piece b) =>
    _compareBy(a, b, (p) => -(p.l * p.w * p.h));

class _Strategy {
  const _Strategy(this.compare, this.tiltInMainPass);
  final int Function(Piece, Piece) compare;
  final bool tiltInMainPass;
}

const List<_Strategy> _strategies = <_Strategy>[
  _Strategy(_byFootprint, false),
  _Strategy(_byFootprint, true),
  _Strategy(_byVolume, false),
  _Strategy(_byVolume, true),
];

double _overlapArea(_Placed q, double x, double y, double dx, double dy) {
  final ox = math.min(q.x2, x + dx) - math.max(q.x, x);
  final oy = math.min(q.y2, y + dy) - math.max(q.y, y);
  return (ox > _eps && oy > _eps) ? ox * oy : 0.0;
}

bool _softLoadOk(List<_Placed> placed, int idx, double w) {
  final q = placed[idx];
  if (q.piece.soft && q.load + w > softMaxLoadKg + _eps) return false;
  for (final k in q.supporters) {
    if (!_softLoadOk(placed, k, w)) return false;
  }
  return true;
}

void _addLoad(List<_Placed> placed, int idx, double w) {
  final q = placed[idx];
  q.load += w;
  for (final k in q.supporters) {
    _addLoad(placed, k, w);
  }
}

/// Devolve os índices dos apoios, ou null se a posição for inválida.
List<int>? _supportFor(
  Piece p,
  List<_Placed> placed,
  double x,
  double y,
  double z,
  _Orient o,
) {
  if (z <= _eps) return const <int>[];
  if (p.heavy) return null; // pesado só no piso
  final sup = <int>[];
  var area = 0.0;
  for (var i = 0; i < placed.length; i++) {
    final q = placed[i];
    if ((q.z2 - z).abs() > _eps) continue;
    final a = _overlapArea(q, x, y, o.dx, o.dy);
    if (a <= 0) continue;
    if (!q.piece.canCarry) return null;
    if (p.weightKg > q.piece.weightKg + _eps) return null;
    if (!_softLoadOk(placed, i, p.weightKg)) return null;
    sup.add(i);
    area += a;
  }
  if (area < _minSupportRatio * o.dx * o.dy - _eps) return null;
  return sup;
}

/// Pontos de ancoragem num espaço: o canto mínimo e, quando o espaço começa
/// acima do piso, os cantos do topo das peças de apoio (sem isso nunca se
/// tentaria empilhar exatamente sobre uma peça já posicionada).
List<_Pt> _anchors(_Space s, List<_Placed> placed, _Orient o) {
  final pts = <_Pt>[_Pt(s.x, s.y)];
  if (s.z > _eps) {
    for (final q in placed) {
      if ((q.z2 - s.z).abs() > _eps) continue;
      final cx = math.max(s.x, q.x);
      final cy = math.max(s.y, q.y);
      if (cx + o.dx > s.x2 + _eps || cy + o.dy > s.y2 + _eps) continue;
      final dup = pts.any(
        (e) => (e.x - cx).abs() < _eps && (e.y - cy).abs() < _eps,
      );
      if (!dup) pts.add(_Pt(cx, cy));
    }
  }
  return pts;
}

bool _intersects(_Space a, _Space b) =>
    a.x < b.x2 - _eps &&
    a.x2 > b.x + _eps &&
    a.y < b.y2 - _eps &&
    a.y2 > b.y + _eps &&
    a.z < b.z2 - _eps &&
    a.z2 > b.z + _eps;

List<_Space> _splitSpaces(List<_Space> spaces, _Space b) {
  final out = <_Space>[];
  for (final s in spaces) {
    if (!_intersects(s, b)) {
      out.add(s);
      continue;
    }
    if (b.x > s.x + _eps) {
      out.add(_Space(s.x, s.y, s.z, b.x - s.x, s.dy, s.dz));
    }
    if (b.x2 < s.x2 - _eps) {
      out.add(_Space(b.x2, s.y, s.z, s.x2 - b.x2, s.dy, s.dz));
    }
    if (b.y > s.y + _eps) {
      out.add(_Space(s.x, s.y, s.z, s.dx, b.y - s.y, s.dz));
    }
    if (b.y2 < s.y2 - _eps) {
      out.add(_Space(s.x, b.y2, s.z, s.dx, s.y2 - b.y2, s.dz));
    }
    if (b.z > s.z + _eps) {
      out.add(_Space(s.x, s.y, s.z, s.dx, s.dy, b.z - s.z));
    }
    if (b.z2 < s.z2 - _eps) {
      out.add(_Space(s.x, s.y, b.z2, s.dx, s.dy, s.z2 - b.z2));
    }
  }
  final kept = <_Space>[];
  for (var i = 0; i < out.length; i++) {
    final a = out[i];
    if (a.dx < _minSpace || a.dy < _minSpace || a.dz < _minSpace) continue;
    var contained = false;
    for (var j = 0; j < out.length; j++) {
      if (i == j) continue;
      final c = out[j];
      if (c.contains(a) && (!a.contains(c) || j < i)) {
        contained = true;
        break;
      }
    }
    if (!contained) kept.add(a);
  }
  return kept;
}

/// Menor é melhor: z, x, y, não-deitado, menor dx.
bool _better(_Candidate a, _Candidate b) {
  var c = _cmp(a.z, b.z);
  if (c != 0) return c < 0;
  c = _cmp(a.x, b.x);
  if (c != 0) return c < 0;
  c = _cmp(a.y, b.y);
  if (c != 0) return c < 0;
  c = (a.orient.tilted ? 1 : 0) - (b.orient.tilted ? 1 : 0);
  if (c != 0) return c < 0;
  return a.orient.dx < b.orient.dx - _eps;
}

PackResult _packOnce(
  List<Piece> pieces,
  Vehicle v,
  int Function(Piece, Piece) compare,
  bool tiltInMainPass,
) {
  final ordered = List<Piece>.of(pieces)..sort(compare);
  var spaces = <_Space>[_Space(0, 0, 0, v.lengthM, v.widthM, v.heightM)];
  final placed = <_Placed>[];
  final unplaced = <Piece>[];

  for (final p in ordered) {
    final groups = <List<_Orient>>[];
    if (tiltInMainPass && !p.keepUpright) {
      groups.add(<_Orient>[..._uprightOrients(p), ..._tiltedOrients(p)]);
    } else {
      groups.add(_uprightOrients(p));
      if (!p.keepUpright) groups.add(_tiltedOrients(p));
    }

    _Candidate? best;
    for (final group in groups) {
      for (final s in spaces) {
        for (final o in group) {
          if (o.dx > s.dx + _eps || o.dy > s.dy + _eps || o.dz > s.dz + _eps) {
            continue;
          }
          for (final a in _anchors(s, placed, o)) {
            final sup = _supportFor(p, placed, a.x, a.y, s.z, o);
            if (sup == null) continue;
            final cand = _Candidate(a.x, a.y, s.z, o, sup);
            final current = best;
            if (current == null || _better(cand, current)) best = cand;
          }
        }
      }
      if (best != null) break;
    }

    final chosen = best;
    if (chosen == null) {
      unplaced.add(p);
      continue;
    }
    final o = chosen.orient;
    placed.add(_Placed(
      piece: p,
      x: chosen.x,
      y: chosen.y,
      z: chosen.z,
      dx: o.dx,
      dy: o.dy,
      dz: o.dz,
      tilted: o.tilted,
      supporters: chosen.supporters,
    ));
    for (final k in chosen.supporters) {
      _addLoad(placed, k, p.weightKg);
    }
    spaces = _splitSpaces(
      spaces,
      _Space(chosen.x, chosen.y, chosen.z, o.dx, o.dy, o.dz),
    );
  }

  final placements = <Placement>[];
  for (var i = 0; i < placed.length; i++) {
    final q = placed[i];
    placements.add(Placement(
      piece: q.piece,
      order: i + 1,
      x: q.x,
      y: q.y,
      z: q.z,
      dx: q.dx,
      dy: q.dy,
      dz: q.dz,
      tilted: q.tilted,
      restsOn: q.supporters.isEmpty ? null : placed[q.supporters.first].piece.label,
    ));
  }
  return PackResult(vehicle: v, placements: placements, unplaced: unplaced);
}

/// [menos peças sem lugar, menor volume sem lugar, menos peças deitadas,
/// menor comprimento usado]
List<double> _score(PackResult r) {
  var unplacedVol = 0.0;
  for (final p in r.unplaced) {
    unplacedVol += p.volumeM3;
  }
  var maxX = 0.0;
  for (final p in r.placements) {
    maxX = math.max(maxX, p.x2);
  }
  return <double>[
    r.unplaced.length.toDouble(),
    unplacedVol,
    r.tiltedCount.toDouble(),
    maxX,
  ];
}

bool _lexLess(List<double> a, List<double> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] < b[i] - 1e-9) return true;
    if (a[i] > b[i] + 1e-9) return false;
  }
  return false;
}

/// Roda algumas estratégias de ordenação/inclinação (barato) e fica com a
/// melhor disposição.
PackResult packPieces(List<Piece> pieces, Vehicle v) {
  var best = _packOnce(
    pieces,
    v,
    _strategies.first.compare,
    _strategies.first.tiltInMainPass,
  );
  var bestScore = _score(best);
  for (var i = 1; i < _strategies.length; i++) {
    final s = _strategies[i];
    final r = _packOnce(pieces, v, s.compare, s.tiltInMainPass);
    final sc = _score(r);
    if (_lexLess(sc, bestScore)) {
      best = r;
      bestScore = sc;
    }
  }
  return best;
}
