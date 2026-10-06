import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../core/validators.dart';
import '../data/inventory_repository.dart';
import '../domain/furniture.dart';
import '../domain/plan.dart';
import '../domain/presets.dart';
import '../domain/reference.dart';

/// Estado único do app. Imutável por fora: cada mudança troca a lista e
/// notifica; o plano de carga é calculado sob demanda e fica em cache.
class AppState extends ChangeNotifier {
  AppState(this._repository);

  final InventoryRepository _repository;

  int _tab = 0;
  ReferenceObject _reference = ReferenceObject.standard;
  List<FurnitureItem> _items = const <FurnitureItem>[];
  double _reserveRatio = Limits.defaultReserve;
  bool _loaded = false;
  LoadPlan? _plan;
  final PackCache _packCache = {};
  Timer? _saveTimer;

  int get tab => _tab;
  ReferenceObject get reference => _reference;
  List<FurnitureItem> get items => _items;
  double get reserveRatio => _reserveRatio;
  bool get loaded => _loaded;
  int get totalUnits => _items.fold<int>(0, (s, e) => s + e.quantity);
  bool get canAddMore =>
      _items.length < Limits.maxItems && totalUnits < Limits.maxTotalUnits;

  LoadPlan get plan => _plan ??= planLoad(
        _items,
        reserveRatio: _reserveRatio,
        cache: _packCache,
      );

  Future<void> load() async {
    final snap = await _repository.load();
    if (snap != null) {
      _items = snap.items;
      _reserveRatio = snap.reserveRatio;
      _reference = snap.reference;
    }
    _loaded = true;
    _invalidate(packChanged: true);
    notifyListeners();
  }

  void goTo(int index) {
    if (index < 0 || index > 3 || index == _tab) return;
    _tab = index;
    notifyListeners();
  }

  void setReferenceKind(ReferenceKind kind) {
    _reference = ReferenceObject.preset(kind);
    _commit(packChanged: false);
  }

  void setReferenceLength(double meters) {
    if (meters < Limits.minDimM || meters > 3.0) return;
    _reference = _reference.withLength(meters);
    _commit(packChanged: false);
  }

  void setReserve(double ratio) {
    _reserveRatio = clampTo(ratio, Limits.minReserve, Limits.maxReserve);
    _commit(packChanged: false);
  }

  /// Adiciona ou atualiza. Devolve uma mensagem de erro se algum limite for
  /// estourado (e nesse caso nada muda).
  String? upsert(FurnitureItem item) {
    final next = List<FurnitureItem>.of(_items);
    final idx = next.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      next[idx] = item;
    } else {
      if (next.length >= Limits.maxItems) {
        return 'Limite de ${Limits.maxItems} móveis atingido.';
      }
      next.add(item);
    }
    final units = next.fold<int>(0, (s, e) => s + e.quantity);
    if (units > Limits.maxTotalUnits) {
      return 'Limite de ${Limits.maxTotalUnits} unidades atingido. '
          'Reduza as quantidades.';
    }
    _items = next;
    _commit();
    return null;
  }

  void remove(String id) {
    _items = _items.where((e) => e.id != id).toList();
    _commit();
  }

  void setProperty(String id, ItemProperty property, {required bool on}) {
    _items = <FurnitureItem>[
      for (final e in _items)
        if (e.id == id) e.withProperty(property, on: on) else e,
    ];
    _commit();
  }

  void setEssential(String id, {required bool essential}) {
    _items = <FurnitureItem>[
      for (final e in _items)
        if (e.id == id) e.copyWith(essential: essential) else e,
    ];
    _commit();
  }

  void loadExample() {
    _items = buildExampleItems();
    _commit();
  }

  /// Apaga os móveis e o que foi salvo neste aparelho.
  Future<void> wipeLocalData() async {
    _saveTimer?.cancel();
    _items = const <FurnitureItem>[];
    _reserveRatio = Limits.defaultReserve;
    _reference = ReferenceObject.standard;
    _invalidate(packChanged: true);
    notifyListeners();
    await _repository.clear();
  }

  void _invalidate({required bool packChanged}) {
    _plan = null;
    if (packChanged) _packCache.clear();
  }

  void _commit({bool packChanged = true}) {
    _invalidate(packChanged: packChanged);
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_repository.save(InventorySnapshot(
        items: _items,
        reserveRatio: _reserveRatio,
        reference: _reference,
      )));
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
