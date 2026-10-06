import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/load_planner.dart';
import '../../domain/piece.dart';
import '../theme.dart';

enum CargoViewMode {
  iso('3D'),
  side('Lateral'),
  top('Superior');

  const CargoViewMode(this.label);
  final String label;
}

/// Cor por tipo de peça (a mesma da legenda).
Color pieceColor(Piece p) {
  if (p.fragile) return AppColors.orange;
  if (p.heavy) return AppColors.blue;
  if (p.soft) return AppColors.purple;
  return AppColors.teal;
}

Color _shade(Color c, double factor) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness(clampTo(hsl.lightness * factor, 0.0, 1.0))
      .toColor();
}

/// Desenha o arranjo da carga no baú: isométrico, lateral ou superior.
/// Eixos do baú: x = comprimento (cabine à esquerda), y = largura, z = altura.
class CargoPainter extends CustomPainter {
  CargoPainter({required this.result, required this.mode});

  final PackResult result;
  final CargoViewMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case CargoViewMode.iso:
        _paintIso(canvas, size);
      case CargoViewMode.side:
        _paintSide(canvas, size);
      case CargoViewMode.top:
        _paintTop(canvas, size);
    }
  }

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    double size = 11,
    Color color = Colors.white,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  // ---------------------------------------------------------------- isométrico
  void _paintIso(Canvas canvas, Size size) {
    final v = result.vehicle;
    const c30 = 0.8660254037844386;
    const s30 = 0.5;

    Offset proj(double x, double y, double z) =>
        Offset((x - y) * c30, (x + y) * s30 - z);

    final corners = <Offset>[
      for (final x in <double>[0, v.lengthM])
        for (final y in <double>[0, v.widthM])
          for (final z in <double>[0, v.heightM]) proj(x, y, z),
    ];
    var minX = corners.first.dx, maxX = corners.first.dx;
    var minY = corners.first.dy, maxY = corners.first.dy;
    for (final c in corners) {
      minX = math.min(minX, c.dx);
      maxX = math.max(maxX, c.dx);
      minY = math.min(minY, c.dy);
      maxY = math.max(maxY, c.dy);
    }
    const pad = 12.0;
    final spanX = maxX - minX;
    final spanY = maxY - minY;
    final scale = math.min(
      (size.width - 2 * pad) / spanX,
      (size.height - 2 * pad) / spanY,
    );
    final offX = pad + ((size.width - 2 * pad) - spanX * scale) / 2 - minX * scale;
    final offY = pad + ((size.height - 2 * pad) - spanY * scale) / 2 - minY * scale;

    Offset pt(double x, double y, double z) {
      final p = proj(x, y, z);
      return Offset(p.dx * scale + offX, p.dy * scale + offY);
    }

    Path quad(Offset a, Offset b, Offset c, Offset d) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();

    // Piso e as duas paredes do fundo (cabine e lateral esquerda do baú).
    final floor = quad(pt(0, 0, 0), pt(v.lengthM, 0, 0), pt(v.lengthM, v.widthM, 0), pt(0, v.widthM, 0));
    final wallCab = quad(pt(0, 0, 0), pt(0, v.widthM, 0), pt(0, v.widthM, v.heightM), pt(0, 0, v.heightM));
    final wallSide = quad(pt(0, 0, 0), pt(v.lengthM, 0, 0), pt(v.lengthM, 0, v.heightM), pt(0, 0, v.heightM));
    canvas.drawPath(wallCab, Paint()..color = const Color(0xFFE6EEF7));
    canvas.drawPath(wallSide, Paint()..color = const Color(0xFFEEF3F9));
    canvas.drawPath(floor, Paint()..color = const Color(0xFFD9E4F0));
    for (final p in <Path>[floor, wallCab, wallSide]) {
      canvas.drawPath(p, _stroke(const Color(0xFF8AA0B8), 1.5));
    }

    // Painter's algorithm: de trás (perto da cabine/piso) para a frente.
    final sorted = List<Placement>.of(result.placements)
      ..sort((a, b) => (a.x + a.y + a.z).compareTo(b.x + b.y + b.z));

    for (final p in sorted) {
      final base = pieceColor(p.piece);
      final x0 = p.x, x1 = p.x2, y0 = p.y, y1 = p.y2, z0 = p.z, z1 = p.z2;

      final faceX = quad(pt(x1, y0, z0), pt(x1, y1, z0), pt(x1, y1, z1), pt(x1, y0, z1));
      final faceY = quad(pt(x0, y1, z0), pt(x1, y1, z0), pt(x1, y1, z1), pt(x0, y1, z1));
      final faceZ = quad(pt(x0, y0, z1), pt(x1, y0, z1), pt(x1, y1, z1), pt(x0, y1, z1));

      canvas.drawPath(faceY, Paint()..color = _shade(base, 0.75));
      canvas.drawPath(faceX, Paint()..color = _shade(base, 0.92));
      canvas.drawPath(faceZ, Paint()..color = _shade(base, 1.15));
      final edge = _stroke(const Color(0x99FFFFFF), 1);
      canvas.drawPath(faceY, edge);
      canvas.drawPath(faceX, edge);
      canvas.drawPath(faceZ, edge);
      if (p.piece.essential) {
        canvas.drawPath(faceZ, _stroke(AppColors.gold, 2.5));
      }

      final center = pt((x0 + x1) / 2, (y0 + y1) / 2, z1);
      final minSide = math.min(p.dx, p.dy) * scale;
      if (minSide > 22) {
        _text(canvas, '${p.order}', center);
      }
    }

    _text(canvas, 'CABINE', pt(0, v.widthM / 2, v.heightM) + const Offset(-4, -10),
        size: 10, color: AppColors.muted);
    _text(canvas, 'PORTA', pt(v.lengthM, v.widthM, 0) + const Offset(0, 12),
        size: 10, color: AppColors.muted);
  }

  // ------------------------------------------------------------------- lateral
  void _paintSide(Canvas canvas, Size size) {
    final v = result.vehicle;
    const pad = 16.0;
    final scale = math.min(
      (size.width - 2 * pad) / v.lengthM,
      (size.height - 2 * pad - 14) / v.heightM,
    );
    final w = v.lengthM * scale;
    final h = v.heightM * scale;
    final ox = (size.width - w) / 2;
    final oy = (size.height - h) / 2 + 8;
    final box = Rect.fromLTWH(ox, oy, w, h);
    canvas.drawRect(box, Paint()..color = const Color(0xFFE6EEF7));
    canvas.drawRect(box, _stroke(const Color(0xFF8AA0B8), 2));

    // Quem está mais perto de quem olha (menor y) é desenhado por último.
    final sorted = List<Placement>.of(result.placements)
      ..sort((a, b) => b.y.compareTo(a.y));
    for (final p in sorted) {
      final r = Rect.fromLTWH(
        ox + p.x * scale,
        oy + h - p.z2 * scale,
        p.dx * scale,
        p.dz * scale,
      );
      _block(canvas, r, p);
    }
    _text(canvas, 'CABINE', Offset(ox + 24, oy - 9), size: 10, color: AppColors.muted);
    _text(canvas, 'PORTA', Offset(ox + w - 20, oy - 9), size: 10, color: AppColors.muted);
  }

  // ------------------------------------------------------------------ superior
  void _paintTop(Canvas canvas, Size size) {
    final v = result.vehicle;
    const pad = 16.0;
    final scale = math.min(
      (size.width - 2 * pad) / v.lengthM,
      (size.height - 2 * pad - 14) / v.widthM,
    );
    final w = v.lengthM * scale;
    final h = v.widthM * scale;
    final ox = (size.width - w) / 2;
    final oy = (size.height - h) / 2 + 8;
    final box = Rect.fromLTWH(ox, oy, w, h);
    canvas.drawRect(box, Paint()..color = const Color(0xFFE6EEF7));
    canvas.drawRect(box, _stroke(const Color(0xFF8AA0B8), 2));

    // Peças mais altas por cima das mais baixas.
    final sorted = List<Placement>.of(result.placements)
      ..sort((a, b) => a.z.compareTo(b.z));
    for (final p in sorted) {
      final r = Rect.fromLTWH(ox + p.x * scale, oy + p.y * scale, p.dx * scale, p.dy * scale);
      _block(canvas, r, p);
    }
    _text(canvas, 'CABINE', Offset(ox + 24, oy - 9), size: 10, color: AppColors.muted);
    _text(canvas, 'PORTA', Offset(ox + w - 20, oy - 9), size: 10, color: AppColors.muted);
  }

  void _block(Canvas canvas, Rect r, Placement p) {
    final rr = RRect.fromRectAndRadius(r.deflate(0.5), const Radius.circular(3));
    canvas.drawRRect(rr, Paint()..color = pieceColor(p.piece));
    canvas.drawRRect(rr, _stroke(Colors.white, 1.5));
    if (p.piece.essential) {
      canvas.drawRRect(rr, _stroke(AppColors.gold, 2.5));
    }
    if (r.shortestSide > 16) {
      _text(canvas, '${p.order}', r.center);
    }
  }

  @override
  bool shouldRepaint(covariant CargoPainter old) =>
      old.result != result || old.mode != mode;
}
