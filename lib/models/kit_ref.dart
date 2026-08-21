/// One sample in a bundled kit.
class KitSampleRef {
  const KitSampleRef({required this.label, required this.assetPath});

  /// Short name shown down the side of the Kit grid. Four characters or so:
  /// the gutter is narrow and it gets read at a glance.
  final String label;

  final String assetPath;
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
}
