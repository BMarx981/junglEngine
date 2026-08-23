/// One sample in a kit: a bundled asset, or a one shot the user imported into
/// that slot.
class KitSampleRef {
  const KitSampleRef({required this.label, required this.assetPath})
    : filePath = null;

  /// A one shot the user imported. Slots stay positional, so this changes what
  /// slot *n* plays and nothing else.
  const KitSampleRef.imported({
    required this.label,
    required String this.filePath,
  }) : assetPath = '';

  /// Short name shown down the side of the Kit grid. Four characters or so:
  /// the gutter is narrow and it gets read at a glance.
  final String label;

  final String assetPath;

  /// Absolute path on disk, set only on an imported one shot.
  final String? filePath;

  bool get isImported => filePath != null;
}

/// A bundled one shot kit. One kit per project, positional: slot *n* plays
/// [samples] *n*, which is what a Kit Beat's slot settings hang off.
///
/// Anything added here needs a line in LICENSING.md before a store build.
class KitRef {
  const KitRef({
    required this.id,
    required this.name,
    required this.samples,
    this.credit = '',
  });

  final String id;
  final String name;
  final List<KitSampleRef> samples;
  final String credit;

  String labelAt(int slot) =>
      (slot >= 0 && slot < samples.length) ? samples[slot].label : '--';

  bool importedAt(int slot) =>
      slot >= 0 && slot < samples.length && samples[slot].isImported;

  /// The same kit with one slot playing something else.
  ///
  /// This is how an imported one shot reaches the mixer: the project resolves
  /// its overrides into an effective [KitRef] once, and everything downstream
  /// -- loading, the grid gutter, audition -- goes on treating a kit as eight
  /// samples in order.
  KitRef withSample(int slot, KitSampleRef sample) {
    if (slot < 0 || slot >= samples.length) return this;
    return KitRef(
      id: id,
      name: name,
      credit: credit,
      samples: [
        for (var i = 0; i < samples.length; i++)
          if (i == slot) sample else samples[i],
      ],
    );
  }
}
