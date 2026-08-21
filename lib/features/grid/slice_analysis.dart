import 'dart:math' as math;

import '../../audio/audio_clip.dart';

/// A cheap read of what each equal division of the break actually contains.
///
/// This is not transient detection and it does not decide where slices fall:
/// the divisions are still equal. It only asks "is this one loud, and is it
/// bright", which is enough for Scramble to put snare-ish material on the
/// backbeat instead of scattering hits at random.
class SliceAnalysis {
  SliceAnalysis({
    required this.sliceCount,
    required this.energy,
    required this.brightness,
  });

  final int sliceCount;

  /// Per slice RMS, normalised so the loudest slice is 1.
  final List<double> energy;

  /// Per slice zero crossing rate, normalised so the brightest slice is 1.
  /// A decent stand in for spectral centroid at a fraction of the cost.
  final List<double> brightness;

  factory SliceAnalysis.of(AudioClip clip, int sliceCount) {
    final total = clip.frames;
    final channels = clip.channels;
    final energy = List<double>.filled(sliceCount, 0);
    final brightness = List<double>.filled(sliceCount, 0);

    for (var i = 0; i < sliceCount; i++) {
      final start = (i * total / sliceCount).round();
      final end = ((i + 1) * total / sliceCount).round().clamp(0, total);
      final n = end - start;
      if (n <= 0) continue;

      var sumSquares = 0.0;
      var crossings = 0;
      var previous = 0.0;
      for (var f = start; f < end; f++) {
        final v = clip.samples[f * channels];
        sumSquares += v * v;
        if ((v < 0) != (previous < 0)) crossings++;
        previous = v;
      }
      energy[i] = math.sqrt(sumSquares / n);
      brightness[i] = crossings / n;
    }

    return SliceAnalysis(
      sliceCount: sliceCount,
      energy: _normalized(energy),
      brightness: _normalized(brightness),
    );
  }

  /// An analysis with nothing to say. Scramble falls back to treating every
  /// slice as equally likely.
  factory SliceAnalysis.flat(int sliceCount) => SliceAnalysis(
    sliceCount: sliceCount,
    energy: List<double>.filled(sliceCount, 0.5),
    brightness: List<double>.filled(sliceCount, 0.5),
  );

  static List<double> _normalized(List<double> values) {
    var peak = 0.0;
    for (final v in values) {
      if (v > peak) peak = v;
    }
    if (peak <= 0) return values;
    return [for (final v in values) v / peak];
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.of(values)..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Loud and dark: the low end of the break.
  late final List<int> kicks = _pool(
    (e, b) => e >= _energyMid && b < _brightMid,
  );

  /// Loud and bright: snares, and the crash of a full hit.
  late final List<int> snares = _pool(
    (e, b) => e >= _energyMid && b >= _brightMid,
  );

  /// Everything quieter. Hats, tails, room, the bits that make a break breathe.
  late final List<int> ghosts = _pool((e, b) => e < _energyMid);

  late final double _energyMid = _median(energy);
  late final double _brightMid = _median(brightness);

  List<int> _pool(bool Function(double energy, double brightness) test) {
    final result = <int>[
      for (var i = 0; i < sliceCount; i++)
        if (test(energy[i], brightness[i])) i,
    ];
    // Never hand back an empty pool; a degenerate break should still scramble.
    return result.isEmpty ? [for (var i = 0; i < sliceCount; i++) i] : result;
  }
}
