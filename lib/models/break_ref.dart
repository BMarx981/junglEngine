/// A break available to load. One break per project; every Chop Beat in the
/// project resequences this one source.
class BreakRef {
  const BreakRef({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.bpm,
    required this.bars,
    this.credit = '',
  });

  final String id;
  final String name;

  /// Bundled asset path, resolved through the Flutter asset bundle.
  final String assetPath;

  /// The break's own tempo. A project opens at this tempo so that the identity
  /// pattern reconstructs the original loop exactly.
  final double bpm;

  /// How many bars long the source loop is.
  final int bars;

  /// Licensing / attribution line. Must be filled in before any store build.
  final String credit;
}
