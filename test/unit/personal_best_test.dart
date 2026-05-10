import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/models/progress_model.dart';

bool isNewPersonalBest({
  required DifficultyMode difficulty,
  required String drawingId,
  required int? elapsedMs,
  required Map<String, int> bestTimeMs,
}) {
  if (difficulty != DifficultyMode.hard && difficulty != DifficultyMode.superHard) {
    return false;
  }
  if (elapsedMs == null) return false;
  final previous = bestTimeMs[drawingId];
  if (previous == null) return true; // first time = always a record
  return elapsedMs < previous;
}

void main() {
  group('isNewPersonalBest', () {
    test('returns false for easy difficulty', () {
      expect(isNewPersonalBest(difficulty: DifficultyMode.easy, drawingId: 'abc', elapsedMs: 5000, bestTimeMs: {}), isFalse);
    });
    test('returns false for normal difficulty', () {
      expect(isNewPersonalBest(difficulty: DifficultyMode.normal, drawingId: 'abc', elapsedMs: 5000, bestTimeMs: {}), isFalse);
    });
    test('returns false when elapsedMs is null', () {
      expect(isNewPersonalBest(difficulty: DifficultyMode.hard, drawingId: 'abc', elapsedMs: null, bestTimeMs: {}), isFalse);
    });
    test('returns true on first completion (no previous record)', () {
      expect(isNewPersonalBest(difficulty: DifficultyMode.hard, drawingId: 'abc', elapsedMs: 8000, bestTimeMs: {}), isTrue);
    });
    test('returns true when beating previous record', () {
      expect(isNewPersonalBest(difficulty: DifficultyMode.hard, drawingId: 'abc', elapsedMs: 7000, bestTimeMs: {'abc': 8000}), isTrue);
    });
    test('returns false when not beating previous record', () {
      expect(isNewPersonalBest(difficulty: DifficultyMode.hard, drawingId: 'abc', elapsedMs: 9000, bestTimeMs: {'abc': 8000}), isFalse);
    });
    test('returns true for superHard difficulty on first completion', () {
      expect(isNewPersonalBest(difficulty: DifficultyMode.superHard, drawingId: 'abc', elapsedMs: 5000, bestTimeMs: {}), isTrue);
    });
  });
}
