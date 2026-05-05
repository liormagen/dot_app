import 'package:flutter/material.dart';

import '../../models/dot_model.dart';

// ---------------------------------------------------------------------------
// Line style enum
// ---------------------------------------------------------------------------
enum LineStyle { sparkle, wave, glow }

// ---------------------------------------------------------------------------
// Connection model
// ---------------------------------------------------------------------------
class Connection {
  const Connection({
    required this.from,
    required this.to,
    required this.style,
    required this.color,
  });

  final DotModel from;
  final DotModel to;
  final LineStyle style;
  final Color color;
}

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------
class DrawingSessionState {
  const DrawingSessionState({
    required this.nextExpectedDotId,
    required this.connections,
    required this.isComplete,
    this.hintingDotId,
  });

  final int nextExpectedDotId;
  final List<Connection> connections;
  final bool isComplete;
  final int? hintingDotId;

  DrawingSessionState copyWith({
    int? nextExpectedDotId,
    List<Connection>? connections,
    bool? isComplete,
    int? hintingDotId,
    bool clearHint = false,
  }) {
    return DrawingSessionState(
      nextExpectedDotId: nextExpectedDotId ?? this.nextExpectedDotId,
      connections: connections ?? this.connections,
      isComplete: isComplete ?? this.isComplete,
      hintingDotId: clearHint ? null : (hintingDotId ?? this.hintingDotId),
    );
  }

  static DrawingSessionState initial(int firstDotId) => DrawingSessionState(
        nextExpectedDotId: firstDotId,
        connections: const [],
        isComplete: false,
      );
}
