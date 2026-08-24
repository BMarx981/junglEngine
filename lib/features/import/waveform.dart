import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/theme.dart';

/// A clip reduced to something drawable.
///
/// Computed once at a fixed resolution and stretched to whatever width it is
/// painted at. Recomputing per layout would mean walking a few million samples
/// every time a trim handle moves.
class WaveformPeaks {
  const WaveformPeaks._(this.highs, this.lows);

  final Float32List highs;
  final Float32List lows;

  int get columns => highs.length;

  /// Wide enough that a phone at three times device pixel ratio still gets
  /// about one column per pixel.
  static const int resolution = 1200;

  static WaveformPeaks of(AudioClip clip, {int columns = resolution}) {
    final frames = clip.frames;
    final count = min(columns, max(1, frames));
    final highs = Float32List(count);
    final lows = Float32List(count);
    if (frames == 0) return WaveformPeaks._(highs, lows);

    for (var column = 0; column < count; column++) {
      final start = (column * frames / count).floor();
      final end = min(frames, ((column + 1) * frames / count).ceil());
      var high = 0.0;
      var low = 0.0;
      for (var frame = start; frame < end; frame++) {
        for (var channel = 0; channel < clip.channels; channel++) {
          final value = clip.samples[frame * clip.channels + channel];
          if (value > high) high = value;
          if (value < low) low = value;
        }
      }
      highs[column] = high;
      lows[column] = low;
    }
    return WaveformPeaks._(highs, lows);
  }
}

/// Draws the whole file, with the trimmed region lit and everything outside it
/// dimmed back.
///
/// The point of the dimming is that the trim is the subject: what you are
/// choosing is a loop, and the rest of the file is context you are choosing it
/// out of.
class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.peaks,
    required this.startFraction,
    required this.endFraction,
    this.barLines = 0,
  });

  final WaveformPeaks peaks;
  final double startFraction;
  final double endFraction;

  /// How many bars the trimmed region is, so the loop can be marked out. Zero
  /// draws no divisions.
  final int barLines;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.columns == 0) return;
    final middle = size.height / 2;
    final scale = size.height / 2 * 0.94;

    final inside = Paint()..color = JungleTheme.accent;
    final outside = Paint()..color = JungleTheme.line;

    final left = startFraction * size.width;
    final right = endFraction * size.width;

    for (var x = 0.0; x < size.width; x += 1) {
      final column = (x / size.width * peaks.columns).floor().clamp(
        0,
        peaks.columns - 1,
      );
      final high = peaks.highs[column];
      final low = peaks.lows[column];
      final top = middle - high * scale;
      final bottom = middle - low * scale;
      canvas.drawRect(
        Rect.fromLTRB(
          x,
          min(top, middle - 0.5),
          x + 1,
          max(bottom, middle + 0.5),
        ),
        x >= left && x <= right ? inside : outside,
      );
    }

    if (barLines > 1 && right > left) {
      final divisions = Paint()
        ..color = JungleTheme.background.withValues(alpha: 0.55)
        ..strokeWidth = 1;
      for (var bar = 1; bar < barLines; bar++) {
        final x = left + (right - left) * bar / barLines;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), divisions);
      }
    }

    final edge = Paint()
      ..color = JungleTheme.text
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, 0), Offset(left, size.height), edge);
    canvas.drawLine(Offset(right, 0), Offset(right, size.height), edge);
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      !identical(old.peaks, peaks) ||
      old.startFraction != startFraction ||
      old.endFraction != endFraction ||
      old.barLines != barLines;
}
