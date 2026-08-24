import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/import_ref.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/song.dart';

/// Project > Beats > Song.
///
/// One break and one kit per project. Every Chop Beat resequences that break
/// and every Kit Beat plays that kit; per Beat source selection is parked.
class Project {
  Project({
    required this.id,
    required this.name,
    required this.breakId,
    required this.kitId,
    required this.bpm,
    required this.beats,
    this.song = const Song.empty(),
    this.importedBreak,
    this.importedSlots = const [],
  });

  /// Bumped when a change to the JSON shape needs old files handled. M1 added
  /// Kit fields and M3 added the imports, but every addition has been just
  /// that: a version 1 file still opens.
  static const int schemaVersion = 3;

  final String id;
  final String name;

  /// Which bundled break this project resequences.
  final String breakId;

  /// Which bundled one shot kit its Kit Beats play.
  final String kitId;
  final double bpm;
  final List<Beat> beats;
  final Song song;

  /// The break the user imported, when [breakId] names it rather than a
  /// bundled one. Kept here rather than in a library because there is one
  /// project, and one break per project: the project is already the index.
  final ImportedBreak? importedBreak;

  /// One shots the user imported into Kit slots, at most one per slot.
  final List<ImportedSlot> importedSlots;

  Beat get firstBeat => beats.first;

  /// Whether [breakId] points at [importedBreak].
  bool get breakIsImported => importedBreak?.id == breakId;

  ImportedSlot? importedSlot(int slot) {
    for (final s in importedSlots) {
      if (s.slot == slot) return s;
    }
    return null;
  }

  /// Every imported file this project still points at. Anything in the imports
  /// directory that is not named here is unreachable and can be swept.
  Set<String> get importedFileNames => {
    if (importedBreak != null) importedBreak!.fileName,
    for (final slot in importedSlots) slot.fileName,
  };

  Beat? beatById(String id) {
    for (final b in beats) {
      if (b.id == id) return b;
    }
    return null;
  }

  int indexOfBeat(String id) {
    for (var i = 0; i < beats.length; i++) {
      if (beats[i].id == id) return i;
    }
    return -1;
  }

  /// The Beat an entry points at, or null when it points at one that is gone.
  Beat? beatForEntry(SongEntry entry) => beatById(entry.beatId);

  /// How many bars the arrangement runs for. Entries pointing at a missing
  /// Beat count for nothing rather than breaking the total.
  int get songBars {
    var bars = 0;
    for (final entry in song.entries) {
      final beat = beatById(entry.beatId);
      if (beat != null) bars += beat.bars * entry.repeats;
    }
    return bars;
  }

  /// Whether the song has anything the sequencer could actually play.
  bool get songIsPlayable => songBars > 0;

  Project copyWith({
    String? name,
    String? breakId,
    String? kitId,
    double? bpm,
    List<Beat>? beats,
    Song? song,
    ImportedBreak? importedBreak,
    List<ImportedSlot>? importedSlots,

    /// Going back to a bundled break drops the imported one, and null is the
    /// value being set rather than the absence of an argument, so it needs a
    /// flag of its own.
    bool clearImportedBreak = false,
  }) => Project(
    id: id,
    name: name ?? this.name,
    breakId: breakId ?? this.breakId,
    kitId: kitId ?? this.kitId,
    bpm: bpm ?? this.bpm,
    beats: beats ?? this.beats,
    song: song ?? this.song,
    importedBreak: clearImportedBreak
        ? null
        : (importedBreak ?? this.importedBreak),
    importedSlots: importedSlots ?? this.importedSlots,
  );

  /// Points the project at a break the user imported.
  Project withImportedBreak(ImportedBreak value) =>
      copyWith(breakId: value.id, importedBreak: value, bpm: value.bpm);

  /// Puts an imported one shot in a slot, replacing whatever was there.
  Project withImportedSlot(ImportedSlot value) => copyWith(
    importedSlots: [
      for (final slot in importedSlots)
        if (slot.slot != value.slot) slot,
      value,
    ],
  );

  /// Puts a slot back on the bundled kit's sample.
  Project withoutImportedSlot(int slot) => copyWith(
    importedSlots: [
      for (final s in importedSlots)
        if (s.slot != slot) s,
    ],
  );

  /// Replaces a Beat in place, matched by id.
  Project withBeat(Beat beat) => copyWith(
    beats: [
      for (final b in beats)
        if (b.id == beat.id) beat else b,
    ],
  );

  /// Appends a Beat to the bank.
  Project withNewBeat(Beat beat) => copyWith(beats: [...beats, beat]);

  Project withSong(Song value) => copyWith(song: value);

  /// Inserts a Beat straight after [afterId], which is where a duplicate
  /// belongs: next to the thing it came from.
  Project withBeatAfter(String afterId, Beat beat) {
    final at = indexOfBeat(afterId);
    if (at < 0) return withNewBeat(beat);
    return copyWith(beats: [...beats]..insert(at + 1, beat));
  }

  /// Removes a Beat, and any Song entry that pointed at it. Never removes the
  /// last one: a project always has something open.
  Project withoutBeat(String beatId) {
    if (beats.length <= 1) return this;
    return copyWith(
      beats: [
        for (final b in beats)
          if (b.id != beatId) b,
      ],
      song: Song([
        for (final e in song.entries)
          if (e.beatId != beatId) e,
      ]),
    );
  }

  /// The next free `beat-n` id.
  ///
  /// Unique among the Beats that exist, which is all an id has to be: deleting
  /// a Beat also removes every Song entry that pointed at it, so a number that
  /// comes round again cannot land on a reference to the Beat that is gone.
  String nextBeatId() {
    var highest = 0;
    for (final b in beats) {
      final n = int.tryParse(b.id.split('-').last);
      if (n != null && n > highest) highest = n;
    }
    return 'beat-${highest + 1}';
  }

  /// A, B, C .. Z, then A2, B2 and so on. Short enough for a bank chip.
  String nextBeatName() {
    final taken = {for (final b in beats) b.name};
    for (var round = 0; round < 100; round++) {
      for (var letter = 0; letter < 26; letter++) {
        final name =
            String.fromCharCode(65 + letter) +
            (round == 0 ? '' : '${round + 1}');
        if (!taken.contains(name)) return name;
      }
    }
    return 'B${beats.length + 1}';
  }

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'id': id,
    'name': name,
    'breakId': breakId,
    'kitId': kitId,
    'bpm': bpm,
    'beats': [for (final b in beats) b.toJson()],
    'song': song.toJson(),
    if (importedBreak != null) 'importedBreak': importedBreak!.toJson(),
    if (importedSlots.isNotEmpty)
      'importedSlots': [for (final s in importedSlots) s.toJson()],
  };

  static Project fromJson(Map<String, Object?> json) {
    final rawBeats = json['beats'];
    final beats = <Beat>[
      if (rawBeats is List)
        for (final b in rawBeats)
          if (b is Map<String, Object?>) Beat.fromJson(b),
    ];
    final rawSlots = json['importedSlots'];
    final slots = <ImportedSlot>[
      if (rawSlots is List)
        for (final s in rawSlots) ?ImportedSlot.fromJson(s),
    ];
    return Project(
      id: json['id'] as String? ?? 'project',
      name: json['name'] as String? ?? 'junglEngine',
      breakId: json['breakId'] as String? ?? '',
      kitId: json['kitId'] as String? ?? '',
      bpm: json['bpm'] is num ? (json['bpm']! as num).toDouble() : 174,
      beats: beats.isEmpty
          ? [Beat(id: 'beat-1', name: 'A', machineType: MachineType.chop)]
          : beats,
      song: Song.fromJson(json['song']),
      importedBreak: ImportedBreak.fromJson(json['importedBreak']),
      importedSlots: slots,
    );
  }
}
