import 'dart:math' as math;

import '../core/validators.dart';

/// Características de transporte (as mesmas do infográfico e do PDF).
enum ItemProperty {
  disassemblable('Desmontável', 'Vira peças menores no cálculo.'),
  fragile('Frágil', 'Não recebe peso por cima.'),
  soft('Macio', 'Compressão limitada; só carga leve por cima (até 15 kg).'),
  heavy('Pesado', 'Vai no piso e é carregado primeiro.'),
  stackable('Empilhável', 'Pode receber outros itens por cima.'),
  orientation('Orientação', 'Manter “este lado para cima” (não deitar).');

  const ItemProperty(this.label, this.hint);
  final String label;
  final String hint;
}

enum Dimension {
  length('Comprimento', 'C'),
  width('Largura', 'L'),
  height('Altura', 'A');

  const Dimension(this.label, this.short);
  final String label;
  final String short;
}

final math.Random _secureRandom = math.Random.secure();
final RegExp _idPattern = RegExp(r'^[0-9a-f]{8,32}$');

/// Identificador aleatório criptograficamente seguro (16 hex).
String newId() => List<String>.generate(
      8,
      (_) => _secureRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

double? _asDouble(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

bool _inRange(double v, double lo, double hi) => v >= lo && v <= hi;

class FurnitureItem {
  const FurnitureItem({
    required this.id,
    required this.name,
    required this.lengthM,
    required this.widthM,
    required this.heightM,
    required this.weightKg,
    this.quantity = 1,
    this.properties = const <ItemProperty>{},
    this.essential = false,
  });

  final String id;
  final String name;
  final double lengthM;
  final double widthM;
  final double heightM;
  final double weightKg;
  final int quantity;
  final Set<ItemProperty> properties;

  /// Item essencial: carregado primeiro (sai primeiro da casa).
  final bool essential;

  bool has(ItemProperty p) => properties.contains(p);

  double get unitVolumeM3 => lengthM * widthM * heightM;
  double get totalVolumeM3 => unitVolumeM3 * quantity;
  double get totalWeightKg => weightKg * quantity;

  FurnitureItem copyWith({
    String? name,
    double? lengthM,
    double? widthM,
    double? heightM,
    double? weightKg,
    int? quantity,
    Set<ItemProperty>? properties,
    bool? essential,
  }) {
    return FurnitureItem(
      id: id,
      name: name ?? this.name,
      lengthM: lengthM ?? this.lengthM,
      widthM: widthM ?? this.widthM,
      heightM: heightM ?? this.heightM,
      weightKg: weightKg ?? this.weightKg,
      quantity: quantity ?? this.quantity,
      properties: properties ?? this.properties,
      essential: essential ?? this.essential,
    );
  }

  FurnitureItem withProperty(ItemProperty p, {required bool on}) {
    final next = Set<ItemProperty>.of(properties);
    if (on) {
      next.add(p);
    } else {
      next.remove(p);
    }
    return copyWith(properties: next);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'l': lengthM,
        'w': widthM,
        'h': heightM,
        'kg': weightKg,
        'qty': quantity,
        'props': properties.map((p) => p.name).toList(),
        'essential': essential,
      };

  /// Desserialização defensiva: dados do armazenamento local não são
  /// confiáveis (podem ter sido adulterados). Qualquer campo fora dos limites
  /// descarta o registro inteiro.
  static FurnitureItem? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    if (name is! String) return null;
    final cleanName = sanitizeName(name);
    if (cleanName.isEmpty) return null;

    final l = _asDouble(raw['l']);
    final w = _asDouble(raw['w']);
    final h = _asDouble(raw['h']);
    final kg = _asDouble(raw['kg']);
    if (l == null || w == null || h == null || kg == null) return null;
    if (!_inRange(l, Limits.minDimM, Limits.maxDimM)) return null;
    if (!_inRange(w, Limits.minDimM, Limits.maxDimM)) return null;
    if (!_inRange(h, Limits.minDimM, Limits.maxDimM)) return null;
    if (!_inRange(kg, Limits.minWeightKg, Limits.maxWeightKg)) return null;

    final qtyRaw = raw['qty'];
    final qty = qtyRaw is int ? qtyRaw : 1;
    if (qty < 1 || qty > Limits.maxQuantity) return null;

    final props = <ItemProperty>{};
    final rawProps = raw['props'];
    if (rawProps is List) {
      for (final p in rawProps) {
        if (p is! String) continue;
        for (final e in ItemProperty.values) {
          if (e.name == p) props.add(e);
        }
      }
    }

    final idRaw = raw['id'];
    final id = idRaw is String && _idPattern.hasMatch(idRaw) ? idRaw : newId();

    return FurnitureItem(
      id: id,
      name: cleanName,
      lengthM: l,
      widthM: w,
      heightM: h,
      weightKg: kg,
      quantity: qty,
      properties: props,
      essential: raw['essential'] == true,
    );
  }
}
