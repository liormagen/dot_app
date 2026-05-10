import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dot_story/models/progress_model.dart';
import 'package:dot_story/services/progress_service.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Future<ProgressService> _freshService([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final svc = ProgressService();
  await svc.init();
  return svc;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProgressService.load', () {
    test('returns initial model when prefs are empty', () async {
      final svc = await _freshService();
      final model = svc.load();
      expect(model.completedDrawingIds, isEmpty);
      expect(model.selectedLanguage, 'en');
      expect(model.musicEnabled, true);
      expect(model.sfxEnabled, true);
      expect(model.purchaseUnlocked, false);
      expect(model.onboardingComplete, false);
      expect(model.difficulty, DifficultyMode.normal);
    });

    test('restores all fields from pre-populated prefs', () async {
      final svc = await _freshService({
        'completed_drawings': ['d1', 'd2'],
        'language': 'he',
        'onboarding_complete': true,
        'music_enabled': false,
        'sfx_enabled': false,
        'purchase_unlocked': true,
        'difficulty': 'hard',
      });
      final model = svc.load();
      expect(model.completedDrawingIds, {'d1', 'd2'});
      expect(model.selectedLanguage, 'he');
      expect(model.onboardingComplete, true);
      expect(model.musicEnabled, false);
      expect(model.sfxEnabled, false);
      expect(model.purchaseUnlocked, true);
      expect(model.difficulty, DifficultyMode.hard);
    });
  });

  group('ProgressService.markDrawingComplete', () {
    test('persists a drawing id and reloads it', () async {
      final svc = await _freshService();
      await svc.markDrawingComplete('drawing_42');
      expect(svc.load().completedDrawingIds, contains('drawing_42'));
    });

    test('marking the same drawing twice does not duplicate it', () async {
      final svc = await _freshService();
      await svc.markDrawingComplete('d1');
      await svc.markDrawingComplete('d1');
      expect(svc.load().completedDrawingIds.length, 1);
    });

    test('multiple different drawings are all persisted', () async {
      final svc = await _freshService();
      await svc.markDrawingComplete('d1');
      await svc.markDrawingComplete('d2');
      await svc.markDrawingComplete('d3');
      expect(svc.load().completedDrawingIds, {'d1', 'd2', 'd3'});
    });
  });

  group('ProgressService.setPurchaseUnlocked', () {
    test('persists true and reloads it', () async {
      final svc = await _freshService();
      await svc.setPurchaseUnlocked(true);
      expect(svc.load().purchaseUnlocked, true);
    });

    test('can be toggled back to false', () async {
      final svc = await _freshService({'purchase_unlocked': true});
      await svc.setPurchaseUnlocked(false);
      expect(svc.load().purchaseUnlocked, false);
    });
  });

  group('ProgressService.setLanguage', () {
    test('persists the new language', () async {
      final svc = await _freshService();
      await svc.setLanguage('ar');
      expect(svc.load().selectedLanguage, 'ar');
    });

    test('can be changed multiple times', () async {
      final svc = await _freshService();
      await svc.setLanguage('he');
      await svc.setLanguage('ar');
      expect(svc.load().selectedLanguage, 'ar');
    });
  });

  group('ProgressService.save round-trip', () {
    test('save then load returns the same model', () async {
      final svc = await _freshService();
      final original = ProgressModel(
        completedDrawingIds: const {'d1', 'd2'},
        selectedLanguage: 'he',
        onboardingComplete: true,
        musicEnabled: false,
        sfxEnabled: false,
        purchaseUnlocked: true,
        difficulty: DifficultyMode.superHard,
      );
      await svc.save(original);
      final loaded = svc.load();
      expect(loaded.completedDrawingIds, original.completedDrawingIds);
      expect(loaded.selectedLanguage, original.selectedLanguage);
      expect(loaded.onboardingComplete, original.onboardingComplete);
      expect(loaded.musicEnabled, original.musicEnabled);
      expect(loaded.sfxEnabled, original.sfxEnabled);
      expect(loaded.purchaseUnlocked, original.purchaseUnlocked);
      expect(loaded.difficulty, original.difficulty);
    });
  });

  group('ProgressService.setDifficulty', () {
    test('persists each difficulty mode', () async {
      for (final mode in DifficultyMode.values) {
        final svc = await _freshService();
        await svc.setDifficulty(mode);
        expect(svc.load().difficulty, mode);
      }
    });
  });

  group('ProgressNotifier session tracking', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('sessionCompletedCount starts at 0', () {
      final notifier = ProgressNotifier(ProgressService());
      expect(notifier.sessionCompletedCount, 0);
    });

    test('sessionCompletedCount increments on new drawing completion', () async {
      final notifier = ProgressNotifier(ProgressService());
      await notifier.markDrawingComplete('drawing1');
      expect(notifier.sessionCompletedCount, 1);
    });

    test('sessionCompletedCount increments again on second new drawing', () async {
      final notifier = ProgressNotifier(ProgressService());
      await notifier.markDrawingComplete('drawing1');
      await notifier.markDrawingComplete('drawing2');
      expect(notifier.sessionCompletedCount, 2);
    });

    test('sessionCompletedCount does NOT increment on re-completion', () async {
      final notifier = ProgressNotifier(ProgressService());
      await notifier.markDrawingComplete('drawing1');
      await notifier.markDrawingComplete('drawing1'); // re-completion
      expect(notifier.sessionCompletedCount, 1); // still 1
    });
  });
}
