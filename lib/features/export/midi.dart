import 'dart:typed_data';

/// A minimal Standard MIDI File writer.
///
/// Enough of the format to say "these notes, at this tempo, in 4/4", which is
/// all a pattern is. There is no reader and there is not going to be one:
/// junglEngine writes MIDI so a pattern can leave, not so one can arrive.

/// One note, in ticks from the top of the pattern.
class MidiNote {
  const MidiNote({
    required this.tick,
    required this.durationTicks,
    required this.note,
    required this.velocity,
  });

  final int tick;
  final int durationTicks;

  /// MIDI note number, 0..127.
  final int note;

  /// 1..127. Zero would be a note off dressed as a note on.
  final int velocity;
}

/// One instrument's worth of notes.
class MidiTrack {
  const MidiTrack({
    required this.name,
    required this.channel,
    required this.notes,
  });

  final String name;

  /// 0..15. Drums and sub go on their own channels because they are two
  /// instruments, whatever the receiving DAW decides to do about it.
  final int channel;

  final List<MidiNote> notes;
}

/// Ticks per quarter note.
///
/// 480 is what every DAW uses and divides cleanly by 3 and by 4, so both
/// sixteenths and the retriggers inside them land on whole ticks, and swing
/// lands within a tick of where the mixer puts it.
const int ticksPerQuarter = 480;

/// Ticks in one sixteenth note step.
const int ticksPerStep = ticksPerQuarter ~/ 4;

/// Writes a format 1 file: a tempo track, then one track per instrument.
Uint8List encodeMidi({
  required double bpm,
  required List<MidiTrack> tracks,
  String name = 'junglengine',
}) {
  final out = BytesBuilder();
  out.add(_header(tracks.length + 1));
  out.add(_tempoTrack(bpm, name));
  for (final track in tracks) {
    out.add(_noteTrack(track));
  }
  return out.toBytes();
}

Uint8List _header(int trackCount) {
  final head = Uint8List(14);
  final view = ByteData.sublistView(head);
  _writeTag(head, 0, 'MThd');
  view.setUint32(4, 6);
  view.setUint16(8, 1); // Format 1: parallel tracks, one tempo map.
  view.setUint16(10, trackCount);
  view.setUint16(12, ticksPerQuarter);
  return head;
}

/// Track 0 carries the tempo and the time signature and no notes, which is what
/// format 1 means by a tempo track.
Uint8List _tempoTrack(double bpm, String name) {
  final events = BytesBuilder();

  events.add(_variable(0));
  events.add(_text(0x03, name));

  events.add(_variable(0));
  final microsecondsPerQuarter = (60000000 / bpm).round();
  events.add([
    0xFF,
    0x51,
    0x03,
    (microsecondsPerQuarter >> 16) & 0xFF,
    (microsecondsPerQuarter >> 8) & 0xFF,
    microsecondsPerQuarter & 0xFF,
  ]);

  events.add(_variable(0));
  // 4/4, a MIDI clock every 24 ticks, 8 32nds to the quarter. Four four is the
  // only time signature this app has: the grid is sixteen sixteenths.
  events.add([0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08]);

  return _chunk(events.toBytes());
}

Uint8List _noteTrack(MidiTrack track) {
  // A note on and a note off are two events at two times, so the track is built
  // as a flat list of moments and then sorted. Offs sort before ons at the same
  // tick: a pad retriggering on the beat should stop and start, not start and
  // then immediately stop.
  final moments = <_Moment>[];
  for (final note in track.notes) {
    final pitch = note.note.clamp(0, 127);
    final velocity = note.velocity.clamp(1, 127);
    final length = note.durationTicks < 1 ? 1 : note.durationTicks;
    moments.add(_Moment(note.tick, false, pitch, velocity));
    moments.add(_Moment(note.tick + length, true, pitch, 0));
  }
  moments.sort((a, b) {
    final byTick = a.tick.compareTo(b.tick);
    if (byTick != 0) return byTick;
    final byKind = (a.off ? 0 : 1).compareTo(b.off ? 0 : 1);
    return byKind != 0 ? byKind : a.note.compareTo(b.note);
  });

  final events = BytesBuilder();
  events.add(_variable(0));
  events.add(_text(0x03, track.name));

  final channel = track.channel.clamp(0, 15);
  var last = 0;
  for (final moment in moments) {
    events.add(_variable(moment.tick - last));
    events.add([
      (moment.off ? 0x80 : 0x90) | channel,
      moment.note,
      moment.velocity,
    ]);
    last = moment.tick;
  }

  events.add(_variable(0));
  events.add([0xFF, 0x2F, 0x00]);
  return _chunk(events.toBytes());
}

class _Moment {
  const _Moment(this.tick, this.off, this.note, this.velocity);

  final int tick;
  final bool off;
  final int note;
  final int velocity;
}

Uint8List _chunk(Uint8List body) {
  final out = Uint8List(8 + body.length);
  _writeTag(out, 0, 'MTrk');
  ByteData.sublistView(out).setUint32(4, body.length);
  out.setRange(8, out.length, body);
  return out;
}

/// A meta event carrying text, such as a track name.
Uint8List _text(int type, String value) {
  final bytes = value.codeUnits.where((c) => c < 128).toList();
  return Uint8List.fromList([0xFF, type, ..._variable(bytes.length), ...bytes]);
}

/// MIDI's variable length quantity: seven bits per byte, high bit set on every
/// byte but the last.
Uint8List _variable(int value) {
  var remaining = value < 0 ? 0 : value;
  final bytes = <int>[remaining & 0x7F];
  remaining >>= 7;
  while (remaining > 0) {
    bytes.insert(0, (remaining & 0x7F) | 0x80);
    remaining >>= 7;
  }
  return Uint8List.fromList(bytes);
}

void _writeTag(Uint8List bytes, int offset, String tag) {
  for (var i = 0; i < 4; i++) {
    bytes[offset + i] = tag.codeUnitAt(i);
  }
}
