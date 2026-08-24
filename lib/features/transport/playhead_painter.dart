import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:junglengine/audio/engine.dart';
import 'package:junglengine/theme.dart';

/// The playhead, on its own paint layer so it can move at frame rate without
/// dragging the grid underneath it into a repaint.
///
/// It reads the transport straight from the audio layer, which is the only
/// thing that knows where playback actually is.
///
/// The grid shows one bar at a time while the pattern can be eight bars long,
/// so this paints a window: [stepOffset] is the first step on screen and
/// [visibleSteps] is how many fit. When the playhead is in a bar you are not
/// looking at, nothing is drawn.
class PlayheadPainter extends CustomPainter {
  PlayheadPainter({
    required this.transport,
    required this.visibleSteps,
    required this.totalSteps,
    this.stepOffset = 0,
    this.color = JungleTheme.accent,
  }) : super(repaint: transport);

  final ValueListenable<TransportState> transport;

  /// Steps across the width of this painter.
  final int visibleSteps;

  /// Steps in the whole pattern.
  final int totalSteps;

  /// Which step of the pattern the left edge is.
  final int stepOffset;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final state = transport.value;
    if (!state.playing || visibleSteps <= 0 || totalSteps <= 0) return;
    final cellWidth = size.width / visibleSteps;

    final step = state.step - stepOffset;
    if (step >= 0 && step < visibleSteps) {
      canvas.drawRect(
        Rect.fromLTWH(step * cellWidth, 0, cellWidth, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.11),
      );
    }

    final position = state.loopPosition * totalSteps - stepOffset;
    if (position < 0 || position > visibleSteps) return;
    final x = position * cellWidth;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(PlayheadPainter old) =>
      old.transport != transport ||
      old.visibleSteps != visibleSteps ||
      old.totalSteps != totalSteps ||
      old.stepOffset != stepOffset ||
      old.color != color;
}
