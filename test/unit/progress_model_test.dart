import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/models/progress_model.dart';

void main() {
  group('ProgressModel', () {
    test('initial has normal difficulty', () {
      expect(ProgressModel.initial.difficulty, DifficultyMode.normal);
    });

    test('initial has english language', () {
      expect(ProgressModel.initial.selectedLanguage, 'en');
    });

    test('initial has onboarding incomplete', () {
      expect(ProgressModel.initial.onboardingComplete, isFalse);
    });

    test('copyWith difficulty changes only difficulty', () {
      final model = ProgressModel.initial.copyWith(difficulty: DifficultyMode.hard);
      expect(model.difficulty, DifficultyMode.hard);
      expect(model.selectedLanguage, ProgressModel.initial.selectedLanguage);
      expect(model.onboardingComplete, ProgressModel.initial.onboardingComplete);
    });

    test('copyWith preserves all other fields when only difficulty changes', () {
      final base = ProgressModel(
        completedDrawingIds: {'d1', 'd2'},
        selectedLanguage: 'he',
        onboardingComplete: true,
        musicEnabled: false,
        sfxEnabled: false,
        purchaseUnlocked: true,
        difficulty: DifficultyMode.easy,
      );
      final updated = base.copyWith(difficulty: DifficultyMode.superHard);
      expect(updated.difficulty, DifficultyMode.superHard);
      expect(updated.completedDrawingIds, {'d1', 'd2'});
      expect(updated.selectedLanguage, 'he');
      expect(updated.onboardingComplete, isTrue);
      expect(updated.musicEnabled, isFalse);
      expect(updated.sfxEnabled, isFalse);
      expect(updated.purchaseUnlocked, isTrue);
    });

    test('all four difficulty modes are distinct', () {
      final modes = DifficultyMode.values;
      expect(modes.toSet().length, 4);
      expect(modes, containsAll([
        DifficultyMode.easy,
        DifficultyMode.normal,
        DifficultyMode.hard,
        DifficultyMode.superHard,
      ]));
    });
  });

  group('ProgressModel.bestTimeMs', () {
    test('defaults to empty map', () {
      const model = ProgressModel();
      expect(model.bestTimeMs, isEmpty);
    });

    test('copyWith preserves bestTimeMs', () {
      const model = ProgressModel(bestTimeMs: {'abc': 5000});
      final copy = model.copyWith(musicEnabled: false);
      expect(copy.bestTimeMs, equals({'abc': 5000}));
    });

    test('copyWith can update bestTimeMs', () {
      const model = ProgressModel(bestTimeMs: {'abc': 5000});
      final updated = model.copyWith(bestTimeMs: {'abc': 4000, 'xyz': 3000});
      expect(updated.bestTimeMs, equals({'abc': 4000, 'xyz': 3000}));
    });

    test('toJson/fromJson round-trips bestTimeMs', () {
      const model = ProgressModel(bestTimeMs: {'drawing1': 12345, 'drawing2': 67890});
      final json = model.toJson();
      final restored = ProgressModel.fromJson(json);
      expect(restored.bestTimeMs, equals({'drawing1': 12345, 'drawing2': 67890}));
    });

    test('fromJson with missing bestTimeMs defaults to empty', () {
      final json = <String, dynamic>{};
      final model = ProgressModel.fromJson(json);
      expect(model.bestTimeMs, isEmpty);
    });
  });
}
