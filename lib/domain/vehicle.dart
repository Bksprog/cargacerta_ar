/// Veículo do cadastro da transportadora. A recomendação usa as dimensões
/// INTERNAS do baú e a carga útil (peso máximo).
class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    required this.lengthM,
    required this.widthM,
    required this.heightM,
    required this.maxPayloadKg,
  });

  final String id;
  final String name;
  final double lengthM;
  final double widthM;
  final double heightM;
  final double maxPayloadKg;

  double get volumeM3 => lengthM * widthM * heightM;
}

/// Frota de exemplo (valores ilustrativos e editáveis). Troque pelos dados
/// reais da transportadora; a lista é a única fonte usada pelo recomendador.
const List<Vehicle> defaultFleet = <Vehicle>[
  Vehicle(
    id: 'utilitario',
    name: 'Utilitário pequeno',
    lengthM: 1.80,
    widthM: 1.20,
    heightM: 1.25,
    maxPayloadKg: 600,
  ),
  Vehicle(
    id: 'van',
    name: 'Van de carga',
    lengthM: 3.00,
    widthM: 1.65,
    heightM: 1.65,
    maxPayloadKg: 1000,
  ),
  Vehicle(
    id: 'caminhao-34',
    name: 'Caminhão 3/4',
    lengthM: 4.20,
    widthM: 2.10,
    heightM: 2.10,
    maxPayloadKg: 3000,
  ),
  Vehicle(
    id: 'toco',
    name: 'Caminhão toco',
    lengthM: 6.00,
    widthM: 2.40,
    heightM: 2.40,
    maxPayloadKg: 6000,
  ),
  Vehicle(
    id: 'truck',
    name: 'Caminhão truck',
    lengthM: 8.00,
    widthM: 2.50,
    heightM: 2.60,
    maxPayloadKg: 12000,
  ),
];
