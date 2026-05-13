import 'package:dot_story/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('drawNextChapter formats chapter number', () {
    expect(l10n.drawNextChapter(2), 'Draw Chapter 2!');
    expect(l10n.drawNextChapter(5), 'Draw Chapter 5!');
  });

  test('finishStory key exists', () {
    expect(l10n.finishStory, 'Finish Story!');
  });

  test('playAgain key exists', () {
    expect(l10n.playAgain, 'Play Again!');
  });

  test('nextChapter key exists', () {
    expect(l10n.nextChapter, 'Next Chapter!');
  });

  test('readMyStory key exists', () {
    expect(l10n.readMyStory, 'Read My Story!');
  });

  test('readAgain key exists', () {
    expect(l10n.readAgain, 'Read Again!');
  });
}
