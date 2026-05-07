import 'package:flutter/material.dart';

/// Returns a 2D affine [Matrix4] that scales by [newScale] keeping canvas
/// point (cx, cy) fixed in the viewport (i.e. the center of the viewport
/// maps to the same canvas point before and after the transform).
Matrix4 zoomMatrixCenteredOn(double newScale, double cx, double cy) {
  final m = Matrix4.identity();
  m.setEntry(0, 0, newScale);
  m.setEntry(1, 1, newScale);
  m.setEntry(0, 3, cx - newScale * cx);
  m.setEntry(1, 3, cy - newScale * cy);
  return m;
}

/// Returns a [Matrix4] that scales by [scale] and translates so that
/// canvas point (dotX, dotY) lands at viewport center (W/2, H/2).
Matrix4 snapToDotMatrix(
  double scale,
  double dotX,
  double dotY,
  double W,
  double H,
) {
  final m = Matrix4.identity();
  m.setEntry(0, 0, scale);
  m.setEntry(1, 1, scale);
  m.setEntry(0, 3, W / 2 - scale * dotX);
  m.setEntry(1, 3, H / 2 - scale * dotY);
  return m;
}

/// Returns the visible canvas [Rect] for a given [zoomMatrix] and
/// [viewportSize]. Used by the minimap to draw the viewport indicator.
Rect viewportRectFromMatrix(Matrix4 zoomMatrix, Size viewportSize) {
  final inv = Matrix4.inverted(zoomMatrix);
  final tl = MatrixUtils.transformPoint(inv, Offset.zero);
  final br = MatrixUtils.transformPoint(
    inv,
    Offset(viewportSize.width, viewportSize.height),
  );
  return Rect.fromPoints(tl, br);
}
