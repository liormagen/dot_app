import 'package:flutter/material.dart';

import '../../models/dot_model.dart';
import 'drawing_types.dart';

const _kLineColors = [
  Color(0xFFFF6B6B),
  Color(0xFF6C48FF),
  Color(0xFFFFD93D),
  Color(0xFF6BCB77),
  Color(0xFF4FC3F7),
];

LineStyle _styleForIndex(int i) {
  switch (i % 3) {
    case 0:
      return LineStyle.sparkle;
    case 1:
      return LineStyle.wave;
    default:
      return LineStyle.glow;
  }
}

/// Builds a closed loop of [Connection]s for all [dots] in id order.
/// dot1→dot2→…→dotN→dot1. Used by the QA skip feature.
List<Connection> buildAllConnections(List<DotModel> dots) {
  if (dots.isEmpty) return [];
  final sorted = List<DotModel>.from(dots)
    ..sort((a, b) => a.id.compareTo(b.id));
  return List.generate(sorted.length, (i) {
    return Connection(
      from: sorted[i],
      to: sorted[(i + 1) % sorted.length],
      style: _styleForIndex(i),
      color: _kLineColors[i % _kLineColors.length],
    );
  });
}
