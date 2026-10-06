import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/validators.dart';
import '../domain/furniture.dart';
import '../domain/reference.dart';

/// Tudo que o app guarda no aparelho. Fotos NUNCA são persistidas.
class InventorySnapshot {
  const InventorySnapshot({
    required this.items,
    required this.reserveRatio,
    required this.reference,
  });

  static const int version = 1;

  final List<FurnitureItem> items;
  final double reserveRatio;
  final ReferenceObject reference;

  Map<String, Object?> toJson() => <String, Object?>{
        'v': version,
        'items': items.map((e) => e.toJson()).toList(),
        'reserve': reserveRatio,
        'refKind': reference.kind.name,
        'refLen': reference.lengthM,
      };

  /// Valida tudo: o armazenamento local pode ser editado pelo usuário (ou por
  /// outra extensão/script no navegador), então nada é aceito às cegas.
  static InventorySnapshot? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    if (raw['v'] != version) return null;

    final rawItems = raw['items'];
    if (rawItems is! List || rawItems.length > Limits.maxItems) return null;

    final items = <FurnitureItem>[];
    var units = 0;
    for (final r in rawItems) {
      final it = FurnitureItem.tryFromJson(r);
      if (it == null) continue;
      if (units + it.quantity > Limits.maxTotalUnits) break;
      units += it.quantity;
      items.add(it);
    }

    final rawReserve = raw['reserve'];
    final reserve = rawReserve is num && rawReserve.isFinite
        ? clampTo(rawReserve.toDouble(), Limits.minReserve, Limits.maxReserve)
        : Limits.defaultReserve;

    var kind = ReferenceKind.door;
    final rawKind = raw['refKind'];
    if (rawKind is String) {
      for (final k in ReferenceKind.values) {
        if (k.name == rawKind) kind = k;
      }
    }
    final rawLen = raw['refLen'];
    final len = rawLen is num &&
            rawLen.isFinite &&
            rawLen >= Limits.minDimM &&
            rawLen <= 3.0
        ? rawLen.toDouble()
        : kind.defaultLengthM;

    return InventorySnapshot(
      items: items,
      reserveRatio: reserve,
      reference: ReferenceObject(kind: kind, lengthM: len),
    );
  }
}

abstract class InventoryRepository {
  Future<InventorySnapshot?> load();
  Future<void> save(InventorySnapshot snapshot);
  Future<void> clear();
}

class PrefsInventoryRepository implements InventoryRepository {
  static const String _key = 'cargacerta.inventory.v1';
  static const int _maxBytes = 200000;

  @override
  Future<InventorySnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.length > _maxBytes) return null;
      return InventorySnapshot.tryFromJson(jsonDecode(raw));
    } catch (_) {
      // Dado corrompido ou ilegível: começa limpo em vez de travar o app.
      return null;
    }
  }

  @override
  Future<void> save(InventorySnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Falha de armazenamento não deve derrubar o fluxo do usuário.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Sem ação possível.
    }
  }
}

/// Usado em testes e como alternativa sem persistência.
class InMemoryInventoryRepository implements InventoryRepository {
  InventorySnapshot? _snapshot;

  @override
  Future<InventorySnapshot?> load() async => _snapshot;

  @override
  Future<void> save(InventorySnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<void> clear() async => _snapshot = null;
}
