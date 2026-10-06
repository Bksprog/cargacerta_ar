import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/validators.dart';
import '../../domain/load_planner.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/cargo_painter.dart';
import '../widgets/common.dart';

/// Etapa 4: volume estimado, veículo sugerido, ordem de carga e alertas.
class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  CargoViewMode _mode = CargoViewMode.iso;

  Future<void> _copySummary(AppState state) async {
    final text = buildSummaryText(state.plan, state.items);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Resumo copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ResponsiveBody(
      children: [
        const StepHeader(
          step: 4,
          title: 'Recomendar',
          subtitle: 'Receba o volume e o veículo ideal.',
        ),
        const SizedBox(height: 12),
        if (state.items.isEmpty)
          EmptyState(
            icon: Icons.local_shipping,
            title: 'Sem móveis para calcular',
            message: 'Cadastre os móveis para ver o volume, o veículo e a '
                'ordem de carregamento.',
            action: FilledButton.icon(
              onPressed: () => state.goTo(1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Ir para Mapear'),
            ),
          )
        else
          ..._content(context, state),
      ],
    );
  }

  List<Widget> _content(BuildContext context, AppState state) {
    final plan = state.plan;
    final est = plan.estimate;
    final display = plan.display;
    const gap = SizedBox(height: 12);
    final essentials = state.items.where((i) => i.essential).length;

    return <Widget>[
      _vehicleCard(context, plan),
      gap,
      SectionCard(
        title: 'Volume estimado',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fmtM3(est.minCapacityM3),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
            ),
            const Text(
              'capacidade mínima estimada',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            _kv('Volume geométrico dos itens', fmtM3(est.geometricM3)),
            _kv(
              'Reserva para proteção e encaixe (${fmtPercent(est.reserveRatio)})',
              '+ ${fmtM3(est.reserveM3)}',
            ),
            _kv('Peso total', fmtKg(est.totalWeightKg)),
            _kv('Maior peça (após desmontar)', fmtMeters(est.largestPieceM)),
            const SizedBox(height: 8),
            Text(
              'Reserva configurável: ${fmtPercent(est.reserveRatio)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            Slider(
              value: clampTo(state.reserveRatio, Limits.minReserve, Limits.maxReserve),
              min: Limits.minReserve,
              max: Limits.maxReserve,
              divisions: 35,
              label: fmtPercent(state.reserveRatio),
              onChanged: state.setReserve,
            ),
          ],
        ),
      ),
      gap,
      SectionCard(
        child: Row(
          children: [
            const Icon(Icons.format_list_numbered, color: AppColors.navy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prioridade', style: TextStyle(color: AppColors.muted)),
                  Text(
                    'Itens essenciais primeiro',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    essentials == 0
                        ? 'Nenhum item marcado como essencial (etapa 3).'
                        : '$essentials ${essentials == 1 ? 'item marcado' : 'itens marcados'}.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (display != null && display.placements.isNotEmpty) ...[
        gap,
        _cargoCard(context, display, plan),
      ],
      gap,
      _fleetCard(plan),
      if (display != null && display.placements.isNotEmpty) ...[
        gap,
        _orderCard(display),
      ],
      gap,
      _alertsCard(plan),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _copySummary(state),
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copiar resumo'),
        ),
      ),
    ];
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(k)),
          const SizedBox(width: 12),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _vehicleCard(BuildContext context, LoadPlan plan) {
    final chosen = plan.chosen;
    final display = plan.display;
    final vehicle = chosen?.vehicle ?? display?.vehicle;
    final ok = chosen != null;
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_shipping,
            size: 40,
            color: ok ? AppColors.navy : AppColors.danger,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Veículo sugerido', style: TextStyle(color: AppColors.muted)),
                Text(
                  chosen != null
                      ? chosen.vehicle.name
                      : 'Nenhum comporta tudo de uma vez',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                if (vehicle != null)
                  Text(
                    ok
                        ? 'Baú ${fmtDims(vehicle.lengthM, vehicle.widthM, vehicle.heightM)} · '
                            'carga útil ${fmtKg(vehicle.maxPayloadKg)}'
                        : 'Estimativa: ${plan.trips} viagens com ${vehicle.name}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cargoCard(BuildContext context, PackResult display, LoadPlan plan) {
    return SectionCard(
      title: 'Disposição no veículo',
      trailing: plan.hasSolution
          ? null
          : const Text('parcial', style: TextStyle(color: AppColors.danger)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<CargoViewMode>(
            showSelectedIcon: false,
            segments: <ButtonSegment<CargoViewMode>>[
              for (final m in CargoViewMode.values)
                ButtonSegment<CargoViewMode>(value: m, label: Text(m.label)),
            ],
            selected: <CargoViewMode>{_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.6,
            child: Semantics(
              label: 'Visualização ${_mode.label} do arranjo da carga em '
                  '${display.vehicle.name}, com ${display.placements.length} peças.',
              child: CustomPaint(
                painter: CargoPainter(result: display, mode: _mode),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(AppColors.blue, 'Pesado'),
              _Legend(AppColors.orange, 'Frágil'),
              _Legend(AppColors.purple, 'Macio'),
              _Legend(AppColors.teal, 'Demais'),
              _Legend(AppColors.gold, 'Contorno: essencial', outlineOnly: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ocupação do baú: ${fmtPercent(display.fillRatio)}. '
            'Os números indicam a ordem de carregamento.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (display.unplaced.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Não couberam: ${display.unplaced.map((p) => p.label).join(', ')}.',
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fleetCard(LoadPlan plan) {
    return SectionCard(
      title: 'Veículos avaliados',
      child: Column(
        children: [
          for (final e in plan.evaluations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    e.fits ? Icons.check_circle : Icons.cancel_outlined,
                    color: e.fits ? AppColors.teal : AppColors.muted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.vehicle.name,
                      style: TextStyle(
                        fontWeight: identical(e, plan.chosen)
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${fmtM3(e.vehicle.volumeM3)} · ${e.verdict}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _orderCard(PackResult display) {
    return SectionCard(
      title: 'Ordem de carregamento',
      child: Column(
        children: [
          for (final p in display.placements)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: pieceColor(p.piece),
                    child: Text(
                      '${p.order}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.piece.essential ? '${p.piece.label} (essencial)' : p.piece.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          describePosition(p, display.vehicle),
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _alertsCard(LoadPlan plan) {
    IconData icon(AlertSeverity s) {
      switch (s) {
        case AlertSeverity.critical:
          return Icons.error_outline;
        case AlertSeverity.warning:
          return Icons.warning_amber_rounded;
        case AlertSeverity.info:
          return Icons.info_outline;
      }
    }

    Color color(AlertSeverity s) {
      switch (s) {
        case AlertSeverity.critical:
          return AppColors.danger;
        case AlertSeverity.warning:
          return AppColors.orange;
        case AlertSeverity.info:
          return AppColors.blue;
      }
    }

    return SectionCard(
      title: 'Alertas',
      child: Column(
        children: [
          for (final a in plan.alerts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon(a.severity), color: color(a.severity), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(a.message)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label, {this.outlineOnly = false});

  final Color color;
  final String label;
  final bool outlineOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: outlineOnly ? Colors.white : color,
            borderRadius: BorderRadius.circular(4),
            border: outlineOnly ? Border.all(color: color, width: 2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
