/// Objeto de comprimento conhecido usado para calibrar a escala da foto.
enum ReferenceKind {
  door('Largura da porta', 0.80),
  card('Cartão bancário (lado maior)', 0.086),
  a4('Folha A4 (lado maior)', 0.297),
  custom('Outra medida (trena)', 1.00);

  const ReferenceKind(this.label, this.defaultLengthM);
  final String label;
  final double defaultLengthM;
}

class ReferenceObject {
  const ReferenceObject({required this.kind, required this.lengthM});

  factory ReferenceObject.preset(ReferenceKind kind) =>
      ReferenceObject(kind: kind, lengthM: kind.defaultLengthM);

  static const ReferenceObject standard =
      ReferenceObject(kind: ReferenceKind.door, lengthM: 0.80);

  final ReferenceKind kind;
  final double lengthM;

  String get name => kind.label;

  ReferenceObject withLength(double meters) =>
      ReferenceObject(kind: kind, lengthM: meters);
}
