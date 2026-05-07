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
}
