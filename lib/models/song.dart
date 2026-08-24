/// A Beat reference with a repeat count.
class SongEntry {
  const SongEntry({required this.beatId, int repeats = 1})
    : repeats = repeats < minRepeats
          ? minRepeats
          : (repeats > maxRepeats ? maxRepeats : repeats);

  final String beatId;

  /// How many times this Beat plays before the song moves on.
  final int repeats;

  /// An entry that played zero times would be a card doing nothing, and one
  /// that played sixteen times is already a section: past that, add a card.
  static const int minRepeats = 1;
  static const int maxRepeats = 16;

  SongEntry withRepeats(int value) => SongEntry(beatId: beatId, repeats: value);

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
/// A list, not a timeline: entries follow each other, there are no free
/// positions and nothing overlaps. The horizontal timeline is parked.
class Song {
  const Song(this.entries);

  const Song.empty() : entries = const [];

  final List<SongEntry> entries;

  bool get isEmpty => entries.isEmpty;

  bool get isNotEmpty => entries.isNotEmpty;

  int get length => entries.length;

  SongEntry? entryAt(int index) =>
      (index >= 0 && index < entries.length) ? entries[index] : null;

  /// Total passes of a pattern the song plays. Not bars: a Beat can be eight
  /// bars long, so bar counts need the Beats themselves.
  int get totalPasses {
    var total = 0;
    for (final e in entries) {
      total += e.repeats;
    }
    return total;
  }

  Song withEntry(SongEntry entry) => Song([...entries, entry]);

  /// Inserts [entry] so that it lands at [index], which is what dropping a
  /// Beat between two cards means. Out of range indices clamp to the ends
  /// rather than being refused: a drop past the last card is an append.
  Song withEntryAt(SongEntry entry, int index) {
    final next = [...entries];
    next.insert(index.clamp(0, next.length), entry);
    return Song(next);
  }

  Song withoutAt(int index) {
    if (index < 0 || index >= entries.length) return this;
    return Song([
      for (var i = 0; i < entries.length; i++)
        if (i != index) entries[i],
    ]);
  }

  Song withRepeatsAt(int index, int repeats) {
    if (index < 0 || index >= entries.length) return this;
    return Song([
      for (var i = 0; i < entries.length; i++)
        i == index ? entries[i].withRepeats(repeats) : entries[i],
    ]);
  }

  /// Moves the entry at [from] so that it sits at [to] in the resulting list.
  /// This is drag to reorder, which is the only editing gesture the Song view
  /// has beyond the repeat stepper.
  Song moved(int from, int to) {
    if (from < 0 || from >= entries.length) return this;
    final next = [...entries];
    final entry = next.removeAt(from);
    next.insert(to.clamp(0, next.length), entry);
    return Song(next);
  }

  List<Object?> toJson() => [for (final e in entries) e.toJson()];

  static Song fromJson(Object? json) {
    if (json is! List) return const Song.empty();
    return Song(
      List.unmodifiable([for (final e in json) SongEntry.fromJson(e)]),
    );
  }
}
