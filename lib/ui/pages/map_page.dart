import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/validators.dart';
import '../../domain/furniture.dart';
import '../../domain/presets.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'furniture_editor_page.dart';

/// Etapa 2: cadastrar/selecionar os móveis que serão transportados.
class MapPage extends StatelessWidget {
  const MapPage({super.key});

  Future<void> _addFlow(BuildContext context) async {
    final state = AppScope.of(context);
    final preset = await showModalBottomSheet<FurniturePreset>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PresetSheet(),
    );
    if (preset == null || !context.mounted) return;
    await _openEditor(context, state, preset: preset);
  }

  Future<void> _openEditor(
    BuildContext context,
    AppState state, {
    FurnitureItem? existing,
    FurniturePreset? preset,
  }) async {
    final result = await Navigator.of(context).push<FurnitureItem>(
      MaterialPageRoute<FurnitureItem>(
        builder: (_) => FurnitureEditorPage(existing: existing, preset: preset),
      ),
    );
    if (result == null || !context.mounted) return;
    final error = state.upsert(result);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _confirmWipe(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar todos os dados?'),
        content: const Text(
          'Remove os móveis e as configurações salvas neste aparelho. '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (ok == true) await state.wipeLocalData();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.items;
    return ResponsiveBody(
      children: [
        const StepHeader(
          step: 2,
          title: 'Mapear e selecionar',
          subtitle: 'Escaneie o ambiente e escolha os móveis.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: state.canAddMore ? () => _addFlow(context) : null,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar móvel'),
            ),
            OutlinedButton.icon(
              onPressed: state.loadExample,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Carregar exemplo'),
            ),
            if (items.isNotEmpty)
              TextButton.icon(
                onPressed: () => _confirmWipe(context, state),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Apagar dados'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!state.loaded)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (items.isEmpty)
          EmptyState(
            icon: Icons.chair_alt,
            title: 'Nenhum móvel ainda',
            message: 'Adicione os móveis medindo com a câmera ou digitando as '
                'medidas. Você também pode carregar um exemplo para testar.',
            action: FilledButton.icon(
              onPressed: () => _addFlow(context),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar o primeiro'),
            ),
          )
        else ...[
          Row(
            children: [
              Text(
                'Móveis detectados',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('${items.length}'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final it in items) ...[
            _ItemCard(
              item: it,
              onEdit: () => _openEditor(context, state, existing: it),
              onDelete: () {
                state.remove(it.id);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('“${it.name}” removido'),
                      action: SnackBarAction(
                        label: 'Desfazer',
                        onPressed: () => state.upsert(it),
                      ),
                    ),
                  );
              },
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => state.goTo(2),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Classificar'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final FurnitureItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = item.quantity > 1 ? '${item.name} ×${item.quantity}' : item.name;
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.chair_alt, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                if (item.properties.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final p in item.properties) PropertyChip(p)],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar ${item.name}',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remover ${item.name}',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _PresetSheet extends StatelessWidget {
  const _PresetSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Que móvel você vai adicionar?',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'O modelo traz medidas típicas. Você ajusta ou mede com a câmera na próxima tela.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in furniturePresets)
                  ActionChip(
                    label: Text(p.name),
                    onPressed: () => Navigator.of(context).pop(p),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Outro (medidas manuais)'),
                  onPressed: () => Navigator.of(context).pop(blankPreset),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Limite: ${Limits.maxItems} móveis e ${Limits.maxTotalUnits} unidades.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
