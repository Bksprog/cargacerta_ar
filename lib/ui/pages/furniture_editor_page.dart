import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/validators.dart';
import '../../domain/furniture.dart';
import '../../domain/presets.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';
import 'measure_screen.dart';

/// Cadastro/edição de um móvel. Cada dimensão pode ser digitada ou medida
/// com a câmera. Devolve o [FurnitureItem] salvo (ou null se cancelar).
class FurnitureEditorPage extends StatefulWidget {
  const FurnitureEditorPage({super.key, this.existing, this.preset});

  final FurnitureItem? existing;
  final FurniturePreset? preset;

  @override
  State<FurnitureEditorPage> createState() => _FurnitureEditorPageState();
}

class _FurnitureEditorPageState extends State<FurnitureEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _l;
  late final TextEditingController _w;
  late final TextEditingController _h;
  late final TextEditingController _kg;
  late final TextEditingController _qty;
  late final Set<ItemProperty> _props;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.preset;
    _name = TextEditingController(text: e?.name ?? p?.name ?? '');
    _l = TextEditingController(text: fmtNum(e?.lengthM ?? p?.lengthM ?? 1.0));
    _w = TextEditingController(text: fmtNum(e?.widthM ?? p?.widthM ?? 0.5));
    _h = TextEditingController(text: fmtNum(e?.heightM ?? p?.heightM ?? 0.5));
    _kg = TextEditingController(
      text: fmtNum(e?.weightKg ?? p?.weightKg ?? 20, decimals: 1),
    );
    _qty = TextEditingController(text: '${e?.quantity ?? p?.quantity ?? 1}');
    _props = Set<ItemProperty>.of(
      e?.properties ?? p?.properties ?? const <ItemProperty>{},
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _l.dispose();
    _w.dispose();
    _h.dispose();
    _kg.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _measure(Dimension d) async {
    final ref = AppScope.of(context).reference;
    final result = await Navigator.of(context).push<Map<Dimension, double>>(
      MaterialPageRoute<Map<Dimension, double>>(
        builder: (_) => MeasureScreen(reference: ref, target: d),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final l = result[Dimension.length];
      final w = result[Dimension.width];
      final h = result[Dimension.height];
      if (l != null) _l.text = fmtNum(l);
      if (w != null) _w.text = fmtNum(w);
      if (h != null) _h.text = fmtNum(h);
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = sanitizeName(_name.text);
    final l = parseMeters(_l.text);
    final w = parseMeters(_w.text);
    final h = parseMeters(_h.text);
    final kg = parseKg(_kg.text);
    final qty = parseQuantity(_qty.text);
    if (name.isEmpty || l == null || w == null || h == null || kg == null || qty == null) {
      return;
    }
    final existing = widget.existing;
    final item = FurnitureItem(
      id: existing?.id ?? newId(),
      name: name,
      lengthM: l,
      widthM: w,
      heightM: h,
      weightKg: kg,
      quantity: qty,
      properties: Set<ItemProperty>.of(_props),
      essential: existing?.essential ?? false,
    );
    Navigator.of(context).pop(item);
  }

  Widget _dimField(Dimension d, TextEditingController c) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: decimalInputFormatters(),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: '${d.label} (${d.short})',
        suffixText: 'm',
        suffixIcon: IconButton(
          tooltip: 'Medir ${d.label.toLowerCase()} com a câmera',
          icon: const Icon(Icons.straighten),
          onPressed: () => _measure(d),
        ),
      ),
      validator: (v) => validateMeters(v, field: d.label.toLowerCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar móvel' : 'Novo móvel')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    maxLength: Limits.maxNameLength,
                    decoration: const InputDecoration(labelText: 'Nome do móvel'),
                    validator: validateName,
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final fields = <Widget>[
                        _dimField(Dimension.length, _l),
                        _dimField(Dimension.width, _w),
                        _dimField(Dimension.height, _h),
                      ];
                      if (constraints.maxWidth >= 560) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < fields.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: fields[i]),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < fields.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            fields[i],
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _kg,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: decimalInputFormatters(),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Peso (unidade)',
                            suffixText: 'kg',
                          ),
                          validator: validateKg,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _qty,
                          keyboardType: TextInputType.number,
                          inputFormatters: integerInputFormatters(),
                          decoration: const InputDecoration(labelText: 'Quantidade'),
                          validator: validateQuantity,
                          onFieldSubmitted: (_) => _save(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Características',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_props.isEmpty)
                          const Text(
                            'Nenhuma marcada.',
                            style: TextStyle(color: AppColors.muted),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [for (final p in _props) PropertyChip(p)],
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ajuste na etapa 3 (Classificar).',
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: Text(editing ? 'Salvar alterações' : 'Adicionar móvel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
