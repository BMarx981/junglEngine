import 'beat.dart';
import 'machine_type.dart';
import 'song.dart';

/// Project > Beats > Song.
///
/// One break per project. M0 creates exactly one Chop Beat and an empty Song,
/// but the hierarchy is real from the start.
class Project {
  Project({
    required this.id,
    required this.name,
    required this.breakId,
    required this.bpm,
    required this.beats,
    this.song = const Song.empty(),
  });

  static const int schemaVersion = 1;

  final String id;
  final String name;

  /// Which bundled break this project resequences.
  final String breakId;
  final double bpm;
  final List<Beat> beats;
  final Song song;

  Beat get firstBeat => beats.first;

  Beat? beatById(String id) {
    for (final b in beats) {
      if (b.id == id) return b;
    }
    return null;
  }

  Project copyWith({
    String? name,
    String? breakId,
    double? bpm,
    List<Beat>? beats,
    Song? song,
  }) => Project(
    id: id,
    name: name ?? this.name,
    breakId: breakId ?? this.breakId,
    bpm: bpm ?? this.bpm,
    beats: beats ?? this.beats,
    song: song ?? this.song,
  );

  /// Replaces a Beat in place, matched by id.
  Project withBeat(Beat beat) => copyWith(
    beats: [
      for (final b in beats)
        if (b.id == beat.id) beat else b,
    ],
  );

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'id': id,
    'name': name,
    'breakId': breakId,
    'bpm': bpm,
    'beats': [for (final b in beats) b.toJson()],
    'song': song.toJson(),
  };

  static Project fromJson(Map<String, Object?> json) {
    final rawBeats = json['beats'];
    final beats = <Beat>[
      if (rawBeats is List)
        for (final b in rawBeats)
          if (b is Map<String, Object?>) Beat.fromJson(b),
    ];
    return Project(
      id: json['id'] as String? ?? 'project',
      name: json['name'] as String? ?? 'junglEngine',
      breakId: json['breakId'] as String? ?? '',
      bpm: json['bpm'] is num ? (json['bpm']! as num).toDouble() : 174,
      beats: beats.isEmpty
          ? [Beat(id: 'beat-1', name: 'A', machineType: MachineType.chop)]
          : beats,
      song: Song.fromJson(json['song']),
    );
  }
}
