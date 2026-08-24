const List<String> _names = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

/// MIDI note number to something a producer can read, e.g. 36 -> C2.
String noteName(int midi) {
  final octave = (midi ~/ 12) - 1;
  return '${_names[midi % 12]}$octave';
}

/// Whether this note falls on a black key.
///
/// Only the sub editor's piano roll cares: shading the black rows is what
/// makes a column of twenty five identical cells readable as a keyboard.
bool isBlackKey(int midi) => _names[midi % 12].length > 1;
