import 'furniture.dart';

/// Modelos rápidos para começar um cadastro. As medidas são típicas e devem
/// ser confirmadas (ou medidas com a câmera) antes de fechar o planejamento.
class FurniturePreset {
  const FurniturePreset({
    required this.name,
    required this.lengthM,
    required this.widthM,
    required this.heightM,
    required this.weightKg,
    this.quantity = 1,
    this.properties = const <ItemProperty>{},
  });

  final String name;
  final double lengthM;
  final double widthM;
  final double heightM;
  final double weightKg;
  final int quantity;
  final Set<ItemProperty> properties;
}

const FurniturePreset blankPreset = FurniturePreset(
  name: '',
  lengthM: 1.00,
  widthM: 0.50,
  heightM: 0.50,
  weightKg: 20,
);

const List<FurniturePreset> furniturePresets = <FurniturePreset>[
  FurniturePreset(
    name: 'Sofá',
    lengthM: 2.00,
    widthM: 0.90,
    heightM: 0.85,
    weightKg: 45,
    properties: {ItemProperty.heavy, ItemProperty.disassemblable},
  ),
  FurniturePreset(
    name: 'Mesa de jantar',
    lengthM: 1.60,
    widthM: 0.90,
    heightM: 0.75,
    weightKg: 35,
    properties: {ItemProperty.disassemblable, ItemProperty.stackable},
  ),
  FurniturePreset(
    name: 'Geladeira',
    lengthM: 0.70,
    widthM: 0.70,
    heightM: 1.80,
    weightKg: 70,
    properties: {ItemProperty.heavy, ItemProperty.fragile},
  ),
  FurniturePreset(
    name: 'Armário',
    lengthM: 1.20,
    widthM: 0.50,
    heightM: 2.00,
    weightKg: 60,
    properties: {ItemProperty.disassemblable, ItemProperty.orientation},
  ),
  FurniturePreset(
    name: 'Cama de casal (estrutura)',
    lengthM: 1.95,
    widthM: 1.45,
    heightM: 0.40,
    weightKg: 40,
    properties: {ItemProperty.disassemblable, ItemProperty.stackable},
  ),
  FurniturePreset(
    name: 'Colchão casal',
    lengthM: 1.88,
    widthM: 1.38,
    heightM: 0.25,
    weightKg: 25,
    properties: {ItemProperty.soft},
  ),
  FurniturePreset(
    name: 'Máquina de lavar',
    lengthM: 0.60,
    widthM: 0.65,
    heightM: 0.95,
    weightKg: 60,
    properties: {ItemProperty.heavy, ItemProperty.orientation},
  ),
  FurniturePreset(
    name: 'Caixas médias',
    lengthM: 0.50,
    widthM: 0.40,
    heightM: 0.40,
    weightKg: 12,
    quantity: 5,
    properties: {ItemProperty.stackable},
  ),
  FurniturePreset(
    name: 'Caixa frágil',
    lengthM: 0.45,
    widthM: 0.35,
    heightM: 0.35,
    weightKg: 8,
    properties: {ItemProperty.fragile, ItemProperty.orientation},
  ),
];

/// Cenário de demonstração inspirado no infográfico: sofá, mesa, geladeira e
/// armário, mais cama, colchão e caixas. Resulta em ~8,6 m³ de capacidade
/// mínima e em um caminhão 3/4 como veículo sugerido.
List<FurnitureItem> buildExampleItems() {
  FurnitureItem make(
    String name,
    double l,
    double w,
    double h,
    double kg,
    Set<ItemProperty> props, {
    int qty = 1,
  }) {
    return FurnitureItem(
      id: newId(),
      name: name,
      lengthM: l,
      widthM: w,
      heightM: h,
      weightKg: kg,
      quantity: qty,
      properties: props,
    );
  }

  return <FurnitureItem>[
    make('Sofá', 2.00, 0.90, 0.85, 45,
        {ItemProperty.heavy, ItemProperty.disassemblable}),
    make('Mesa de jantar', 1.60, 0.90, 0.75, 35,
        {ItemProperty.disassemblable, ItemProperty.stackable}),
    make('Geladeira', 0.70, 0.70, 1.80, 70,
        {ItemProperty.heavy, ItemProperty.fragile}),
    make('Armário', 1.20, 0.50, 2.00, 60,
        {ItemProperty.disassemblable, ItemProperty.orientation}),
    make('Cama de casal (estrutura)', 1.95, 1.45, 0.40, 40,
        {ItemProperty.disassemblable, ItemProperty.stackable}),
    make('Colchão casal', 1.88, 1.38, 0.25, 25, {ItemProperty.soft}),
    make('Caixas médias', 0.50, 0.40, 0.40, 12, {ItemProperty.stackable},
        qty: 8),
    make('Caixa frágil', 0.45, 0.35, 0.35, 8,
        {ItemProperty.fragile, ItemProperty.orientation}),
  ];
}
