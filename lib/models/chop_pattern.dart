import 'steps.dart';

/// A monophonic step grid over the slices of the project break.
///
/// One slice per step: painting a step replaces whatever was there. Rows in the
/// UI are slices, columns are steps.
class ChopPattern {
  ChopPattern(this.steps);

  /// One entry per step. `null` means the step is empty.
  final List<int?> steps;

  int get length => steps.length;

  int get bars => steps.length ~/ stepsPerBar;

  ChopPattern.empty({int bars = 1})
    : steps = List<int?>.filled(bars * stepsPerBar, null, growable: false);

  /// The diagonal: step *n* plays slice *n*. Playing this back at the break's
  /// own tempo reconstructs the original loop, which is the reference point
  /// every rearrangement is heard against.
  factory ChopPattern.identity({int bars = 1, required int sliceCount}) {
    final total = bars * stepsPerBar;
    return ChopPattern(
      List<int?>.generate(total, (i) => i % sliceCount, growable: false),
    );
  }

  int? sliceAt(int step) =>
      (step >= 0 && step < steps.length) ? steps[step] : null;

  bool get isEmpty => steps.every((s) => s == null);

  /// Sets [step] to [slice], or clears it when [slice] is null.
  ChopPattern withStep(int step, int? slice) {
    final next = List<int?>.of(steps);
    next[step] = slice;
    return ChopPattern(List<int?>.unmodifiable(next));
  }

  /// Clears [step] when it already holds [slice], otherwise sets it. This is
  /// the tap behaviour: tap to place, tap the same cell again to clear.
  ChopPattern toggled(int step, int slice) =>
      withStep(step, steps[step] == slice ? null : slice);

  ChopPattern cleared() => ChopPattern.empty(bars: bars);

  /// Drops any slice index that no longer exists after a re-slice.
  ChopPattern clampedTo(int sliceCount) => ChopPattern(
    List<int?>.unmodifiable([
      for (final s in steps) (s == null || s >= sliceCount) ? null : s,
    ]),
  );

  List<Object?> toJson() => steps;

  /// Always comes back at exactly [bars] bars, whatever the file said. The
  /// Beat's length is the truth; a pattern that disagreed with it would paint
  /// steps the sequencer never reaches.
  static ChopPattern fromJson(Object? json, {int bars = 1}) {
    final total = bars * stepsPerBar;
    if (json is! List) return ChopPattern.empty(bars: bars);
    return ChopPattern(
      List<int?>.unmodifiable([
        for (var i = 0; i < total; i++)
          if (i < json.length && json[i] is int) json[i]! as int else null,
      ]),
    );
  }
}
