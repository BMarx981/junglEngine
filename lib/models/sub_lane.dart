import 'package:junglengine/models/steps.dart';

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
  const SubStep({this.semitone, this.tie = false, this.accent = false});

  const SubStep.rest() : semitone = null, tie = false, accent = false;

  final int? semitone;
  final bool tie;

  /// Opens the filter on this note only. The sub synth has one lowpass and no
  /// modulation, so this is the whole of its dynamics: an accented note speaks
  /// where the ones around it sit under the drums.
  final bool accent;

  bool get isRest => semitone == null && !tie;

  SubStep copyWith({
    int? semitone,
    bool clearSemitone = false,
    bool? tie,
    bool? accent,
  }) {
    return SubStep(
      semitone: clearSemitone ? null : (semitone ?? this.semitone),
      tie: tie ?? this.tie,
      accent: accent ?? this.accent,
    );
  }

  Map<String, Object?> toJson() => {
    if (semitone != null) 'n': semitone,
    if (tie) 't': true,
    if (accent) 'a': true,
  };

  static SubStep fromJson(Object? json) {
    if (json is! Map) return const SubStep.rest();
    final n = json['n'];
    return SubStep(
      semitone: n is int ? n : null,
      tie: json['t'] == true,
      accent: json['a'] == true,
    );
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

  /// Accents the cell, if there is a note on it to accent.
  SubLane toggledAccent(int step) {
    if (step < 0 || step >= steps.length) return this;
    final cell = steps[step];
    if (cell.isRest) return this;
    return withStep(step, cell.copyWith(accent: !cell.accent));
  }

  SubLane cleared() => SubLane.empty(bars: bars);

  List<Object?> toJson() => [for (final s in steps) s.toJson()];

  /// Always comes back at exactly [bars] bars, so the lane and the Beat's
  /// timeline can never disagree.
  static SubLane fromJson(Object? json, {int bars = 1}) {
    final total = bars * stepsPerBar;
    if (json is! List) return SubLane.empty(bars: bars);
    return SubLane(
      List<SubStep>.unmodifiable([
        for (var i = 0; i < total; i++)
          if (i < json.length)
            SubStep.fromJson(json[i])
          else
            const SubStep.rest(),
      ]),
    );
  }
}
