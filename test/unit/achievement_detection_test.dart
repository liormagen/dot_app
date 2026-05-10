import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/models/progress_model.dart';

enum _AchievementType { none, firstEver, sessionStreak }

_AchievementType detectAchievement({
  required DifficultyMode difficulty,
  required String drawingId,
  required Set<String> completedDrawingIds,
  required int sessionCompletedCount,
}) {
  if (difficulty != DifficultyMode.easy && difficulty != DifficultyMode.normal) {
    return _AchievementType.none;
  }
  if (completedDrawingIds.contains(drawingId)) {
    return _AchievementType.none; // re-completion
  }
  if (completedDrawingIds.isEmpty && sessionCompletedCount == 0) {
    return _AchievementType.firstEver;
  }
  if (sessionCompletedCount >= 1) {
    return _AchievementType.sessionStreak;
  }
  return _AchievementType.none;
}

void main() {
  group('detectAchievement', () {
    test('returns none for hard difficulty', () {
      expect(detectAchievement(difficulty: DifficultyMode.hard, drawingId: 'abc', completedDrawingIds: {}, sessionCompletedCount: 0), _AchievementType.none);
    });
    test('returns none for superHard difficulty', () {
      expect(detectAchievement(difficulty: DifficultyMode.superHard, drawingId: 'abc', completedDrawingIds: {}, sessionCompletedCount: 0), _AchievementType.none);
    });
    test('returns none on re-completion', () {
      expect(detectAchievement(difficulty: DifficultyMode.easy, drawingId: 'abc', completedDrawingIds: {'abc'}, sessionCompletedCount: 1), _AchievementType.none);
    });
    test('returns firstEver on very first drawing ever', () {
      expect(detectAchievement(difficulty: DifficultyMode.easy, drawingId: 'abc', completedDrawingIds: {}, sessionCompletedCount: 0), _AchievementType.firstEver);
    });
    test('returns firstEver on normal difficulty too', () {
      expect(detectAchievement(difficulty: DifficultyMode.normal, drawingId: 'abc', completedDrawingIds: {}, sessionCompletedCount: 0), _AchievementType.firstEver);
    });
    test('returns sessionStreak after 1 completion this session', () {
      expect(detectAchievement(difficulty: DifficultyMode.easy, drawingId: 'xyz', completedDrawingIds: {'abc'}, sessionCompletedCount: 1), _AchievementType.sessionStreak);
    });
    test('returns sessionStreak after 3 completions this session', () {
      expect(detectAchievement(difficulty: DifficultyMode.easy, drawingId: 'new', completedDrawingIds: {'abc', 'def', 'ghi'}, sessionCompletedCount: 3), _AchievementType.sessionStreak);
    });
    test('returns none when first drawing of new session but has prior completions', () {
      expect(detectAchievement(difficulty: DifficultyMode.easy, drawingId: 'new', completedDrawingIds: {'old1', 'old2'}, sessionCompletedCount: 0), _AchievementType.none);
    });
  });
}
