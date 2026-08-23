/// What a Chop step does to its slice when it fires.
///
/// Four modifiers, and that is the ceiling: reverse, retrigger, pitch down,
/// half speed. These are the edits a jungle producer makes to a slice by hand,
/// and between them they cover the moves the grid alone cannot make. Anything
/// that would need a fifth is an effect, and effects are parked.
///
/// Each one is data, not code: the renderer reads [rate] and [retriggers] and
/// there is no per modifier branch in the mixer.
enum StepMod {
  /// Plays the slice as it is.
  none('', 1.0, 1),

  /// Plays the slice backwards. The tail becomes the transient, which is the
  /// reverse snare every jungle roll ends on.
  reverse('rev', -1.0, 1),

  /// Four hits inside the step instead of one, all from the head of the slice.
  retrigger('ret', 1.0, 4),

  /// Down a fourth. Enough to hear as a different drum, not so far that it
  /// stops being one.
  pitchDown('pd', 0.7491535384, 1),

  /// Down an octave, so the slice is also twice as long: the classic weight on
  /// a snare that has to land.
  halfSpeed('half', 0.5, 1);

  const StepMod(this.code, this.rate, this.retriggers);

  /// Short key written to JSON. Stable: it is in saved projects.
  ///
  /// There is deliberately no display label next to it. One used to sit here,
  /// one argument along, and a translation pass that took the wrong literal
  /// would have silently rewritten every saved project. The picker's wording
  /// lives in `stepModLabel` in the grid feature, where it can be localised.
  final String code;

  /// Playback rate, negative when the slice is read backwards.
  final double rate;

  /// How many times the head of the slice fires inside the step.
  final int retriggers;

  bool get isNone => this == StepMod.none;

  String? toJson() => isNone ? null : code;

  static StepMod fromJson(Object? value) {
    if (value is! String) return StepMod.none;
    for (final mod in StepMod.values) {
      if (mod.code == value) return mod;
    }
    return StepMod.none;
  }
}
