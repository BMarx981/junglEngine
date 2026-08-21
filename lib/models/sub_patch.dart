/// The sub synth's entire control surface.
///
/// Five parameters, and that is the ceiling. Anything that would need a sixth
/// belongs in a different app. See the sub synth spec in CLAUDE.md.
class SubPatch {
  const SubPatch({
    this.tone = 0.25,
    this.cutoff = 0.45,
    this.drive = 0.2,
    this.decay = 0.35,
    this.glide = 0.3,
  });

  /// Sine at 0, triangle at 1, blended in between.
  final double tone;

  /// Lowpass corner, 0..1 mapped exponentially over the bass register.
  final double cutoff;

  /// Soft clip amount into the filter.
  final double drive;

  /// Amp envelope release, 0..1 mapped to roughly 20 ms .. 900 ms.
  final double decay;

  /// Portamento time for tied notes, 0..1 mapped to 0 .. 220 ms.
  final double glide;

  static const List<String> parameterNames = [
    'TONE',
    'CUTOFF',
    'DRIVE',
    'DECAY',
    'GLIDE',
  ];

  double parameter(int index) => switch (index) {
    0 => tone,
    1 => cutoff,
    2 => drive,
    3 => decay,
    _ => glide,
  };

  SubPatch withParameter(int index, double value) {
    final v = value.clamp(0.0, 1.0);
    return switch (index) {
      0 => copyWith(tone: v),
      1 => copyWith(cutoff: v),
      2 => copyWith(drive: v),
      3 => copyWith(decay: v),
      _ => copyWith(glide: v),
    };
  }

  SubPatch copyWith({
    double? tone,
    double? cutoff,
    double? drive,
    double? decay,
    double? glide,
  }) => SubPatch(
    tone: tone ?? this.tone,
    cutoff: cutoff ?? this.cutoff,
    drive: drive ?? this.drive,
    decay: decay ?? this.decay,
    glide: glide ?? this.glide,
  );

  Map<String, Object?> toJson() => {
    'tone': tone,
    'cutoff': cutoff,
    'drive': drive,
    'decay': decay,
    'glide': glide,
  };

  static SubPatch fromJson(Object? json) {
    if (json is! Map) return const SubPatch();
    double read(String key, double fallback) {
      final v = json[key];
      return v is num ? v.toDouble().clamp(0.0, 1.0) : fallback;
    }

    const d = SubPatch();
    return SubPatch(
      tone: read('tone', d.tone),
      cutoff: read('cutoff', d.cutoff),
      drive: read('drive', d.drive),
      decay: read('decay', d.decay),
      glide: read('glide', d.glide),
    );
  }
}
