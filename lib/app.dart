import 'dart:async';

import 'package:flutter/material.dart';

import 'data/inventory_repository.dart';
import 'state/app_state.dart';
import 'ui/pages/home_shell.dart';
import 'ui/theme.dart';

/// Disponibiliza o [AppState] para a árvore e reconstrói quem depende dele.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope não encontrado na árvore de widgets.');
    return scope!.notifier!;
  }
}

class CargaCertaApp extends StatefulWidget {
  const CargaCertaApp({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  State<CargaCertaApp> createState() => _CargaCertaAppState();
}

class _CargaCertaAppState extends State<CargaCertaApp> {
  late final AppState _state = AppState(widget.repository);

  @override
  void initState() {
    super.initState();
    unawaited(_state.load());
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'CargaCerta AR',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
