import 'package:flutter/material.dart';

import '../../app.dart';
import 'calibrate_page.dart';
import 'classify_page.dart';
import 'map_page.dart';
import 'recommend_page.dart';

class _Dest {
  const _Dest(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Casca responsiva: barra inferior no celular, trilho lateral em telas largas.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const List<_Dest> _destinations = <_Dest>[
    _Dest('Calibrar', Icons.straighten),
    _Dest('Mapear', Icons.chair_alt),
    _Dest('Classificar', Icons.checklist),
    _Dest('Recomendar', Icons.local_shipping),
  ];

  Widget _page(int index) {
    switch (index) {
      case 0:
        return const CalibratePage();
      case 1:
        return const MapPage();
      case 2:
        return const ClassifyPage();
      default:
        return const RecommendPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final body = KeyedSubtree(key: ValueKey<int>(state.tab), child: _page(state.tab));

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: state.tab,
              onDestinationSelected: state.goTo,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.tab,
        onDestinationSelected: state.goTo,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
