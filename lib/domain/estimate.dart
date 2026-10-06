import 'dart:math' as math;

import '../core/format.dart';
import '../core/validators.dart';
import 'furniture.dart';
import 'piece.dart';

/// V = comprimento × largura × altura, somado por item, mais uma reserva
/// configurável para proteção e perdas de encaixe.
class VolumeEstimate {
  const VolumeEstimate({
    required this.geometricM3,
    required this.reserveRatio,
    required this.totalWeightKg,
    required this.largestPieceM,
    required this.itemCount,
    required this.unitCount,
  });

  final double geometricM3;
  final double reserveRatio;
  final double totalWeightKg;
  final double largestPieceM;
  final int itemCount;
  final int unitCount;

  double get reserveM3 => geometricM3 * reserveRatio;
  double get minCapacityM3 => geometricM3 + reserveM3;
}

VolumeEstimate estimateVolume(
  List<FurnitureItem> items, {
  double reserveRatio = Limits.defaultReserve,
}) {
  var volume = 0.0;
  var weight = 0.0;
  var units = 0;
  for (final it in items) {
    volume += it.totalVolumeM3;
    weight += it.totalWeightKg;
    units += it.quantity;
  }
  var longest = 0.0;
  for (final p in expandPieces(items)) {
    longest = math.max(longest, p.longestSide);
  }
  return VolumeEstimate(
    geometricM3: volume,
    reserveRatio: clampTo(reserveRatio, Limits.minReserve, Limits.maxReserve),
    totalWeightKg: weight,
    largestPieceM: longest,
    itemCount: items.length,
    unitCount: units,
  );
}
