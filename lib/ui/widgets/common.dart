import 'package:flutter/material.dart';

import '../../domain/furniture.dart';
import '../theme.dart';

/// Cabeçalho de etapa no estilo do infográfico: número em círculo + título.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.steps[step - 1];
    return Semantics(
      container: true,
      label: 'Etapa $step de 4: $title. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
              child: Text(
                '$step',
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coluna rolável centralizada com largura máxima (boa em celular e desktop).
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: children,
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final heading = title;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (heading != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        heading,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Icon(icon, size: 44, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PropStyle {
  const _PropStyle(this.bg, this.fg, this.icon);
  final Color bg;
  final Color fg;
  final IconData icon;
}

_PropStyle _styleFor(ItemProperty p) {
  switch (p) {
    case ItemProperty.heavy:
      return const _PropStyle(Color(0xFFFDE7E7), Color(0xFFB3261E), Icons.fitness_center);
    case ItemProperty.disassemblable:
      return const _PropStyle(Color(0xFFE3EEFB), Color(0xFF1F5FA8), Icons.build_outlined);
    case ItemProperty.fragile:
      return const _PropStyle(Color(0xFFFFF0D6), Color(0xFF9A5B00), Icons.warning_amber_rounded);
    case ItemProperty.stackable:
      return const _PropStyle(Color(0xFFE2F4EA), Color(0xFF1E7A46), Icons.layers_outlined);
    case ItemProperty.orientation:
      return const _PropStyle(Color(0xFFEFE8FB), Color(0xFF5E3FA3), Icons.arrow_upward);
    case ItemProperty.soft:
      return const _PropStyle(Color(0xFFF3E8F5), Color(0xFF8A3FA0), Icons.bed_outlined);
  }
}

/// Selo somente leitura de uma característica (Pesado, Frágil, ...).
class PropertyChip extends StatelessWidget {
  const PropertyChip(this.property, {super.key});

  final ItemProperty property;

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(property);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 14, color: s.fg),
          const SizedBox(width: 4),
          Text(
            property.label,
            style: TextStyle(
              color: s.fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marca “Carga|Certa| AR” como no infográfico.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      color: AppColors.navy,
    );
    return Semantics(
      label: 'CargaCerta AR',
      excludeSemantics: true,
      child: Text.rich(
        const TextSpan(
          style: base,
          children: [
            TextSpan(text: 'Carga'),
            TextSpan(text: 'Certa', style: TextStyle(color: AppColors.teal)),
            TextSpan(text: ' AR'),
          ],
        ),
      ),
    );
  }
}
