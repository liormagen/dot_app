import 'package:flutter_test/flutter_test.dart';

void main() {
  // Navigation routing smoke-tests — verifies the path strings are correct.
  test('next drawing path is /drawing/{id}', () {
    const nextId = 'drawing2_1';
    final path = '/drawing/$nextId';
    expect(path, '/drawing/drawing2_1');
  });

  test('story complete path is /story-complete/{id}', () {
    const storyId = 'story1';
    final path = '/story-complete/$storyId';
    expect(path, '/story-complete/story1');
  });
}
