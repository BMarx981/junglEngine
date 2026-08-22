import 'dart:math';

import '../../models/chop_pattern.dart';
import '../../models/steps.dart';
import 'slice_analysis.dart';

/// Generates a rearrangement that still sounds like a breakbeat.
///
/// The rules, in the order they matter:
///
/// - The downbeats stay put. If a step on the quarter note already holds a
///   slice, it usually survives the shuffle, so repeated taps evolve a groove
///   instead of throwing it away.
/// - Beats 2 and 4 want snare-ish material, beat 1 wants kick-ish material.
/// - Everything in between is ghost territory, drawn from the quieter slices
///   and left empty often enough to leave holes for the sub to sit in.
///
/// Fully determined by [seed], so the same tap always produces the same bar and
/// undo is just holding on to the previous pattern.
ChopPattern scramblePattern({
  required ChopPattern current,
  required SliceAnalysis analysis,
  required int seed,
  double density = 0.42,
}) {
  final random = Random(seed);
  final steps = List<ChopStep?>.filled(current.length, null);

  final kicks = analysis.kicks;
  final snares = analysis.snares;
  final ghosts = analysis.ghosts;

  ChopStep pick(List<int> pool) => ChopStep(pool[random.nextInt(pool.length)]);

  for (var step = 0; step < steps.length; step++) {
    final inBar = step % stepsPerBar;
    final onQuarter = inBar % stepsPerBeat == 0;
    final existing = current.stepAt(step);

    if (onQuarter) {
      // Anchored: keep what is there most of the time, modifier and all. A
      // reverse you put on the downbeat is part of the groove you are
      // evolving, not something to shuffle away.
      if (existing != null && existing.slice < analysis.sliceCount) {
        if (random.nextDouble() < 0.72) {
          steps[step] = existing;
          continue;
        }
      }
      final beat = inBar ~/ stepsPerBeat;
      // Beat 1 is the kick, beats 2 and 4 are the backbeat, beat 3 can go
      // either way. That is the skeleton every break shares.
      steps[step] = switch (beat) {
        0 => pick(kicks),
        2 => random.nextDouble() < 0.55 ? pick(kicks) : pick(snares),
        _ => pick(snares),
      };
      continue;
    }

    // Off the quarter note. The sixteenth just before a downbeat is where the
    // classic jungle snare drag lives, so it gets a better chance.
    final isPickup = inBar % stepsPerBeat == 3;
    final chance = isPickup ? density + 0.18 : density;
    if (random.nextDouble() >= chance) continue;

    steps[step] = random.nextDouble() < 0.78 ? pick(ghosts) : pick(snares);
  }

  return ChopPattern(List<ChopStep?>.unmodifiable(steps));
}
