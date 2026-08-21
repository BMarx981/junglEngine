import 'steps.dart';

/// The lowest and highest note the sub lane can hold, in semitones relative to
/// the lane's root. Deliberately narrow: this is a sub, not a lead.
const int subMinSemitone = -12;
const int subMaxSemitone = 12;

/// One cell of the sub lane.
///
/// - `semitone == null && !tie` is silence.
/// - `semitone != null && !tie` retriggers the amp envelope at that pitch.
/// - `semitone != null && tie` glides to that pitch without retriggering.
/// - `semitone == null && tie` holds the previous pitch.
class SubStep {
  const SubStep({this.semitone, this.tie = false});

  const SubStep.rest() : semitone = null, tie = false;

  final int? semitone;
  final bool tie;

  bool get isRest => semitone == null && !tie;

  SubStep copyWith({int? semitone, bool clearSemitone = false, bool? tie}) {
    return SubStep(
      semitone: clearSemitone ? null : (semitone ?? this.semitone),
      tie: tie ?? this.tie,
    );
  }

  Map<String, Object?> toJson() => {
    if (semitone != null) 'n': semitone,
    if (tie) 't': true,
  };

  static SubStep fromJson(Object? json) {
    if (json is! Map) return const SubStep.rest();
    final n = json['n'];
    return SubStep(semitone: n is int ? n : null, tie: json['t'] == true);
  }
}

/// A monophonic pitch lane running alongside the drum grid.
class SubLane {
  SubLane(this.steps);

  final List<SubStep> steps;

  int get bars => steps.length ~/ stepsPerBar;

  SubLane.empty({int bars = 1})
    : steps = List<SubStep>.filled(
        bars * stepsPerBar,
        const SubStep.rest(),
        growable: false,
      );

  bool get isEmpty => steps.every((s) => s.isRest);

  SubStep stepAt(int step) =>
      (step >= 0 && step < steps.length) ? steps[step] : const SubStep.rest();

  SubLane withStep(int step, SubStep value) {
    final next = List<SubStep>.of(steps);
    next[step] = value;
    return SubLane(List<SubStep>.unmodifiable(next));
  }

  /// Toggling a tie only means anything from step 1 onward: step 0 has nothing
  /// to glide from.
  SubLane toggledTie(int step) {
    if (step <= 0) return this;
    return withStep(step, steps[step].copyWith(tie: !steps[step].tie));
  }

  SubLane cleared() => SubLane.empty(bars: bars);

  List<Object?> toJson() => [for (final s in steps) s.toJson()];

  static SubLane fromJson(Object? json) {
    if (json is! List) return SubLane.empty();
    return SubLane(
      List<SubStep>.unmodifiable([for (final v in json) SubStep.fromJson(v)]),
    );
  }
}
