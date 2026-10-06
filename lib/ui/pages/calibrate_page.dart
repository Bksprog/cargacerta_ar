import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/validators.dart';
import '../../domain/reference.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';
import 'measure_screen.dart';

/// Etapa 1: escolher o objeto de referência (e confirmar seu comprimento real).
class CalibratePage extends StatefulWidget {
  const CalibratePage({super.key});

  @override
  State<CalibratePage> createState() => _CalibratePageState();
}

class _CalibratePageState extends State<CalibratePage> {
  late final TextEditingController _length;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final ref = AppScope.of(context).reference;
      _length = TextEditingController(text: _lengthText(ref.lengthM));
      _initialized = true;
    }
  }

  @override
  void dispose() {
    if (_initialized) _length.dispose();
    super.dispose();
  }

  String _lengthText(double meters) =>
      fmtNum(meters, decimals: meters < 0.5 ? 3 : 2);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ref = state.reference;
    return ResponsiveBody(
      children: [
        const Align(alignment: Alignment.centerLeft, child: BrandMark()),
        const SizedBox(height: 12),
        const StepHeader(
          step: 1,
          title: 'Calibrar',
          subtitle: 'Informe uma medida real.',
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Objeto de referência',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escolha algo de tamanho conhecido que apareça na foto, no '
                'mesmo plano do móvel (por exemplo, a porta ao lado dele).',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in ReferenceKind.values)
                    ChoiceChip(
                      label: Text(k.label),
                      selected: ref.kind == k,
                      onSelected: (_) {
                        state.setReferenceKind(k);
                        _length.text = _lengthText(k.defaultLengthM);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _length,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimalInputFormatters(),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Comprimento real da referência',
                  helperText: 'Confirme com uma trena. Portas variam (0,60 a 0,90 m).',
                  suffixText: 'm',
                ),
                validator: (v) => validateMeters(v, field: 'o comprimento'),
                onChanged: (v) {
                  final m = parseMeters(v);
                  if (m != null) state.setReferenceLength(m);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.name,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmtLen(ref.lengthM),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: Color(0xFF5FD8C8), size: 32),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Dicas para medir bem',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Tip(Icons.crop_free, 'Fique de frente para o móvel, com o celular paralelo a ele.'),
              _Tip(Icons.layers_outlined, 'A referência precisa estar no mesmo plano (mesma distância) do que você mede.'),
              _Tip(Icons.zoom_in, 'Quanto maior a referência na foto, menor o erro.'),
              _Tip(Icons.wb_sunny_outlined, 'Boa iluminação ajuda a enxergar as bordas.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: AppColors.teal),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Privacidade: a câmera só é usada enquanto esta tela de medição '
                  'está aberta. As fotos ficam apenas na memória do aparelho, '
                  'não são enviadas a nenhum servidor nem salvas na galeria.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => MeasureScreen(reference: state.reference),
                  ),
                );
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Testar com a câmera'),
            ),
            FilledButton.icon(
              onPressed: () => state.goTo(1),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Mapear móveis'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
