import 'package:junglengine/models/step_mod.dart';
import 'package:junglengine/models/steps.dart';

/// One filled step of the Chop grid: which slice, and what is done to it.
class ChopStep {
  const ChopStep(this.slice, {this.mod = StepMod.none});

  final int slice;

  /// Reverse, retrigger, pitch down or half speed. See [StepMod].
  final StepMod mod;

  ChopStep withMod(StepMod value) => ChopStep(slice, mod: value);

  /// A plain step is written as a bare integer, which is also what M0 and M1
  /// files contain. Only a modified step costs a map.
  Object toJson() => mod.isNone ? slice : {'s': slice, 'm': mod.code};

  static ChopStep? fromJson(Object? json) {
    if (json is int) return ChopStep(json);
    if (json is Map) {
      final slice = json['s'];
      if (slice is! int) return null;
      return ChopStep(slice, mod: StepMod.fromJson(json['m']));
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ChopStep && other.slice == slice && other.mod == mod;

  @override
  int get hashCode => Object.hash(slice, mod);

  @override
  String toString() => mod.isNone ? '$slice' : '$slice.${mod.code}';
}

/// A monophonic step grid over the slices of the project break.
///
/// One slice per step: painting a step replaces whatever was there. Rows in the
/// UI are slices, columns are steps.
class ChopPattern {
  ChopPattern(this.steps);

  /// One entry per step. `null` means the step is empty.
  final List<ChopStep?> steps;

  int get length => steps.length;

  int get bars => steps.length ~/ stepsPerBar;

  ChopPattern.empty({int bars = 1})
    : steps = List<ChopStep?>.filled(bars * stepsPerBar, null, growable: false);

  /// A pattern of plain, unmodified steps.
  factory ChopPattern.ofSlices(List<int?> slices) => ChopPattern(
    List<ChopStep?>.unmodifiable([
      for (final s in slices) s == null ? null : ChopStep(s),
    ]),
  );

  /// The diagonal: step *n* plays slice *n*. Playing this back at the break's
  /// own tempo reconstructs the original loop, which is the reference point
  /// every rearrangement is heard against.
  factory ChopPattern.identity({int bars = 1, required int sliceCount}) {
    final total = bars * stepsPerBar;
    return ChopPattern(
      List<ChopStep?>.generate(
        total,
        (i) => ChopStep(i % sliceCount),
        growable: false,
      ),
    );
  }

  ChopStep? stepAt(int step) =>
      (step >= 0 && step < steps.length) ? steps[step] : null;

  int? sliceAt(int step) => stepAt(step)?.slice;

  StepMod modAt(int step) => stepAt(step)?.mod ?? StepMod.none;

  bool get isEmpty => steps.every((s) => s == null);

  ChopPattern withCell(int step, ChopStep? cell) {
    if (step < 0 || step >= steps.length) return this;
    final next = List<ChopStep?>.of(steps);
    next[step] = cell;
    return ChopPattern(List<ChopStep?>.unmodifiable(next));
  }

  /// Sets [step] to [slice], or clears it when [slice] is null.
  ///
  /// Placing a slice writes a plain step: a modifier belongs to what was put
  /// there, so painting over it starts clean rather than inheriting a reverse
  /// you set on a different slice.
  ChopPattern withStep(int step, int? slice) =>
      withCell(step, slice == null ? null : ChopStep(slice));

  /// Puts a modifier on whatever is already on [step]. An empty step has
  /// nothing to modify.
  ChopPattern withMod(int step, StepMod mod) {
    final cell = stepAt(step);
    if (cell == null || cell.mod == mod) return this;
    return withCell(step, cell.withMod(mod));
  }

  /// Clears [step] when it already holds [slice], otherwise sets it. This is
  /// the tap behaviour: tap to place, tap the same cell again to clear.
  ChopPattern toggled(int step, int slice) =>
      withStep(step, sliceAt(step) == slice ? null : slice);

  ChopPattern cleared() => ChopPattern.empty(bars: bars);

  /// Drops any slice index that no longer exists after a re-slice.
  ChopPattern clampedTo(int sliceCount) => ChopPattern(
    List<ChopStep?>.unmodifiable([
      for (final s in steps) (s == null || s.slice >= sliceCount) ? null : s,
    ]),
  );

  List<Object?> toJson() => [for (final s in steps) s?.toJson()];

  /// Always comes back at exactly [bars] bars, whatever the file said. The
  /// Beat's length is the truth; a pattern that disagreed with it would paint
  /// steps the sequencer never reaches.
  ///
  /// Reads both shapes: a bare integer, which is what M0 and M1 wrote, and the
  /// map a modified step needs.
  static ChopPattern fromJson(Object? json, {int bars = 1}) {
    final total = bars * stepsPerBar;
    if (json is! List) return ChopPattern.empty(bars: bars);
    return ChopPattern(
      List<ChopStep?>.unmodifiable([
        for (var i = 0; i < total; i++)
          i < json.length ? ChopStep.fromJson(json[i]) : null,
      ]),
    );
  }
}
