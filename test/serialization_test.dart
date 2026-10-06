import 'dart:convert';

import 'package:cargacerta_ar/data/inventory_repository.dart';
import 'package:cargacerta_ar/domain/furniture.dart';
import 'package:cargacerta_ar/domain/presets.dart';
import 'package:cargacerta_ar/domain/reference.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _validItem() => <String, Object?>{
      'id': 'abcdef0123456789',
      'name': 'Sofá',
      'l': 2.0,
      'w': 0.9,
      'h': 0.85,
      'kg': 45.0,
      'qty': 1,
      'props': ['heavy', 'desconhecida'],
      'essential': true,
    };

void main() {
  test('ida e volta preserva os dados', () {
    final snap = InventorySnapshot(
      items: buildExampleItems(),
      reserveRatio: 0.25,
      reference: const ReferenceObject(kind: ReferenceKind.a4, lengthM: 0.297),
    );
    final json = jsonDecode(jsonEncode(snap.toJson()));
    final back = InventorySnapshot.tryFromJson(json);
    expect(back, isNotNull);
    expect(back!.items.length, snap.items.length);
    expect(back.items.first.name, snap.items.first.name);
    expect(back.reserveRatio, closeTo(0.25, 1e-9));
    expect(back.reference.kind, ReferenceKind.a4);
  });

  test('propriedades desconhecidas são ignoradas', () {
    final item = FurnitureItem.tryFromJson(_validItem());
    expect(item, isNotNull);
    expect(item!.properties, {ItemProperty.heavy});
    expect(item.essential, isTrue);
  });

  test('registro adulterado é descartado', () {
    final cases = <Map<String, Object?>>[
      {..._validItem(), 'l': 999},
      {..._validItem(), 'l': -1},
      {..._validItem(), 'kg': 0},
      {..._validItem(), 'qty': 1000},
      {..._validItem(), 'name': '   '},
      {..._validItem(), 'name': 123},
      {..._validItem(), 'w': 'abc'},
    ];
    for (final c in cases) {
      expect(FurnitureItem.tryFromJson(c), isNull, reason: '$c');
    }
  });

  test('id inválido é substituído por um id seguro', () {
    final item = FurnitureItem.tryFromJson({..._validItem(), 'id': '<script>'});
    expect(item, isNotNull);
    expect(item!.id, matches(RegExp(r'^[0-9a-f]{16}$')));
  });

  test('snapshot corrompido ou de outra versão vira null', () {
    expect(InventorySnapshot.tryFromJson('lixo'), isNull);
    expect(InventorySnapshot.tryFromJson(<String, Object?>{'v': 99}), isNull);
    expect(
      InventorySnapshot.tryFromJson(<String, Object?>{'v': 1, 'items': 'x'}),
      isNull,
    );
  });

  test('reserva e referência fora do intervalo voltam ao padrão', () {
    final snap = InventorySnapshot.tryFromJson(<String, Object?>{
      'v': 1,
      'items': <Object?>[_validItem()],
      'reserve': 9.0,
      'refKind': 'nada',
      'refLen': -5,
    });
    expect(snap, isNotNull);
    expect(snap!.reserveRatio, 0.40);
    expect(snap.reference.kind, ReferenceKind.door);
    expect(snap.reference.lengthM, 0.80);
  });
}
