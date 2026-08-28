/// The sub synth's entire control surface.
///
/// Six parameters, and that is the ceiling. Anything that would need a seventh
/// belongs in a different app. See the sub synth spec in CLAUDE.md, which also
/// records why the ceiling was five until the Reese and why it moved exactly
/// once.
class SubPatch {
  const SubPatch({
    this.tone = 0.125,
    this.cutoff = 0.45,
    this.drive = 0.2,
    this.decay = 0.35,
    this.glide = 0.3,
    this.detune = 0.0,
  });

  /// Core waveshape: sine at 0, triangle at 0.5, saw at 1, blended between.
  ///
  /// The lower half is the sine to triangle blend this knob used to be, at
  /// half the travel. That is why the default is 0.125 rather than the 0.25 it
  /// reads as in a version 3 file: same sound, new scale. [fromJson] does the
  /// same halving to every patch a user already saved.
  final double tone;

  /// Lowpass corner, 0..1 mapped exponentially over the bass register.
  final double cutoff;

  /// Soft clip amount into the filter.
  final double drive;

  /// Amp envelope release, 0..1 mapped to roughly 20 ms .. 900 ms.
  final double decay;

  /// Portamento time for tied notes, 0..1 mapped to 0 .. 220 ms.
  final double glide;

  /// How far the two oscillators are pushed apart, 0..1 mapped to 0 .. 30
  /// cents either side of the note.
  ///
  /// This is the Reese knob. At 0 the two oscillators are the same frequency
  /// at the same phase and sum to exactly one oscillator, which is the whole
  /// instrument as it shipped before this parameter existed. Wind it up and
  /// they beat against each other, which is the entire sound of a Reese and
  /// the one thing a filter cannot fake. Detune is in cents, not hertz, so the
  /// beating stays musically proportional as the bassline moves.
  final double detune;

  /// Six, and six is the ceiling the sub synth spec sets.
  ///
  /// The count is a model concern because it is a promise about the
  /// instrument. What the six are *called* is a UI concern, so the words live
  /// beside the panel that draws them, in `subParameterLabels`.
  static const int parameterCount = 6;

  /// The widest the oscillators spread, in cents either side of the note.
  static const double maxDetuneCents = 30.0;

  double parameter(int index) => switch (index) {
    0 => tone,
    1 => cutoff,
    2 => drive,
    3 => decay,
    4 => glide,
    _ => detune,
  };

  SubPatch withParameter(int index, double value) {
    final v = value.clamp(0.0, 1.0);
    return switch (index) {
      0 => copyWith(tone: v),
      1 => copyWith(cutoff: v),
      2 => copyWith(drive: v),
      3 => copyWith(decay: v),
      4 => copyWith(glide: v),
      _ => copyWith(detune: v),
    };
  }

  SubPatch copyWith({
    double? tone,
    double? cutoff,
    double? drive,
    double? decay,
    double? glide,
    double? detune,
  }) => SubPatch(
    tone: tone ?? this.tone,
    cutoff: cutoff ?? this.cutoff,
    drive: drive ?? this.drive,
    decay: decay ?? this.decay,
    glide: glide ?? this.glide,
    detune: detune ?? this.detune,
  );

  Map<String, Object?> toJson() => {
    'tone': tone,
    'cutoff': cutoff,
    'drive': drive,
    'decay': decay,
    'glide': glide,
    'detune': detune,
  };

  /// Reads a patch, migrating [tone] out of the pre Reese scale on the way.
  ///
  /// A patch written before the second oscillator has no `detune` key and its
  /// `tone` runs sine to triangle across the whole 0..1. A patch written after
  /// it always has one, and its `tone` runs sine to triangle to saw. So the
  /// presence of `detune` is the discriminator, rather than the schema version
  /// on the project envelope, which does not reach down this far and which
  /// this model has no business knowing about.
  ///
  /// Halving is exact in binary, so a migrated patch renders the same samples
  /// it always did rather than merely close ones.
  static SubPatch fromJson(Object? json) {
    if (json is! Map) return const SubPatch();
    double? read(String key) {
      final v = json[key];
      return v is num ? v.toDouble().clamp(0.0, 1.0) : null;
    }

    const d = SubPatch();
    final detune = read('detune');
    final tone = read('tone');
    return SubPatch(
      tone: switch ((tone, detune)) {
        (null, _) => d.tone,
        (final t?, null) => t / 2,
        (final t?, _) => t,
      },
      cutoff: read('cutoff') ?? d.cutoff,
      drive: read('drive') ?? d.drive,
      decay: read('decay') ?? d.decay,
      glide: read('glide') ?? d.glide,
      detune: detune ?? d.detune,
    );
  }
}
