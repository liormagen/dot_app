import 'package:flutter_test/flutter_test.dart';

void main() {
  test('elapsedMs query param can be parsed as int', () {
    final uri = Uri.parse('/completion/drawing123?elapsedMs=12345');
    final elapsedMs = int.tryParse(uri.queryParameters['elapsedMs'] ?? '');
    expect(elapsedMs, 12345);
  });

  test('missing elapsedMs parses as null', () {
    final uri = Uri.parse('/completion/drawing123');
    final elapsedMs = int.tryParse(uri.queryParameters['elapsedMs'] ?? '');
    expect(elapsedMs, isNull);
  });
}
