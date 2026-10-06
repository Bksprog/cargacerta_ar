import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../domain/furniture.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Etapa 3: marcar as características de transporte de cada móvel.
class ClassifyPage extends StatelessWidget {
  const ClassifyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.items;
    return ResponsiveBody(
      children: [
        const StepHeader(
          step: 3,
          title: 'Classificar',
          subtitle: 'Defina características de transporte.',
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          EmptyState(
            icon: Icons.checklist,
            title: 'Nada para classificar',
            message: 'Adicione móveis na etapa 2 para marcar se são frágeis, '
                'pesados, desmontáveis e assim por diante.',
            action: FilledButton.icon(
              onPressed: () => state.goTo(1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Ir para Mapear'),
            ),
          )
        else ...[
          Text(
            'Móveis selecionados',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final it in items) ...[
            _ClassifyCard(item: it, state: state),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          const SectionCard(
            title: 'Como cada marca muda a carga',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Rule(ItemProperty.fragile),
                _Rule(ItemProperty.heavy),
                _Rule(ItemProperty.soft),
                _Rule(ItemProperty.stackable),
                _Rule(ItemProperty.disassemblable),
                _Rule(ItemProperty.orientation),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => state.goTo(3),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Ver recomendação'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ClassifyCard extends StatelessWidget {
  const _ClassifyCard({required this.item, required this.state});

  final FurnitureItem item;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final title = item.quantity > 1 ? '${item.name} ×${item.quantity}' : item.name;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${fmtDims(item.lengthM, item.widthM, item.heightM)} · ${fmtKg(item.weightKg)}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in ItemProperty.values)
                Tooltip(
                  message: p.hint,
                  child: FilterChip(
                    label: Text(p.label),
                    selected: item.has(p),
                    onSelected: (on) => state.setProperty(item.id, p, on: on),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Item essencial (sai primeiro)'),
            value: item.essential,
            onChanged: (v) => state.setEssential(item.id, essential: v),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.property);

  final ItemProperty property;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Align(alignment: Alignment.centerLeft, child: PropertyChip(property))),
          const SizedBox(width: 8),
          Expanded(child: Text(property.hint)),
        ],
      ),
    );
  }
}
