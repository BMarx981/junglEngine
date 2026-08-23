/// What the user brought in themselves.
///
/// Imported audio lives as a file in the app's imports directory and is
/// described here, in the project, rather than in a library of its own. There
/// is one project and one break per project, so the project is already the
/// index: a second registry would only be a second thing to keep in step.
///
/// Everything here is written at import time and never edited afterwards. The
/// trim is baked into the file, so a re-trim is a re-import, and the file on
/// disk is always exactly the loop the grid is chopping.
library;

/// A break the user imported: trimmed, named, and known to be [bars] long at
/// [bpm].
///
/// [bars] is as load bearing here as it is on a bundled break, because slice
/// divisions are per bar. It is not guessed: the import screen makes the user
/// say it.
class ImportedBreak {
  const ImportedBreak({
    required this.id,
    required this.name,
    required this.fileName,
    required this.bpm,
    required this.bars,
  });

  final String id;
  final String name;

  /// File name inside the imports directory. Not a full path: the documents
  /// directory moves between app launches on iOS, so a stored absolute path
  /// goes stale and a stored name does not.
  final String fileName;

  final double bpm;
  final int bars;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'file': fileName,
    'bpm': bpm,
    'bars': bars,
  };

  static ImportedBreak? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final fileName = json['file'];
    if (id is! String || fileName is! String) return null;
    final bpm = json['bpm'];
    final bars = json['bars'];
    return ImportedBreak(
      id: id,
      name: json['name'] is String ? json['name']! as String : 'Imported',
      fileName: fileName,
      bpm: bpm is num ? bpm.toDouble() : 170,
      bars: bars is int && bars > 0 ? bars : 1,
    );
  }
}

/// A one shot the user imported into a Kit slot.
///
/// Slots stay positional, so this replaces what slot [slot] plays and nothing
/// else: the Beat's volume and pitch for that position are untouched, which is
/// the same deal as switching to a different bundled kit.
class ImportedSlot {
  const ImportedSlot({
    required this.slot,
    required this.label,
    required this.fileName,
  });

  final int slot;

  /// Short name for the Kit grid gutter, taken from the file name and cut to
  /// something that fits.
  final String label;

  final String fileName;

  Map<String, Object?> toJson() => {
    'slot': slot,
    'label': label,
    'file': fileName,
  };

  static ImportedSlot? fromJson(Object? json) {
    if (json is! Map) return null;
    final slot = json['slot'];
    final fileName = json['file'];
    if (slot is! int || slot < 0 || fileName is! String) return null;
    return ImportedSlot(
      slot: slot,
      label: json['label'] is String ? json['label']! as String : 'USER',
      fileName: fileName,
    );
  }
}
