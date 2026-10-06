import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/format.dart';

/// Segmento desenhado sobre a foto. Coordenadas NORMALIZADAS (0..1) em relação
/// à imagem, para que não dependam do tamanho da tela.
class MeasureSegment {
  const MeasureSegment({
    required this.a,
    required this.b,
    required this.color,
    this.label,
    this.editable = true,
  });

  final Offset a;
  final Offset b;
  final Color color;
  final String? label;
  final bool editable;
}

/// Maior retângulo com a proporção de [content] que cabe em [container],
/// centralizado (equivalente a BoxFit.contain).
Rect fitContain(Size container, Size content) {
  if (content.isEmpty || container.isEmpty) return Offset.zero & container;
  final scale = (container.width / content.width) <
          (container.height / content.height)
      ? container.width / content.width
      : container.height / content.height;
  final w = content.width * scale;
  final h = content.height * scale;
  return Rect.fromLTWH(
    (container.width - w) / 2,
    (container.height - h) / 2,
    w,
    h,
  );
}

class _HandleRef {
  const _HandleRef(this.segment, this.handle);
  final int segment;
  final int handle;
}

/// Foto congelada com alças arrastáveis. Arrastar move a alça mais próxima de
/// onde o dedo tocou (por deslocamento relativo, para o dedo não cobrir o
/// ponto); um toque simples reposiciona a alça mais próxima.
class PhotoMeasureCanvas extends StatefulWidget {
  const PhotoMeasureCanvas({
    super.key,
    required this.image,
    required this.segments,
    required this.onHandleMoved,
  });

  final ui.Image image;
  final List<MeasureSegment> segments;
  final void Function(int segment, int handle, Offset normalized)
      onHandleMoved;

  @override
  State<PhotoMeasureCanvas> createState() => _PhotoMeasureCanvasState();
}

class _PhotoMeasureCanvasState extends State<PhotoMeasureCanvas> {
  _HandleRef? _active;

  Offset _toScreen(Rect r, Offset n) =>
      Offset(r.left + n.dx * r.width, r.top + n.dy * r.height);

  Offset _toNorm(Rect r, Offset p) {
    if (r.width <= 0 || r.height <= 0) return const Offset(0.5, 0.5);
    return Offset(
      clampTo((p.dx - r.left) / r.width, 0, 1),
      clampTo((p.dy - r.top) / r.height, 0, 1),
    );
  }

  _HandleRef? _nearest(Rect r, Offset p) {
    _HandleRef? best;
    var bestDist = double.infinity;
    for (var i = 0; i < widget.segments.length; i++) {
      final s = widget.segments[i];
      if (!s.editable) continue;
      for (var h = 0; h < 2; h++) {
        final pos = _toScreen(r, h == 0 ? s.a : s.b);
        final d = (pos - p).distance;
        if (d < bestDist) {
          bestDist = d;
          best = _HandleRef(i, h);
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final imgSize = Size(
      widget.image.width.toDouble(),
      widget.image.height.toDouble(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final rect = fitContain(size, imgSize);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _active = _nearest(rect, d.localPosition),
          onPanUpdate: (d) {
            final a = _active;
            if (a == null || a.segment >= widget.segments.length) return;
            final seg = widget.segments[a.segment];
            final current = a.handle == 0 ? seg.a : seg.b;
            final moved = _toScreen(rect, current) + d.delta;
            widget.onHandleMoved(a.segment, a.handle, _toNorm(rect, moved));
          },
          onPanEnd: (_) => _active = null,
          onPanCancel: () => _active = null,
          onTapUp: (d) {
            final h = _nearest(rect, d.localPosition);
            if (h == null) return;
            widget.onHandleMoved(h.segment, h.handle, _toNorm(rect, d.localPosition));
          },
          child: Semantics(
            label: 'Foto para medir. Arraste os pontos até as extremidades.',
            child: CustomPaint(
              size: size,
              painter: _PhotoPainter(image: widget.image, segments: widget.segments),
            ),
          ),
        );
      },
    );
  }
}

class _PhotoPainter extends CustomPainter {
  _PhotoPainter({required this.image, required this.segments});

  final ui.Image image;
  final List<MeasureSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    final imgSize = Size(image.width.toDouble(), image.height.toDouble());
    final rect = fitContain(size, imgSize);
    canvas.drawImageRect(
      image,
      Offset.zero & imgSize,
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    for (final s in segments) {
      final pa = Offset(rect.left + s.a.dx * rect.width, rect.top + s.a.dy * rect.height);
      final pb = Offset(rect.left + s.b.dx * rect.width, rect.top + s.b.dy * rect.height);

      // Contorno escuro + linha colorida: legível em fundo claro e escuro.
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = const Color(0xAA000000)
          ..strokeWidth = s.editable ? 6 : 4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = s.color
          ..strokeWidth = s.editable ? 3 : 2
          ..strokeCap = StrokeCap.round,
      );

      for (final p in <Offset>[pa, pb]) {
        if (s.editable) {
          canvas.drawCircle(p, 15, Paint()..color = Colors.white);
          canvas.drawCircle(p, 12, Paint()..color = s.color);
          canvas.drawCircle(p, 3, Paint()..color = Colors.white);
        } else {
          canvas.drawCircle(p, 6, Paint()..color = Colors.white);
          canvas.drawCircle(p, 4, Paint()..color = s.color);
        }
      }

      final label = s.label;
      if (label != null) {
        _drawLabel(canvas, size, Offset.lerp(pa, pb, 0.5)!, label, s.color);
      }
    }
  }

  void _drawLabel(Canvas canvas, Size size, Offset anchor, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padH = 10.0;
    const padV = 5.0;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;
    var cx = anchor.dx;
    var cy = anchor.dy - 30;
    cx = clampTo(cx, w / 2 + 4, size.width - w / 2 - 4);
    cy = clampTo(cy, h / 2 + 4, size.height - h / 2 - 4);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      const Radius.circular(10),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xE6000000));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PhotoPainter old) =>
      old.image != image || old.segments != segments;
}
