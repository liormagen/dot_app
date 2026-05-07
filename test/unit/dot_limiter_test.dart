import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/models/dot_model.dart';
import 'package:dot_story/models/progress_model.dart';
import 'package:dot_story/screens/drawing/dot_limiter.dart';

// Builds a grid of n×n dots spread evenly over a 1000×1000 canvas.
List<DotModel> _makeGrid(int count) {
  final side = 1000.0;
  return List.generate(count, (i) {
    return DotModel(id: i + 1, x: (i % 10) * 100.0 + 50, y: (i ~/ 10) * 100.0 + 50);
  });
}

void main() {
  const canvasW = 1000.0;
  const canvasH = 1000.0;

  group('applyDotLimit — easy (max 25)', () {
    test('returns all dots unchanged when count <= 25', () {
      final dots = _makeGrid(20);
      final result = applyDotLimit(dots, DifficultyMode.easy, canvasW, canvasH);
      expect(result.length, 20);
    });

    test('limits to exactly 25 when over limit', () {
      final dots = _makeGrid(100);
      final result = applyDotLimit(dots, DifficultyMode.easy, canvasW, canvasH);
      expect(result.length, lessThanOrEqualTo(25));
    });

    test('renumbers selected dots from 1', () {
      final dots = _makeGrid(100);
      final result = applyDotLimit(dots, DifficultyMode.easy, canvasW, canvasH);
      final ids = result.map((d) => d.id).toList()..sort();
      expect(ids.first, 1);
      expect(ids.last, result.length);
    });
  });

  group('applyDotLimit — normal (max 100)', () {
    test('returns all dots unchanged when count <= 100', () {
      final dots = _makeGrid(80);
      final result = applyDotLimit(dots, DifficultyMode.normal, canvasW, canvasH);
      expect(result.length, 80);
    });

    test('limits to exactly 100 when over limit', () {
      final dots = _makeGrid(200);
      final result = applyDotLimit(dots, DifficultyMode.normal, canvasW, canvasH);
      expect(result.length, lessThanOrEqualTo(100));
    });
  });

  group('applyDotLimit — hard / superHard (no limit)', () {
    test('returns all dots for hard mode', () {
      final dots = _makeGrid(150);
      final result = applyDotLimit(dots, DifficultyMode.hard, canvasW, canvasH);
      expect(result.length, 150);
    });

    test('returns all dots for superHard mode', () {
      final dots = _makeGrid(150);
      final result = applyDotLimit(dots, DifficultyMode.superHard, canvasW, canvasH);
      expect(result.length, 150);
    });
  });

  group('applyDotLimit — spatial distribution', () {
    test('selected dots span the canvas (not all clustered)', () {
      // 100 dots in a 10×10 grid, easy mode → 25 selected.
      // With a good scatter the x range should be > 500.
      final dots = _makeGrid(100);
      final result = applyDotLimit(dots, DifficultyMode.easy, canvasW, canvasH);
      final xs = result.map((d) => d.x).toList();
      expect(xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b),
          greaterThan(500));
    });
  });
}
