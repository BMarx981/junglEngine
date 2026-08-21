import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../audio/engine.dart';
import '../../theme.dart';

/// The playhead, on its own paint layer so it can move at frame rate without
/// dragging the grid underneath it into a repaint.
///
/// It reads the transport straight from the audio layer, which is the only
/// thing that knows where playback actually is.
class PlayheadPainter extends CustomPainter {
  PlayheadPainter({
    required this.transport,
    required this.stepCount,
    this.color = JungleTheme.accent,
  }) : super(repaint: transport);

  final ValueListenable<TransportState> transport;
  final int stepCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final state = transport.value;
    if (!state.playing) return;
    final cellWidth = size.width / stepCount;

    canvas.drawRect(
      Rect.fromLTWH(state.step * cellWidth, 0, cellWidth, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.11),
    );

    final x = state.loopPosition * size.width;
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
      old.stepCount != stepCount ||
      old.color != color;
}
