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
  }) : filePath = null;

  /// A break the user imported, already trimmed to its loop and written into
  /// the imports directory.
  ///
  /// The path is resolved when the project opens rather than stored, because
  /// the documents directory moves between launches on iOS.
  const BreakRef.imported({
    required this.id,
    required this.name,
    required String this.filePath,
    required this.bpm,
    required this.bars,
  }) : assetPath = '',
       credit = 'Imported by you. Never bundled and never redistributed.';

  final String id;
  final String name;

  /// Bundled asset path, resolved through the Flutter asset bundle. Empty on
  /// an imported break.
  final String assetPath;

  /// Absolute path on disk, set only on an imported break.
  final String? filePath;

  /// The break's own tempo. A project opens at this tempo so that the identity
  /// pattern reconstructs the original loop exactly.
  final double bpm;

  /// How many bars the source loop is.
  final int bars;

  /// Licensing / attribution line. Must be filled in before any store build.
  final String credit;

  /// Whether this came from the user rather than the bundle. Imported breaks
  /// are Pro, are never redistributed, and never need a LICENSING.md row.
  bool get isImported => filePath != null;
}
