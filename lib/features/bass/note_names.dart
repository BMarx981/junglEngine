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
