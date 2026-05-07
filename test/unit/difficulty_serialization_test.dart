import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/models/progress_model.dart';

void main() {
  group('parseDifficultyMode', () {
    test('parses "easy"', () {
      expect(parseDifficultyMode('easy'), DifficultyMode.easy);
    });

    test('parses "normal"', () {
      expect(parseDifficultyMode('normal'), DifficultyMode.normal);
    });

    test('parses "hard"', () {
      expect(parseDifficultyMode('hard'), DifficultyMode.hard);
    });

    test('parses "superHard"', () {
      expect(parseDifficultyMode('superHard'), DifficultyMode.superHard);
    });

    test('null defaults to normal', () {
      expect(parseDifficultyMode(null), DifficultyMode.normal);
    });

    test('unknown string defaults to normal', () {
      expect(parseDifficultyMode('banana'), DifficultyMode.normal);
    });

    test('round-trip: name → parse → same value', () {
      for (final mode in DifficultyMode.values) {
        expect(parseDifficultyMode(mode.name), mode,
            reason: 'round-trip failed for ${mode.name}');
      }
    });
  });
}
