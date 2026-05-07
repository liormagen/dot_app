import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/l10n/app_localizations.dart';
import 'package:dot_story/models/story_model.dart';
import 'package:dot_story/widgets/story_card.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _kStory = StoryModel(
  id: 'story1',
  titles: const {'en': 'The Big Fish'},
  companionAsset: 'assets/companion.png',
  previewAsset: 'assets/preview.png',
  drawingIds: const ['d1', 'd2', 'd3'],
  chapters: const [],
);

// 320×420 matches a realistic iPad story-card size; 240 overflows the progress row.
Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SizedBox(width: 320, height: 420, child: child),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StoryCard', () {
    testWidgets('renders story title', (tester) async {
      await tester.pumpWidget(_wrap(StoryCard(
        story: _kStory,
        completedCount: 0,
        onTap: () {},
        language: 'en',
      )));
      expect(find.text('The Big Fish'), findsOneWidget);
    });

    testWidgets('shows correct progress fraction', (tester) async {
      await tester.pumpWidget(_wrap(StoryCard(
        story: _kStory,
        completedCount: 2,
        onTap: () {},
        language: 'en',
      )));
      expect(find.text('2/3'), findsOneWidget);
    });

    testWidgets('shows 0/3 when nothing completed', (tester) async {
      await tester.pumpWidget(_wrap(StoryCard(
        story: _kStory,
        completedCount: 0,
        onTap: () {},
        language: 'en',
      )));
      expect(find.text('0/3'), findsOneWidget);
    });

    testWidgets('does not show done badge when incomplete', (tester) async {
      await tester.pumpWidget(_wrap(StoryCard(
        story: _kStory,
        completedCount: 1,
        onTap: () {},
        language: 'en',
      )));
      await tester.pump();
      expect(find.text('Done!'), findsNothing);
    });

    testWidgets('shows done badge when all drawings completed', (tester) async {
      await tester.pumpWidget(_wrap(StoryCard(
        story: _kStory,
        completedCount: 3,
        onTap: () {},
        language: 'en',
      )));
      await tester.pump();
      expect(find.text('Done!'), findsOneWidget);
    });

    testWidgets('calls onTap exactly once per tap', (tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(StoryCard(
        story: _kStory,
        completedCount: 0,
        onTap: () => taps++,
        language: 'en',
      )));
      await tester.tap(find.byType(StoryCard));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('calls onTap again on second tap', (tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(StoryCard(
        story: _kStory,
        completedCount: 0,
        onTap: () => taps++,
        language: 'en',
      )));
      await tester.tap(find.byType(StoryCard));
      await tester.pump();
      await tester.tap(find.byType(StoryCard));
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('progress row shows overflow label for totals above 8',
        (tester) async {
      final bigStory = StoryModel(
        id: 'big',
        titles: const {'en': 'Big Story'},
        companionAsset: 'assets/companion.png',
        previewAsset: 'assets/preview.png',
        drawingIds: List.generate(10, (i) => 'd$i'),
        chapters: const [],
      );
      await tester.pumpWidget(_wrap(StoryCard(
        story: bigStory,
        completedCount: 0,
        onTap: () {},
        language: 'en',
      )));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('falls back to story id when language key missing',
        (tester) async {
      await tester.pumpWidget(_wrap(StoryCard(
        story: _kStory,
        completedCount: 0,
        onTap: () {},
        language: 'fr', // no French translation → falls back to 'en'
      )));
      expect(find.text('The Big Fish'), findsOneWidget);
    });
  });
}
