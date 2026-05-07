import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/screens/drawing/drawing_types.dart';
import 'package:dot_story/models/dot_model.dart';
import 'package:dot_story/screens/drawing/drawing_screen.dart';

// Helpers
DotModel _dot(int id) => DotModel(id: id, x: id * 10.0, y: id * 10.0);
Connection _conn(int fromId, int toId) => Connection(
      from: _dot(fromId),
      to: _dot(toId),
      style: LineStyle.sparkle,
      color: Colors.red,
    );

void main() {
  group('DrawingSessionNotifier', () {
    late DrawingSessionNotifier notifier;

    setUp(() {
      notifier = DrawingSessionNotifier();
    });

    test('initial state starts at dot 1 with no connections', () {
      expect(notifier.state.nextExpectedDotId, 1);
      expect(notifier.state.connections, isEmpty);
      expect(notifier.state.isComplete, isFalse);
    });

    test('init resets to a new first dot id', () {
      notifier.init(5);
      expect(notifier.state.nextExpectedDotId, 5);
      expect(notifier.state.connections, isEmpty);
      expect(notifier.state.isComplete, isFalse);
    });

    test('addConnection appends the connection', () {
      notifier.addConnection(_conn(1, 2), 2, false);
      expect(notifier.state.connections.length, 1);
      expect(notifier.state.connections.first.from.id, 1);
      expect(notifier.state.connections.first.to.id, 2);
    });

    test('addConnection updates nextExpectedDotId', () {
      notifier.addConnection(_conn(1, 2), 3, false);
      expect(notifier.state.nextExpectedDotId, 3);
    });

    test('addConnection with complete=true marks session complete', () {
      notifier.addConnection(_conn(1, 2), 2, true);
      expect(notifier.state.isComplete, isTrue);
    });

    test('addConnection clears hinting dot', () {
      notifier.setHintingDot(3);
      expect(notifier.state.hintingDotId, 3);
      notifier.addConnection(_conn(1, 2), 2, false);
      expect(notifier.state.hintingDotId, isNull);
    });

    test('setHintingDot sets hinting dot id', () {
      notifier.setHintingDot(7);
      expect(notifier.state.hintingDotId, 7);
    });

    test('setHintingDot with null clears hinting dot', () {
      notifier.setHintingDot(7);
      notifier.setHintingDot(null);
      expect(notifier.state.hintingDotId, isNull);
    });

    test('connectAll sets all connections and marks complete', () {
      final conns = [_conn(1, 2), _conn(2, 3), _conn(3, 1)];
      notifier.connectAll(conns, 3);
      expect(notifier.state.connections.length, 3);
      expect(notifier.state.isComplete, isTrue);
      expect(notifier.state.nextExpectedDotId, 3);
    });

    test('connectAll replaces any existing connections', () {
      notifier.addConnection(_conn(1, 2), 2, false);
      final allConns = [_conn(1, 2), _conn(2, 3)];
      notifier.connectAll(allConns, 2);
      expect(notifier.state.connections.length, 2);
    });

    test('connectAll clears hinting dot', () {
      notifier.setHintingDot(4);
      notifier.connectAll([_conn(1, 2)], 1);
      expect(notifier.state.hintingDotId, isNull);
    });
  });

  group('DrawingSessionState.copyWith', () {
    test('preserves all fields when nothing specified', () {
      const state = DrawingSessionState(
        nextExpectedDotId: 5,
        connections: [],
        isComplete: false,
        hintingDotId: 2,
      );
      final copy = state.copyWith();
      expect(copy.nextExpectedDotId, 5);
      expect(copy.isComplete, isFalse);
      expect(copy.hintingDotId, 2);
    });

    test('clearHint overrides hintingDotId', () {
      const state = DrawingSessionState(
        nextExpectedDotId: 1,
        connections: [],
        isComplete: false,
        hintingDotId: 3,
      );
      final copy = state.copyWith(clearHint: true);
      expect(copy.hintingDotId, isNull);
    });
  });
}
