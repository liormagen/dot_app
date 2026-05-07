import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/models/dot_model.dart';
import 'package:dot_story/screens/drawing/connection_builder.dart';
import 'package:dot_story/screens/drawing/drawing_types.dart';

List<DotModel> _dots(int count) =>
    List.generate(count, (i) => DotModel(id: i + 1, x: i * 10.0, y: 0));

void main() {
  group('buildAllConnections', () {
    test('returns exactly N connections for N dots', () {
      final result = buildAllConnections(_dots(5));
      expect(result.length, 5);
    });

    test('connections form a closed loop (last connects back to first)', () {
      final dots = _dots(4);
      final result = buildAllConnections(dots);
      expect(result.last.to.id, dots.first.id);
    });

    test('each connection leads into the next dot', () {
      final dots = _dots(4);
      final result = buildAllConnections(dots);
      for (int i = 0; i < dots.length - 1; i++) {
        expect(result[i].to.id, dots[i + 1].id);
      }
    });

    test('styles cycle through sparkle→wave→glow', () {
      final result = buildAllConnections(_dots(6));
      expect(result[0].style, LineStyle.sparkle);
      expect(result[1].style, LineStyle.wave);
      expect(result[2].style, LineStyle.glow);
      expect(result[3].style, LineStyle.sparkle);
    });

    test('colors cycle through the palette', () {
      final result = buildAllConnections(_dots(10));
      // Colors must not all be the same (palette has 5 entries)
      final uniqueColors = result.map((c) => c.color).toSet();
      expect(uniqueColors.length, greaterThan(1));
    });

    test('handles single dot — one self-loop connection', () {
      final result = buildAllConnections(_dots(1));
      expect(result.length, 1);
      expect(result.first.from.id, 1);
      expect(result.first.to.id, 1);
    });

    test('returns empty list for empty dot list', () {
      final result = buildAllConnections([]);
      expect(result, isEmpty);
    });

    test('dots are sorted by id before building connections', () {
      // Unsorted input: 3, 1, 2
      final unsorted = [
        DotModel(id: 3, x: 30, y: 0),
        DotModel(id: 1, x: 10, y: 0),
        DotModel(id: 2, x: 20, y: 0),
      ];
      final result = buildAllConnections(unsorted);
      expect(result.first.from.id, 1);
      expect(result[1].from.id, 2);
      expect(result[2].from.id, 3);
    });
  });
}
