import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/models/story_model.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _kStory = StoryModel(
  id: 'story_abc',
  titles: const {'en': 'The Big Fish', 'he': 'הדג הגדול', 'ar': 'السمكة الكبيرة'},
  companionAsset: 'assets/companion.png',
  previewAsset: 'assets/preview.png',
  drawingIds: const ['d1', 'd2'],
  chapters: const [],
);

final _kChapter = StoryChapter(
  chapter: 1,
  narrations: const {
    'en': 'Once upon a time...',
    'he': 'היה היה פעם...',
  },
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StoryModel.getTitle', () {
    test('returns the title for the requested language', () {
      expect(_kStory.getTitle('en'), 'The Big Fish');
      expect(_kStory.getTitle('he'), 'הדג הגדול');
      expect(_kStory.getTitle('ar'), 'السمكة الكبيرة');
    });

    test('falls back to English when requested language is missing', () {
      expect(_kStory.getTitle('fr'), 'The Big Fish');
      expect(_kStory.getTitle('es'), 'The Big Fish');
    });

    test('falls back to story id when no language keys exist', () {
      const noTitles = StoryModel(
        id: 'fallback_id',
        titles: {},
        companionAsset: '',
        previewAsset: '',
        drawingIds: [],
        chapters: [],
      );
      expect(noTitles.getTitle('en'), 'fallback_id');
      expect(noTitles.getTitle('he'), 'fallback_id');
    });

    test('falls back to story id when only non-en keys exist and lang missing', () {
      const heOnly = StoryModel(
        id: 'he_only',
        titles: {'he': 'כותרת'},
        companionAsset: '',
        previewAsset: '',
        drawingIds: [],
        chapters: [],
      );
      expect(heOnly.getTitle('fr'), 'he_only');
    });
  });

  group('StoryModel.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'story1',
        'titles': {'en': 'My Story', 'he': 'הסיפור שלי'},
        'companion_asset': 'assets/comp.png',
        'preview_asset': 'assets/prev.png',
        'drawing_ids': ['d1', 'd2', 'd3'],
        'chapters': [],
      };
      final story = StoryModel.fromJson(json);
      expect(story.id, 'story1');
      expect(story.getTitle('en'), 'My Story');
      expect(story.getTitle('he'), 'הסיפור שלי');
      expect(story.drawingIds, ['d1', 'd2', 'd3']);
      expect(story.chapters, isEmpty);
    });

    test('handles missing titles and drawing_ids gracefully', () {
      final json = {
        'id': 'minimal',
        'companion_asset': '',
        'preview_asset': '',
      };
      final story = StoryModel.fromJson(json);
      expect(story.getTitle('en'), 'minimal');
      expect(story.drawingIds, isEmpty);
    });
  });

  group('StoryChapter.getNarration', () {
    test('returns narration for the requested language', () {
      expect(_kChapter.getNarration('en'), 'Once upon a time...');
      expect(_kChapter.getNarration('he'), 'היה היה פעם...');
    });

    test('falls back to English when language is missing', () {
      expect(_kChapter.getNarration('fr'), 'Once upon a time...');
    });

    test('returns empty string when no narrations exist', () {
      const empty = StoryChapter(chapter: 1, narrations: {});
      expect(empty.getNarration('en'), '');
      expect(empty.getNarration('he'), '');
    });

    test('returns empty string when only non-en keys exist and lang missing', () {
      const heOnly = StoryChapter(
        chapter: 1,
        narrations: {'he': 'טקסט'},
      );
      expect(heOnly.getNarration('fr'), '');
    });
  });

  group('StoryChapter.fromJson', () {
    test('parses chapter number and narrations', () {
      final json = {
        'chapter': 2,
        'narrations': {'en': 'Hello', 'ar': 'مرحبا'},
      };
      final chapter = StoryChapter.fromJson(json);
      expect(chapter.chapter, 2);
      expect(chapter.getNarration('en'), 'Hello');
      expect(chapter.getNarration('ar'), 'مرحبا');
    });
  });
}
