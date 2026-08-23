import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/wav.dart';
import 'package:junglengine/features/export/midi.dart';
import 'package:junglengine/features/export/slices_export.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/kit_slot.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/step_mod.dart';
import 'package:junglengine/models/sub_lane.dart';

/// One note read back out of a written file.
class ReadNote {
  const ReadNote(
    this.track,
    this.channel,
    this.tick,
    this.note,
    this.velocity,
    this.durationTicks,
  );

  final int track;
  final int channel;
  final int tick;
  final int note;
  final int velocity;
  final int durationTicks;

  @override
  String toString() =>
      'track $track ch$channel @$tick n$note v$velocity '
      'for $durationTicks';
}

/// Reads back what [encodeMidi] wrote.
///
/// A writer checked only against itself proves nothing. This walks the bytes
/// the way any DAW would, so a file that parses here is a file that opens.
class ReadMidi {
  ReadMidi(this.division, this.microsecondsPerQuarter, this.notes, this.names);

  final int division;
  final int microsecondsPerQuarter;
  final List<ReadNote> notes;
  final List<String> names;

  double get bpm => 60000000 / microsecondsPerQuarter;

  static ReadMidi parse(Uint8List bytes) {
    final view = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes, 0, 4), 'MThd');
    expect(view.getUint32(4), 6);
    expect(view.getUint16(8), 1, reason: 'format 1');
    final trackCount = view.getUint16(10);
    final division = view.getUint16(12);

    var offset = 14;
    var tempo = 500000;
    final notes = <ReadNote>[];
    final names = <String>[];

    for (var track = 0; track < trackCount; track++) {
      expect(String.fromCharCodes(bytes, offset, offset + 4), 'MTrk');
      final length = view.getUint32(offset + 4);
      var at = offset + 8;
      final end = at + length;
      var tick = 0;
      var status = 0;
      final open = <int, List<int>>{};

      while (at < end) {
        final delta = _variable(bytes, at);
        at = delta.next;
        tick += delta.value;

        var byte = bytes[at];
        if (byte < 0x80) {
          // Running status: reuse the last one rather than repeating it.
          byte = status;
        } else {
          at++;
          status = byte;
        }

        if (byte == 0xFF) {
          final type = bytes[at++];
          final size = _variable(bytes, at);
          at = size.next;
          if (type == 0x51) {
            tempo = (bytes[at] << 16) | (bytes[at + 1] << 8) | bytes[at + 2];
          } else if (type == 0x03) {
            names.add(String.fromCharCodes(bytes, at, at + size.value));
          }
          at += size.value;
          continue;
        }

        final kind = byte & 0xF0;
        final channel = byte & 0x0F;
        final note = bytes[at++];
        final velocity = bytes[at++];

        if (kind == 0x90 && velocity > 0) {
          open[note] = [tick, velocity, channel];
        } else if (kind == 0x80 || (kind == 0x90 && velocity == 0)) {
          final started = open.remove(note);
          if (started != null) {
            notes.add(
              ReadNote(
                track,
                started[2],
                started[0],
                note,
                started[1],
                tick - started[0],
              ),
            );
          }
        }
      }
      expect(open, isEmpty, reason: 'every note is turned off again');
      offset = end;
    }

    notes.sort((a, b) {
      final byTick = a.tick.compareTo(b.tick);
      return byTick != 0 ? byTick : a.note.compareTo(b.note);
    });
    return ReadMidi(division, tempo, notes, names);
  }

  static ({int value, int next}) _variable(Uint8List bytes, int at) {
    var value = 0;
    var index = at;
    while (true) {
      final byte = bytes[index++];
      value = (value << 7) | (byte & 0x7F);
      if (byte & 0x80 == 0) break;
    }
    return (value: value, next: index);
  }
}

/// A break whose every frame says which slice it came from, so a sliced export
/// can be checked by reading the audio.
AudioClip countingBreak({int slices = 16, int framesPerSlice = 100}) {
  final frames = slices * framesPerSlice;
  final samples = Float32List(frames * 2);
  for (var f = 0; f < frames; f++) {
    final value = (f ~/ framesPerSlice) / slices;
    samples[f * 2] = value;
    samples[f * 2 + 1] = value;
  }
  return AudioClip(samples: samples, channels: 2, sampleRate: 44100);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('junglengine-parts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<Archive> exported(
    Beat beat, {
    AudioClip? breakClip,
    List<AudioClip> kitClips = const [],
    double bpm = 170,
  }) async {
    final result = await SlicesExporter.export(
      beat: beat,
      breakClip: breakClip ?? countingBreak(),
      kitClips: kitClips,
      bpm: bpm,
      projectName: 'junglEngine',
    );
    return ZipDecoder().decodeBytes(await result.file.readAsBytes());
  }

  Uint8List fileNamed(Archive archive, bool Function(String) matches) {
    final file = archive.files.firstWhere((f) => matches(f.name));
    return file.readBytes()!;
  }

  ReadMidi midiIn(Archive archive) =>
      ReadMidi.parse(fileNamed(archive, (n) => n.endsWith('.mid')));

  group('rendering a modified slice', () {
    /// A ramp from 0 to 1, so direction and rate are both readable.
    AudioClip ramp(int frames) => AudioClip(
      samples: Float32List.fromList([
        for (var f = 0; f < frames; f++) f / (frames - 1),
      ]),
      channels: 1,
      sampleRate: 44100,
    );

    test('reverse really is backwards', () {
      final out = playedAt(ramp(100), StepMod.reverse.rate);
      expect(out.frames, 100);
      expect(out.samples.first, closeTo(1, 0.02));
      expect(out.samples.last, closeTo(0, 0.02));
    });

    test('half speed is an octave down and twice as long', () {
      final out = playedAt(ramp(100), StepMod.halfSpeed.rate);
      expect(out.frames, 200);
      // Halfway through takes twice as long to get halfway up the ramp.
      expect(out.samples[100], closeTo(0.5, 0.02));
    });

    test('pitch down is a fourth, so a third longer', () {
      final out = playedAt(ramp(100), StepMod.pitchDown.rate);
      expect(out.frames, (100 / StepMod.pitchDown.rate).floor());
    });

    test('an unmodified slice is handed back untouched', () {
      final clip = ramp(100);
      expect(identical(playedAt(clip, StepMod.none.rate), clip), isTrue);
    });

    test('scaling changes the level and nothing else', () {
      final out = scaled(ramp(100), 0.25);
      expect(out.frames, 100);
      expect(out.samples.last, closeTo(0.25, 1e-6));
    });
  });

  group('the MIDI writer', () {
    test('writes a file that parses back note for note', () {
      final bytes = encodeMidi(
        bpm: 174,
        tracks: const [
          MidiTrack(
            name: 'chop',
            channel: 0,
            notes: [
              MidiNote(tick: 0, durationTicks: 120, note: 36, velocity: 100),
              MidiNote(tick: 240, durationTicks: 120, note: 41, velocity: 64),
            ],
          ),
        ],
      );

      final read = ReadMidi.parse(bytes);
      expect(read.division, ticksPerQuarter);
      expect(read.bpm, closeTo(174, 0.01));
      expect(read.notes, hasLength(2));
      expect(read.notes.first.note, 36);
      expect(read.notes.first.tick, 0);
      expect(read.notes.first.durationTicks, 120);
      expect(read.notes.last.note, 41);
      expect(read.notes.last.tick, 240);
      expect(read.notes.last.velocity, 64);
    });

    test('a tick past 127 still round trips, which is the whole of the'
        ' variable length encoding', () {
      final bytes = encodeMidi(
        bpm: 120,
        tracks: const [
          MidiTrack(
            name: 't',
            channel: 0,
            notes: [
              MidiNote(tick: 0, durationTicks: 10, note: 36, velocity: 1),
              MidiNote(tick: 100000, durationTicks: 10, note: 36, velocity: 1),
            ],
          ),
        ],
      );
      expect(ReadMidi.parse(bytes).notes.last.tick, 100000);
    });
  });

  group('a chop beat', () {
    Beat chop({
      ChopPattern? pattern,
      SubLane? sub,
      double swing = 0,
      int bars = 1,
    }) => Beat(
      id: 'b',
      name: 'A',
      bars: bars,
      sliceCount: 16,
      chop: pattern ?? ChopPattern.identity(bars: bars, sliceCount: 16),
      sub: sub,
      swing: swing,
    );

    test('every slice is in the zip, in mapping order', () async {
      final archive = await exported(chop());
      final samples = archive.files
          .where((f) => f.name.startsWith('samples/'))
          .toList();

      expect(samples, hasLength(16));
      expect(samples.first.name, 'samples/01_slice-01.wav');
      expect(samples.last.name, 'samples/16_slice-16.wav');

      // Numbered in mapping order means sorting by name is the mapping.
      final names = [for (final f in samples) f.name]..sort();
      expect(names, [for (final f in samples) f.name]);
    });

    test('the samples are the slices, not the whole break', () async {
      final archive = await exported(chop(), breakClip: countingBreak());
      final third = decodeWav(
        fileNamed(archive, (n) => n.contains('slice-03')),
      );

      expect(third.frames, 100);
      // Slice three of sixteen carries the value 2/16.
      expect(third.samples[0], closeTo(2 / 16, 1e-6));
    });

    test(
      'the identity pattern is sixteen notes up from the base note',
      () async {
        final read = midiIn(await exported(chop()));
        expect(read.notes, hasLength(16));
        for (var step = 0; step < 16; step++) {
          expect(read.notes[step].note, baseNote + step);
          expect(read.notes[step].tick, step * ticksPerStep);
          expect(read.notes[step].channel, drumChannel);
        }
      },
    );

    test('an empty step is a rest, not a note', () async {
      final pattern = ChopPattern.ofSlices([
        0, null, 2, null, //
        for (var i = 0; i < 12; i++) null,
      ]);
      final read = midiIn(await exported(chop(pattern: pattern)));
      expect(read.notes, hasLength(2));
      expect(read.notes.map((n) => n.note), [baseNote, baseNote + 2]);
    });

    test('swing moves the odd sixteenths and leaves the even ones', () async {
      final read = midiIn(await exported(chop(swing: 1)));
      // Full swing is half a step late, which at 120 ticks a step is 60.
      expect(read.notes[0].tick, 0);
      expect(read.notes[1].tick, ticksPerStep + ticksPerStep ~/ 2);
      expect(read.notes[2].tick, 2 * ticksPerStep);
      expect(read.notes[3].tick, 3 * ticksPerStep + ticksPerStep ~/ 2);
    });

    test(
      'a retrigger is four notes on the same sample, not a fifth file',
      () async {
        final pattern = ChopPattern([
          const ChopStep(0, mod: StepMod.retrigger),
          for (var i = 0; i < 15; i++) null,
        ]);
        final archive = await exported(chop(pattern: pattern));

        expect(
          archive.files.where((f) => f.name.startsWith('samples/')),
          hasLength(16),
          reason: 'retrigger needs no sample of its own',
        );

        final read = midiIn(archive);
        expect(read.notes, hasLength(4));
        expect(read.notes.map((n) => n.note).toSet(), {baseNote});
        expect(read.notes.map((n) => n.tick), [0, 30, 60, 90]);
      },
    );

    test('reverse gets a sample of its own, above the slices', () async {
      final pattern = ChopPattern([
        const ChopStep(3, mod: StepMod.reverse),
        for (var i = 0; i < 15; i++) null,
      ]);
      final archive = await exported(chop(pattern: pattern));

      expect(
        archive.files.where((f) => f.name.startsWith('samples/')),
        hasLength(17),
      );
      expect(archive.files.any((f) => f.name.contains('slice-04-rev')), isTrue);

      final read = midiIn(archive);
      expect(read.notes.single.note, baseNote + 16);

      // And it really is backwards: slice four of the counting break runs from
      // 3/16 up, so reversed it starts at the end of that slice.
      final forwards = decodeWav(
        fileNamed(archive, (n) => n.contains('17_slice-04-rev')),
      );
      expect(forwards.frames, 100);
      expect(forwards.samples[0], closeTo(3 / 16, 1e-6));
    });

    test('half speed is twice as long', () async {
      final pattern = ChopPattern([
        const ChopStep(0, mod: StepMod.halfSpeed),
        for (var i = 0; i < 15; i++) null,
      ]);
      final archive = await exported(chop(pattern: pattern));
      final variant = decodeWav(fileNamed(archive, (n) => n.contains('-half')));
      expect(variant.frames, 200);
    });

    test(
      'the same modifier on the same slice is one file, not one per step',
      () async {
        final pattern = ChopPattern([
          const ChopStep(0, mod: StepMod.reverse),
          const ChopStep(0, mod: StepMod.reverse),
          const ChopStep(1, mod: StepMod.reverse),
          for (var i = 0; i < 13; i++) null,
        ]);
        final archive = await exported(chop(pattern: pattern));
        expect(
          archive.files.where((f) => f.name.startsWith('samples/')),
          hasLength(18),
          reason: '16 slices and two distinct variants',
        );
        final read = midiIn(archive);
        expect(read.notes.map((n) => n.note), [
          baseNote + 16,
          baseNote + 16,
          baseNote + 17,
        ]);
      },
    );
  });

  group('a kit beat', () {
    List<AudioClip> kit() => [
      for (var i = 0; i < 8; i++)
        AudioClip(
          samples: Float32List.fromList(List<double>.filled(200, (i + 1) / 10)),
          channels: 1,
          sampleRate: 44100,
        ),
    ];

    Beat kitBeat(KitPattern pattern) =>
        Beat(id: 'b', name: 'K', machineType: MachineType.kit, kit: pattern);

    test('eight slots, eight samples, from the base note up', () async {
      final pattern = KitPattern.empty()
          .withCell(0, 0, KitVelocity.hard)
          .withCell(1, 4, KitVelocity.medium)
          .withCell(7, 8, KitVelocity.soft);

      final archive = await exported(kitBeat(pattern), kitClips: kit());
      expect(
        archive.files.where((f) => f.name.startsWith('samples/')),
        hasLength(8),
      );
      expect(archive.files.first.name, 'samples/01_slot-01.wav');

      final read = midiIn(archive);
      expect(read.notes, hasLength(3));
      expect(read.notes[0].note, baseNote);
      expect(read.notes[0].velocity, 127);
      expect(read.notes[1].note, baseNote + 1);
      expect(read.notes[1].velocity, (KitVelocity.medium.gain * 127).round());
      expect(read.notes[2].note, baseNote + 7);
      expect(read.notes[2].velocity, (KitVelocity.soft.gain * 127).round());
    });

    test('slot volume and pitch are baked into the file', () async {
      final beat = kitBeat(
        KitPattern.empty().withCell(0, 0, KitVelocity.hard),
      ).withSlot(0, const KitSlot(volume: 0.5, pitch: -12));

      final archive = await exported(beat, kitClips: kit());
      final slot = decodeWav(fileNamed(archive, (n) => n.contains('slot-01')));

      // An octave down is twice the length, and half volume is half the level.
      expect(slot.frames, 400);
      expect(slot.samples[0], closeTo(0.1 * 0.5, 1e-3));
    });
  });

  group('the sub lane', () {
    test(
      'is a track of its own, on its own channel, at real pitches',
      () async {
        final sub = SubLane.empty()
            .withStep(0, const SubStep(semitone: 0))
            .withStep(4, const SubStep(semitone: 7, accent: true));

        final beat = Beat(
          id: 'b',
          name: 'A',
          sliceCount: 16,
          chop: ChopPattern.empty(),
          sub: sub,
        );

        final read = midiIn(await exported(beat));
        expect(read.notes, hasLength(2));
        expect(read.notes.every((n) => n.channel == subChannel), isTrue);
        expect(read.notes[0].note, beat.subRootMidi);
        expect(read.notes[1].note, beat.subRootMidi + 7);
        // An accent is a louder note on the way out.
        expect(read.notes[1].velocity, greaterThan(read.notes[0].velocity));
      },
    );

    test('a tie holds the note instead of restarting it', () async {
      final sub = SubLane.empty()
          .withStep(0, const SubStep(semitone: 0))
          .withStep(1, const SubStep(tie: true))
          .withStep(2, const SubStep(tie: true));

      final beat = Beat(
        id: 'b',
        name: 'A',
        sliceCount: 16,
        chop: ChopPattern.empty(),
        sub: sub,
      );

      final read = midiIn(await exported(beat));
      expect(read.notes, hasLength(1));
      expect(read.notes.single.durationTicks, 3 * ticksPerStep);
    });

    test('an empty sub lane is no track at all', () async {
      final beat = Beat(
        id: 'b',
        name: 'A',
        sliceCount: 16,
        chop: ChopPattern.identity(sliceCount: 16),
      );
      final read = midiIn(await exported(beat));
      expect(read.notes.every((n) => n.channel == drumChannel), isTrue);
    });
  });

  group('the zip', () {
    test('carries a README that names every note', () async {
      final archive = await exported(
        Beat(
          id: 'b',
          name: 'A',
          sliceCount: 16,
          chop: ChopPattern.identity(sliceCount: 16),
        ),
      );
      final readme = String.fromCharCodes(
        fileNamed(archive, (n) => n == 'README.txt'),
      );

      expect(readme, contains('junglEngine export'));
      expect(readme, contains('NN-XT'));
      expect(readme, contains('Kong'));
      expect(readme, contains('01_slice-01.wav'));
      expect(readme, contains('16_slice-16.wav'));
    });

    test('is named after the beat and the tempo', () async {
      final result = await SlicesExporter.export(
        beat: Beat(
          id: 'b',
          name: 'Roller',
          sliceCount: 16,
          chop: ChopPattern.identity(sliceCount: 16),
        ),
        breakClip: countingBreak(),
        kitClips: const [],
        bpm: 172,
        projectName: 'junglEngine',
      );
      expect(result.fileName, 'junglengine-roller-172bpm-1bar.zip');
    });
  });
}
