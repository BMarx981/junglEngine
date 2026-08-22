import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/features/grid/scramble.dart';
import 'package:junglengine/features/grid/slice_analysis.dart';
import 'package:junglengine/models/chop_pattern.dart';

const int sliceCount = 16;

SliceAnalysis analysisWith({
  List<int> kicks = const [0, 1],
  List<int> snares = const [4, 5],
}) {
  // Loud and dark reads as kick, loud and bright reads as snare, the rest is
  // ghost material.
  final energy = List<double>.filled(sliceCount, 0.2);
  final brightness = List<double>.filled(sliceCount, 0.2);
  for (final k in kicks) {
    energy[k] = 1.0;
    brightness[k] = 0.1;
  }
  for (final s in snares) {
    energy[s] = 1.0;
    brightness[s] = 1.0;
  }
  return SliceAnalysis(
    sliceCount: sliceCount,
    energy: energy,
    brightness: brightness,
  );
}

void main() {
  final analysis = analysisWith();

  test('the same seed always produces the same bar', () {
    final a = scramblePattern(
      current: ChopPattern.identity(sliceCount: sliceCount),
      analysis: analysis,
      seed: 12345,
    );
    final b = scramblePattern(
      current: ChopPattern.identity(sliceCount: sliceCount),
      analysis: analysis,
      seed: 12345,
    );
    expect(a.steps, equals(b.steps));
  });

  test('different seeds produce different bars', () {
    final results = {
      for (var seed = 0; seed < 20; seed++)
        scramblePattern(
          current: ChopPattern.empty(),
          analysis: analysis,
          seed: seed,
        ).steps.toString(),
    };
    expect(results.length, greaterThan(15));
  });

  test('every quarter note lands on something', () {
    for (var seed = 0; seed < 50; seed++) {
      final pattern = scramblePattern(
        current: ChopPattern.empty(),
        analysis: analysis,
        seed: seed,
      );
      for (final step in [0, 4, 8, 12]) {
        expect(pattern.sliceAt(step), isNotNull, reason: 'seed $seed');
      }
    }
  });

  test('beat one takes a kick and the backbeat takes a snare', () {
    for (var seed = 0; seed < 50; seed++) {
      final pattern = scramblePattern(
        current: ChopPattern.empty(),
        analysis: analysis,
        seed: seed,
      );
      expect(analysis.kicks, contains(pattern.sliceAt(0)));
      expect(analysis.snares, contains(pattern.sliceAt(4)));
      expect(analysis.snares, contains(pattern.sliceAt(12)));
    }
  });

  test('downbeats you already placed mostly survive', () {
    final current = ChopPattern.empty().withStep(0, 9).withStep(8, 11);
    var kept = 0;
    const runs = 200;
    for (var seed = 0; seed < runs; seed++) {
      final pattern = scramblePattern(
        current: current,
        analysis: analysis,
        seed: seed,
      );
      if (pattern.sliceAt(0) == 9 && pattern.sliceAt(8) == 11) kept++;
    }
    // Anchored, not frozen: it should usually keep them and sometimes not.
    expect(kept / runs, greaterThan(0.4));
    expect(kept / runs, lessThan(0.95));
  });

  test('never places a slice that does not exist', () {
    for (var seed = 0; seed < 100; seed++) {
      final pattern = scramblePattern(
        current: ChopPattern.identity(sliceCount: sliceCount),
        analysis: analysis,
        seed: seed,
      );
      for (final cell in pattern.steps) {
        if (cell == null) continue;
        expect(cell.slice, inInclusiveRange(0, sliceCount - 1));
      }
    }
  });

  test('leaves holes for the sub to sit in', () {
    var totalEmpty = 0;
    const runs = 100;
    for (var seed = 0; seed < runs; seed++) {
      final pattern = scramblePattern(
        current: ChopPattern.empty(),
        analysis: analysis,
        seed: seed,
      );
      totalEmpty += pattern.steps.where((s) => s == null).length;
    }
    final averageEmpty = totalEmpty / runs;
    expect(averageEmpty, greaterThan(2));
    expect(averageEmpty, lessThan(9));
  });

  test('a flat analysis still scrambles rather than throwing', () {
    final pattern = scramblePattern(
      current: ChopPattern.empty(),
      analysis: SliceAnalysis.flat(8),
      seed: 7,
    );
    expect(pattern.steps.where((s) => s != null), isNotEmpty);
  });
}
