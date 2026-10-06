/// Formatação pt-BR feita à mão: evita a dependência `intl` (menos código de
/// terceiros = menor superfície de ataque na cadeia de suprimentos).

String fmtNum(double v, {int decimals = 2}) =>
    v.toStringAsFixed(decimals).replaceAll('.', ',');

String fmtMeters(double v) => '${fmtNum(v)} m';

/// Comprimentos pequenos (cartão, folha A4) aparecem em centímetros.
String fmtLen(double meters) =>
    meters < 0.5 ? '${fmtNum(meters * 100, decimals: 1)} cm' : fmtMeters(meters);

String fmtM3(double v, {int decimals = 1}) =>
    '${fmtNum(v, decimals: decimals)} m³';

String fmtKg(double v) =>
    v >= 100 ? '${v.round()} kg' : '${fmtNum(v, decimals: 1)} kg';

String fmtDims(double l, double w, double h) =>
    '${fmtNum(l)} × ${fmtNum(w)} × ${fmtNum(h)} m';

String fmtPercent(double ratio) => '${(ratio * 100).round()}%';

double clampTo(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);
