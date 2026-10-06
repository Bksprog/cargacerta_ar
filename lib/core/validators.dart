import 'format.dart';

/// Limites de negócio e de segurança. Toda entrada (digitada, medida pela
/// câmera ou lida do armazenamento local) passa por estes limites.
abstract final class Limits {
  static const double minDimM = 0.05;
  static const double maxDimM = 12.0;
  static const double minWeightKg = 0.1;
  static const double maxWeightKg = 3000.0;
  static const int maxQuantity = 99;
  static const int maxItems = 60;

  /// Teto de unidades (soma das quantidades): protege o empacotador 3D.
  static const int maxTotalUnits = 150;
  static const int maxNameLength = 40;
  static const double minReserve = 0.05;
  static const double maxReserve = 0.40;
  static const double defaultReserve = 0.20;
}

final RegExp _decimalPattern = RegExp(r'^\d{1,4}([.,]\d{1,3})?$');
final RegExp _intPattern = RegExp(r'^\d{1,3}$');
final RegExp _invisibleChars = RegExp(
  r'[\u0000-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2066-\u2069]',
);
final RegExp _whitespaceRuns = RegExp(r'\s+');

/// Aceita só dígitos com vírgula ou ponto ("1,20" / "1.20"). Rejeita notação
/// científica, sinais, "NaN", "Infinity" e dígitos não-ASCII.
double? parseDecimal(String? input) {
  if (input == null) return null;
  final s = input.trim();
  if (!_decimalPattern.hasMatch(s)) return null;
  final v = double.tryParse(s.replaceAll(',', '.'));
  if (v == null || !v.isFinite) return null;
  return v;
}

double? parseMeters(String? input) {
  final v = parseDecimal(input);
  if (v == null) return null;
  if (v < Limits.minDimM || v > Limits.maxDimM) return null;
  return v;
}

double? parseKg(String? input) {
  final v = parseDecimal(input);
  if (v == null) return null;
  if (v < Limits.minWeightKg || v > Limits.maxWeightKg) return null;
  return v;
}

int? parseQuantity(String? input) {
  if (input == null) return null;
  final s = input.trim();
  if (!_intPattern.hasMatch(s)) return null;
  final v = int.tryParse(s);
  if (v == null || v < 1 || v > Limits.maxQuantity) return null;
  return v;
}

/// Remove caracteres de controle e de direção invisíveis, colapsa espaços e
/// limita o tamanho. O nome é sempre exibido como texto puro (nunca HTML).
String sanitizeName(String raw) {
  var s = raw.replaceAll(_invisibleChars, ' ');
  s = s.replaceAll(_whitespaceRuns, ' ').trim();
  if (s.runes.length > Limits.maxNameLength) {
    s = String.fromCharCodes(s.runes.take(Limits.maxNameLength)).trim();
  }
  return s;
}

String? validateMeters(String? input, {String field = 'o valor'}) {
  if (input == null || input.trim().isEmpty) return 'Informe $field';
  if (parseDecimal(input) == null) return 'Use só números (ex.: 1,20)';
  if (parseMeters(input) == null) {
    return 'Entre ${fmtNum(Limits.minDimM)} e ${fmtNum(Limits.maxDimM, decimals: 0)} m';
  }
  return null;
}

String? validateKg(String? input) {
  if (input == null || input.trim().isEmpty) return 'Informe o peso';
  if (parseDecimal(input) == null) return 'Use só números (ex.: 45)';
  if (parseKg(input) == null) {
    return 'Entre ${fmtNum(Limits.minWeightKg, decimals: 1)} e ${fmtNum(Limits.maxWeightKg, decimals: 0)} kg';
  }
  return null;
}

String? validateQuantity(String? input) {
  if (input == null || input.trim().isEmpty) return 'Informe a quantidade';
  if (parseQuantity(input) == null) {
    return 'Use um número de 1 a ${Limits.maxQuantity}';
  }
  return null;
}

String? validateName(String? input) {
  if (sanitizeName(input ?? '').isEmpty) return 'Dê um nome ao móvel';
  return null;
}
