import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/secure_temp.dart';
import '../../core/validators.dart';
import '../../domain/calibration.dart';
import '../../domain/furniture.dart';
import '../../domain/reference.dart';
import '../theme.dart';
import '../widgets/photo_measure_canvas.dart';

enum _Phase { camera, reference, measure }

/// Medição assistida por câmera, no modo “calibração manual por referência”:
///  1. tira a foto (fica só em memória e é descartada ao sair);
///  2. o usuário marca as duas pontas de um objeto de comprimento conhecido;
///  3. o app deriva a escala (px/m) e mede qualquer segmento no mesmo plano.
///
/// Devolve um mapa com as dimensões registradas (ou null se cancelar).
/// Com [target] nulo funciona como “medida livre” (teste de calibração).
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key, required this.reference, this.target});

  final ReferenceObject reference;
  final Dimension? target;

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.camera;
  CameraController? _controller;
  String? _cameraMessage;
  bool _busy = false;

  ui.Image? _image;
  double? _pxPerM;
  bool _lowShare = false;

  Offset _refA = const Offset(0.25, 0.5);
  Offset _refB = const Offset(0.75, 0.5);
  Offset _mA = const Offset(0.30, 0.30);
  Offset _mB = const Offset(0.70, 0.30);

  Dimension? _current;
  final Map<Dimension, double> _results = <Dimension, double>{};

  @override
  void initState() {
    super.initState();
    _current = widget.target;
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      // Libera a câmera quando o app sai de cena (privacidade e bateria).
      c.dispose();
      if (mounted) setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed && _phase == _Phase.camera) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (mounted) setState(() => _cameraMessage = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail('Nenhuma câmera foi encontrada neste dispositivo.');
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // enableAudio: false => o app nunca pede nem usa o microfone.
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      _fail(_friendlyCameraError(e));
    } catch (_) {
      _fail('Não foi possível iniciar a câmera.');
    }
  }

  String _friendlyCameraError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
      case 'NotAllowedError':
      case 'PermissionDeniedError':
        return 'O acesso à câmera foi negado. Libere a permissão nas '
            'configurações do aparelho ou do navegador e tente de novo.';
      default:
        return 'Não foi possível iniciar a câmera neste dispositivo.';
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _cameraMessage = message);
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      await deleteTempFile(file.path);
      final decoded = await decodeImageFromList(bytes);
      if (!mounted) {
        decoded.dispose();
        return;
      }
      try {
        await c.pausePreview();
      } catch (_) {
        // Algumas plataformas não suportam pausar; a foto já está congelada.
      }
      _image?.dispose();
      setState(() {
        _image = decoded;
        _phase = _Phase.reference;
        _pxPerM = null;
        _lowShare = false;
        _refA = const Offset(0.25, 0.5);
        _refB = const Offset(0.75, 0.5);
        _mA = const Offset(0.30, 0.30);
        _mB = const Offset(0.70, 0.30);
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Não foi possível tirar a foto. Tente novamente.');
    }
  }

  Future<void> _retake() async {
    _image?.dispose();
    setState(() {
      _image = null;
      _phase = _Phase.camera;
      _pxPerM = null;
    });
    try {
      await _controller?.resumePreview();
    } catch (_) {
      // Sem ação: se o preview não voltar, o usuário pode tentar de novo.
    }
  }

  double _pxBetween(ui.Image img, Offset a, Offset b) => pixelDistance(
        a.dx * img.width,
        a.dy * img.height,
        b.dx * img.width,
        b.dy * img.height,
      );

  void _confirmReference() {
    final img = _image;
    if (img == null) return;
    final refPx = _pxBetween(img, _refA, _refB);
    final scale = scalePxPerMeter(
      referencePx: refPx,
      referenceMeters: widget.reference.lengthM,
    );
    if (scale == null) {
      _snack('Os pontos estão muito próximos. Leve-os até as pontas da referência.');
      return;
    }
    final longSide = (img.width > img.height ? img.width : img.height).toDouble();
    setState(() {
      _pxPerM = scale;
      _lowShare = referenceShare(refPx, longSide) < minReferenceShare;
      _phase = _Phase.measure;
    });
  }

  void _onHandleMoved(int segment, int handle, Offset p) {
    setState(() {
      if (_phase == _Phase.reference) {
        if (handle == 0) {
          _refA = p;
        } else {
          _refB = p;
        }
      } else if (_phase == _Phase.measure && segment == 1) {
        if (handle == 0) {
          _mA = p;
        } else {
          _mB = p;
        }
      }
    });
  }

  void _register(double meters) {
    final d = _current;
    if (d == null) return;
    if (meters < Limits.minDimM || meters > Limits.maxDimM) {
      _snack('Medida fora do intervalo (0,05 a 12 m). Ajuste os pontos.');
      return;
    }
    setState(() => _results[d] = meters);
  }

  void _finish() {
    if (widget.target == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(Map<Dimension, double>.of(_results));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Medir com a câmera'),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_phase == _Phase.camera) return _cameraView();
    final img = _image;
    if (img == null) return const SizedBox.shrink();

    final segments = _phase == _Phase.reference
        ? <MeasureSegment>[
            MeasureSegment(a: _refA, b: _refB, color: AppColors.orange),
          ]
        : <MeasureSegment>[
            MeasureSegment(
              a: _refA,
              b: _refB,
              color: AppColors.teal,
              editable: false,
            ),
            MeasureSegment(
              a: _mA,
              b: _mB,
              color: Colors.white,
              label: fmtMeters(
                metersFromPx(_pxBetween(img, _mA, _mB), _pxPerM ?? 1),
              ),
            ),
          ];

    return Column(
      children: [
        Expanded(
          child: PhotoMeasureCanvas(
            image: img,
            segments: segments,
            onHandleMoved: _onHandleMoved,
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: Material(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _phase == _Phase.reference
                  ? _referencePanel(img)
                  : _measurePanel(img),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraView() {
    final message = _cameraMessage;
    if (message != null) {
      return _CameraProblem(message: message, onRetry: _initCamera);
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(c)),
        const IgnorePointer(child: CustomPaint(painter: _GuidePainter())),
        const Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: _Banner(
            'Fique de frente, com o celular paralelo ao móvel. '
            'Inclua na foto um objeto de referência no mesmo plano.',
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: FloatingActionButton.large(
              heroTag: null,
              tooltip: 'Tirar foto',
              onPressed: _busy ? null : _capture,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.camera_alt),
            ),
          ),
        ),
      ],
    );
  }

  Widget _referencePanel(ui.Image img) {
    final refPx = _pxBetween(img, _refA, _refB);
    final ok = scalePxPerMeter(
          referencePx: refPx,
          referenceMeters: widget.reference.lengthM,
        ) !=
        null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Marque a referência',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Arraste os pontos laranja até as duas pontas de '
          '“${widget.reference.name}” (${fmtLen(widget.reference.lengthM)}). '
          'Ela precisa estar no mesmo plano do que você vai medir.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: ok ? _confirmReference : null,
                child: const Text('Confirmar referência'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _retake,
              child: const Text('Refazer foto'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _measurePanel(ui.Image img) {
    final scale = _pxPerM ?? 1;
    final meters = metersFromPx(_pxBetween(img, _mA, _mB), scale);
    final target = widget.target;
    final current = _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lowShare)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.warning_amber_rounded, color: AppColors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A referência ocupa pouco da foto. Chegue mais perto '
                    'para medir com mais precisão.',
                  ),
                ),
              ],
            ),
          ),
        if (target != null && current != null) ...[
          SegmentedButton<Dimension>(
            showSelectedIcon: false,
            segments: <ButtonSegment<Dimension>>[
              for (final d in Dimension.values)
                ButtonSegment<Dimension>(value: d, label: Text(d.label)),
            ],
            selected: <Dimension>{current},
            onSelectionChanged: (s) => setState(() => _current = s.first),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          target == null || current == null
              ? 'Medida: ${fmtMeters(meters)}'
              : '${current.label}: ${fmtMeters(meters)}',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        const Text(
          'Arraste os pontos brancos até as extremidades do que quer medir.',
          style: TextStyle(color: AppColors.muted),
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final e in _results.entries)
                Chip(
                  avatar: const Icon(Icons.check_circle, size: 18, color: AppColors.teal),
                  label: Text('${e.key.short}  ${fmtMeters(e.value)}'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (target != null && current != null)
              FilledButton.icon(
                onPressed: () => _register(meters),
                icon: const Icon(Icons.add_task),
                label: Text('Registrar ${current.label.toLowerCase()}'),
              ),
            FilledButton.tonal(
              onPressed: (target == null || _results.isNotEmpty) ? _finish : null,
              child: const Text('Concluir'),
            ),
            OutlinedButton(
              onPressed: _retake,
              child: const Text('Refazer foto'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'No navegador, a câmera só funciona em páginas HTTPS. '
              'Você também pode digitar as medidas manualmente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grade de terços e mira central para alinhar o enquadramento.
class _GuidePainter extends CustomPainter {
  const _GuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        p,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        p,
      );
    }
    final c = Offset(size.width / 2, size.height / 2);
    final cross = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 2;
    canvas.drawLine(c - const Offset(14, 0), c + const Offset(14, 0), cross);
    canvas.drawLine(c - const Offset(0, 14), c + const Offset(0, 14), cross);
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) => false;
}
