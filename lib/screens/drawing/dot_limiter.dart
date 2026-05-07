import 'dart:math';

import '../../models/dot_model.dart';
import '../../models/progress_model.dart';

/// Spatial-grid dot limiter. Picks up to maxDots dots scattered across the
/// canvas. Easy → 25, Normal → 100, Hard/SuperHard → unlimited.
/// Returns dots renumbered 1..N in their original spatial order.
List<DotModel> applyDotLimit(
  List<DotModel> dots,
  DifficultyMode mode,
  double canvasWidth,
  double canvasHeight,
) {
  final maxDots = mode == DifficultyMode.easy
      ? 25
      : mode == DifficultyMode.normal
          ? 100
          : dots.length;

  if (dots.length <= maxDots) return List<DotModel>.from(dots);

  final n = sqrt(maxDots.toDouble()).ceil();
  final cellW = canvasWidth / n;
  final cellH = canvasHeight / n;

  final sorted = List<DotModel>.from(dots)
    ..sort((a, b) => a.id.compareTo(b.id));
  final selected = <DotModel>{};

  for (int row = 0; row < n && selected.length < maxDots; row++) {
    for (int col = 0; col < n && selected.length < maxDots; col++) {
      final cx = (col + 0.5) * cellW;
      final cy = (row + 0.5) * cellH;

      DotModel? nearest;
      double nearestDist = double.infinity;
      for (final dot in sorted) {
        if (selected.contains(dot)) continue;
        final dx = dot.x - cx;
        final dy = dot.y - cy;
        final dist = dx * dx + dy * dy;
        if (dist < nearestDist) {
          nearestDist = dist;
          nearest = dot;
        }
      }
      if (nearest != null) selected.add(nearest);
    }
  }

  final sortedSelected = selected.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return sortedSelected
      .asMap()
      .entries
      .map((e) => DotModel(id: e.key + 1, x: e.value.x, y: e.value.y))
      .toList();
}
