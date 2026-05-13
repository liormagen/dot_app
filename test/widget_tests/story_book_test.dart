import 'package:dot_story/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('readAgain key is Read Again!', () {
    expect(l10n.readAgain, 'Read Again!');
  });

  test('storyComplete key is Story Complete!', () {
    expect(l10n.storyComplete, 'Story Complete!');
  });

  test('backToStories key is Back to Stories', () {
    expect(l10n.backToStories, 'Back to Stories');
  });
}
