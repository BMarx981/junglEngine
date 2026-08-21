import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/features/grid/slice_analysis.dart';

/// Four slices: a loud low tone, a loud high tone, a quiet low tone, silence.
AudioClip fixture() {
  const frames = 4000;
  final samples = Float32List(frames * 2);
  for (var f = 0; f < frames; f++) {
    final slice = f ~/ 1000;
    final hz = slice == 1 ? 6000.0 : 60.0;
    final amp = switch (slice) {
      0 => 1.0,
      1 => 1.0,
      2 => 0.05,
      _ => 0.0,
    };
    final v = math.sin(2 * math.pi * hz * (f % 1000) / 44100) * amp;
    samples[f * 2] = v;
    samples[f * 2 + 1] = v;
  }
  return AudioClip(samples: samples, channels: 2, sampleRate: 44100);
}

void main() {
  test('separates loud dark, loud bright and quiet slices', () {
    final analysis = SliceAnalysis.of(fixture(), 4);

    expect(analysis.kicks, contains(0));
    expect(analysis.snares, contains(1));
    expect(analysis.ghosts, containsAll([2, 3]));
    expect(analysis.brightness[1], greaterThan(analysis.brightness[0]));
  });

  test('a silent break still yields usable pools', () {
    final analysis = SliceAnalysis.of(
      AudioClip.silent(frames: 4000),
      8,
    );
    expect(analysis.kicks, isNotEmpty);
    expect(analysis.snares, isNotEmpty);
    expect(analysis.ghosts, isNotEmpty);
  });
}
