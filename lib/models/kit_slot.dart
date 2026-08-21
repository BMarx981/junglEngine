/// Per slot settings on a Kit Beat.
///
/// Volume and pitch, and nothing else. No per slot effects, no choke group:
/// see the Kit machine spec in CLAUDE.md.
class KitSlot {
  const KitSlot({this.volume = 0.8, this.pitch = 0});

  /// 0..1, linear. Starts below unity so a slot has somewhere to go up to.
  final double volume;

  /// Playback pitch in semitones. Moves the sample's rate, so a tuned down hit
  /// is also a longer one, which is the point.
  final int pitch;

  static const int minPitch = -12;
  static const int maxPitch = 12;

  /// Playback rate for [pitch].
  double get rate => _rates[(pitch - minPitch).clamp(0, _rates.length - 1)];

  KitSlot copyWith({double? volume, int? pitch}) => KitSlot(
    volume: (volume ?? this.volume).clamp(0.0, 1.0),
    pitch: (pitch ?? this.pitch).clamp(minPitch, maxPitch),
  );

  /// One unity slot per position, which is what a fresh Kit Beat opens with.
  static List<KitSlot> defaults(int count) =>
      List<KitSlot>.unmodifiable(List<KitSlot>.filled(count, const KitSlot()));

  Map<String, Object?> toJson() => {'vol': volume, 'pitch': pitch};

  static KitSlot fromJson(Object? json) {
    if (json is! Map) return const KitSlot();
    final volume = json['vol'];
    final pitch = json['pitch'];
    return KitSlot(
      volume: volume is num ? volume.toDouble().clamp(0.0, 1.0) : 0.8,
      pitch: pitch is int ? pitch.clamp(minPitch, maxPitch) : 0,
    );
  }

  /// Semitone to rate table, so the renderer never calls `pow` per trigger.
  static const List<double> _rates = [
    0.5,
    0.5297315471,
    0.5612310242,
    0.5946035575,
    0.6299605249,
    0.6674199271,
    0.7071067812,
    0.7491535384,
    0.7937005260,
    0.8408964153,
    0.8908987181,
    0.9438743127,
    1.0,
    1.0594630944,
    1.1224620483,
    1.1892071150,
    1.2599210499,
    1.3348398542,
    1.4142135624,
    1.4983070769,
    1.5874010520,
    1.6817928305,
    1.7817974363,
    1.8877486254,
    2.0,
  ];
}
