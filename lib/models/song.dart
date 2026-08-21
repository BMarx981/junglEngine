/// A Beat reference with a repeat count.
class SongEntry {
  const SongEntry({required this.beatId, this.repeats = 1});

  final String beatId;
  final int repeats;

  Map<String, Object?> toJson() => {'beatId': beatId, 'repeats': repeats};

  static SongEntry fromJson(Object? json) {
    if (json is! Map) return const SongEntry(beatId: '');
    return SongEntry(
      beatId: json['beatId'] as String? ?? '',
      repeats: json['repeats'] is int ? json['repeats']! as int : 1,
    );
  }
}

/// An ordered list of Beat references. Agnostic to machine type, so a Chop Beat
/// and a Kit Beat sit side by side in the same song.
///
/// The Song view itself lands in M2; the data lives here from M0 so that
/// arrangement is never a migration.
class Song {
  const Song(this.entries);

  const Song.empty() : entries = const [];

  final List<SongEntry> entries;

  bool get isEmpty => entries.isEmpty;

  List<Object?> toJson() => [for (final e in entries) e.toJson()];

  static Song fromJson(Object? json) {
    if (json is! List) return const Song.empty();
    return Song(
      List.unmodifiable([for (final e in json) SongEntry.fromJson(e)]),
    );
  }
}
