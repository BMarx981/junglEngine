import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/wav.dart';
import 'package:junglengine/features/bass/note_names.dart';
import 'package:junglengine/features/export/midi.dart';
import 'package:junglengine/features/export/wav_export.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/step_mod.dart';

/// What a step modifier is called inside an exported sample name.
///
/// English in every locale, and deliberately so: this ends up as a sample name
/// in Kong or NN-XT, next to a file name built from [StepMod.code]. Names that
/// go into other people's projects have to be stable and ASCII, so this does
/// not follow the interface language.
String _exportName(StepMod mod) => switch (mod) {
  StepMod.none => '',
  StepMod.reverse => 'reverse',
  StepMod.retrigger => 'retrig',
  StepMod.pitchDown => 'pitch down',
  StepMod.halfSpeed => 'half speed',
};

/// The Beat as a MIDI file and the samples it plays, in a zip.
///
/// This is the export for finishing somewhere else. A WAV is the loop; this is
/// the parts, mapped so that dropping the samples into Kong or NN-XT and the
/// MIDI onto a track gives you back what the phone was playing, and then lets
/// you take it apart.
///
/// Samples are numbered in mapping order, because both of Reason's samplers map
/// a multiple selection up the keyboard in the order the files are listed, and
/// a leading number is what makes "the order the files are listed" mean
/// something.

/// The MIDI note the first sample answers to.
///
/// 36 is pad 1 on Kong and the bottom of a chromatic NN-XT map, which is where
/// both of them expect a drum kit to start.
const int baseNote = 36;

/// The channel the drums are on, and the one the sub is on. Two instruments,
/// two channels, whatever the receiving DAW decides to do about that.
const int drumChannel = 0;
const int subChannel = 1;

/// One file in the zip and the note that plays it.
class ExportedSample {
  const ExportedSample({
    required this.fileName,
    required this.note,
    required this.label,
    required this.clip,
  });

  final String fileName;
  final int note;

  /// What the README calls it.
  final String label;

  final AudioClip clip;
}

class SlicesExporter {
  const SlicesExporter._();

  /// Renders the open Beat to a zip and returns the file.
  ///
  /// One Beat, one pass. A song is what the WAV export is for: an arrangement
  /// mixing both machines would need two sample sets and two mappings in one
  /// file, and what a sampler wants is one instrument.
  static Future<ExportResult> export({
    required Beat beat,
    required AudioClip breakClip,
    required List<AudioClip> kitClips,
    required double bpm,
    required String projectName,
  }) async {
    final samples = beat.isKit
        ? _kitSamples(beat, kitClips)
        : _chopSamples(beat, breakClip);

    final tracks = <MidiTrack>[
      MidiTrack(
        name: beat.isKit ? 'kit' : 'chop',
        channel: drumChannel,
        notes: beat.isKit ? _kitNotes(beat) : _chopNotes(beat, samples),
      ),
      if (!beat.sub.isEmpty)
        MidiTrack(name: 'sub', channel: subChannel, notes: _subNotes(beat)),
    ];

    final stem = WavExporter.fileNameFor(
      beat.name,
      bpm,
      beat.bars,
    ).replaceAll('.wav', '');

    final archive = Archive();
    for (final sample in samples) {
      archive.addFile(
        ArchiveFile.bytes(
          'samples/${sample.fileName}',
          encodeWav(
            sample.clip.samples,
            sampleRate: sample.clip.sampleRate,
            channels: sample.clip.channels,
          ),
        ),
      );
    }
    archive.addFile(
      ArchiveFile.bytes(
        '$stem.mid',
        encodeMidi(bpm: bpm, tracks: tracks, name: '$projectName ${beat.name}'),
      ),
    );
    archive.addFile(
      ArchiveFile.bytes(
        'README.txt',
        Uint8List.fromList(
          readme(beat: beat, samples: samples, bpm: bpm, stem: stem).codeUnits,
        ),
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$stem.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    return ExportResult(
      file: file,
      bars: beat.bars,
      duration: Duration(
        microseconds: (beat.bars * 4 * 60000000 / bpm).round(),
      ),
    );
  }

  // --- Samples -------------------------------------------------------------

  /// Every slice of the break, then one extra file per modified step that needs
  /// its own audio.
  ///
  /// All of the slices go in, not only the ones the pattern uses, because the
  /// point of taking the parts somewhere else is to rearrange them again.
  static List<ExportedSample> _chopSamples(Beat beat, AudioClip breakClip) {
    final samples = <ExportedSample>[];
    final count = beat.sliceCount;

    // Position is the mapping, so nothing is ever skipped: a slice that came
    // out empty still takes its place in the list, or every note after it in
    // the MIDI would point at the wrong sample.
    for (var index = 0; index < count; index++) {
      samples.add(
        ExportedSample(
          fileName: _numbered(index, 'slice-${_pad(index + 1)}'),
          note: baseNote + index,
          label: 'slice ${index + 1}',
          clip: sliceOf(breakClip, index, count),
        ),
      );
    }

    // Reverse, pitch down and half speed change the audio, so each one the
    // pattern actually uses becomes a file of its own. Retrigger does not: it
    // is the head of the slice fired four times, which is four notes.
    final variants = _variantsUsedBy(beat);
    for (var i = 0; i < variants.length; i++) {
      final variant = variants[i];
      samples.add(
        ExportedSample(
          fileName: _numbered(
            count + i,
            'slice-${_pad(variant.slice + 1)}-${variant.mod.code}',
          ),
          note: baseNote + count + i,
          label: 'slice ${variant.slice + 1} ${_exportName(variant.mod)}',
          clip: playedAt(
            sliceOf(breakClip, variant.slice, count),
            variant.mod.rate,
          ),
        ),
      );
    }
    return samples;
  }

  /// The kit, with each slot's volume and pitch baked in.
  ///
  /// Baked rather than left to the user to dial back in, because those settings
  /// belong to the Beat: an export that needs eight numbers copied across by
  /// hand before it sounds right has not exported the Beat.
  static List<ExportedSample> _kitSamples(Beat beat, List<AudioClip> kitClips) {
    final samples = <ExportedSample>[];
    for (var slot = 0; slot < kitClips.length; slot++) {
      final settings = beat.slot(slot);
      samples.add(
        ExportedSample(
          fileName: _numbered(slot, 'slot-${_pad(slot + 1)}'),
          note: baseNote + slot,
          label: 'slot ${slot + 1}',
          clip: scaled(
            playedAt(kitClips[slot], settings.rate),
            settings.volume,
          ),
        ),
      );
    }
    return samples;
  }

  // --- Notes ---------------------------------------------------------------

  static List<MidiNote> _chopNotes(Beat beat, List<ExportedSample> samples) {
    final variants = _variantsUsedBy(beat).toList();
    final notes = <MidiNote>[];

    for (var step = 0; step < beat.stepCount; step++) {
      final cell = beat.chop.stepAt(step);
      if (cell == null) continue;
      final tick = _tickOf(step, beat);

      final note = cell.mod == StepMod.retrigger || cell.mod == StepMod.none
          ? baseNote + cell.slice
          : baseNote +
                beat.sliceCount +
                variants.indexWhere(
                  (v) => v.slice == cell.slice && v.mod == cell.mod,
                );
      if (note < 0 || note - baseNote >= samples.length) continue;

      if (cell.mod == StepMod.retrigger) {
        // Four hits inside the step, which is four notes rather than a fifth
        // sample. A Kong pad chokes itself, so they truncate each other there
        // exactly as they do here.
        final spacing = ticksPerStep ~/ StepMod.retrigger.retriggers;
        for (var hit = 0; hit < StepMod.retrigger.retriggers; hit++) {
          notes.add(
            MidiNote(
              tick: tick + hit * spacing,
              durationTicks: spacing,
              note: note,
              velocity: 100,
            ),
          );
        }
      } else {
        notes.add(
          MidiNote(
            tick: tick,
            durationTicks: ticksPerStep,
            note: note,
            velocity: 100,
          ),
        );
      }
    }
    return notes;
  }

  static List<MidiNote> _kitNotes(Beat beat) {
    final notes = <MidiNote>[];
    for (var slot = 0; slot < kitSlotCount; slot++) {
      for (var step = 0; step < beat.stepCount; step++) {
        final velocity = beat.kit.velocityAt(slot, step);
        if (velocity == null) continue;
        notes.add(
          MidiNote(
            tick: _tickOf(step, beat),
            durationTicks: ticksPerStep,
            note: baseNote + slot,
            // The three levels the grid has, as the three velocities they are.
            velocity: (velocity.gain * 127).round(),
          ),
        );
      }
    }
    return notes;
  }

  /// The sub lane as real notes.
  ///
  /// A tie holds the note rather than restarting it, which is what the tie
  /// means on the lane, so a run of tied cells comes out as one long note. A
  /// tie that also carries a pitch is a glide, and glide is a property of the
  /// patch rather than of the file, so it lands as the next note starting where
  /// the last one ended.
  static List<MidiNote> _subNotes(Beat beat) {
    final notes = <MidiNote>[];
    int? openTick;
    int? openNote;
    var openVelocity = 88;

    void close(int atTick) {
      if (openTick == null || openNote == null) return;
      notes.add(
        MidiNote(
          tick: openTick!,
          durationTicks: atTick - openTick!,
          note: openNote!,
          velocity: openVelocity,
        ),
      );
      openTick = null;
      openNote = null;
    }

    for (var step = 0; step < beat.stepCount; step++) {
      final cell = beat.sub.stepAt(step);
      final tick = _tickOf(step, beat);
      if (cell.semitone != null) {
        close(tick);
        openTick = tick;
        openNote = (beat.subRootMidi + cell.semitone!).clamp(0, 127);
        // An accent opens the filter and lifts the level, which on the way out
        // is simply a louder note.
        openVelocity = cell.accent ? 112 : 88;
      } else if (!cell.tie) {
        close(tick);
      }
      // A tie with no pitch holds whatever is open: nothing to do but let the
      // note run on.
    }
    close(_tickOf(beat.stepCount, beat));
    return notes;
  }

  /// Where a step lands, swing included.
  ///
  /// Swing pushes the odd sixteenths late and leaves the even ones alone, which
  /// is the same thing the mixer does, so the MIDI and the WAV of one Beat land
  /// on the same grid.
  static int _tickOf(int step, Beat beat) {
    final swing = step.isOdd
        ? (beat.swingOffsetFraction * ticksPerStep).round()
        : 0;
    return step * ticksPerStep + swing;
  }

  /// The (slice, modifier) pairs in the pattern that need their own audio, in a
  /// stable order so that the mapping is the same every export.
  static List<_Variant> _variantsUsedBy(Beat beat) {
    final seen = <_Variant>[];
    for (var step = 0; step < beat.stepCount; step++) {
      final cell = beat.chop.stepAt(step);
      if (cell == null) continue;
      if (cell.mod == StepMod.none || cell.mod == StepMod.retrigger) continue;
      final variant = _Variant(cell.slice, cell.mod);
      if (!seen.contains(variant)) seen.add(variant);
    }
    seen.sort((a, b) {
      final bySlice = a.slice.compareTo(b.slice);
      return bySlice != 0 ? bySlice : a.mod.index.compareTo(b.mod.index);
    });
    return seen;
  }

  // --- The note in the box -------------------------------------------------

  static String readme({
    required Beat beat,
    required List<ExportedSample> samples,
    required double bpm,
    required String stem,
  }) {
    final lines = StringBuffer()
      ..writeln('junglEngine export: ${beat.name}')
      ..writeln('')
      ..writeln(
        '${beat.bars} bar${beat.bars == 1 ? '' : 's'} at '
        '${bpm.round()} BPM, swing ${beat.swingPercent}%, '
        '${beat.isKit ? 'Kit' : 'Chop'} machine.',
      )
      ..writeln('')
      ..writeln('  $stem.mid    the pattern')
      ..writeln('  samples/          the audio it plays')
      ..writeln('')
      ..writeln('Reason NN-XT: select every file in samples/ and drop them on')
      ..writeln(
        'the sampler. They map up the keyboard from '
        '${noteName(baseNote)} in file order,',
      )
      ..writeln('which is the order the MIDI expects.')
      ..writeln('')
      ..writeln(
        'Reason Kong: drop sample n on pad n. Pad 1 is '
        '${noteName(baseNote)}.',
      )
      ..writeln('')
      ..writeln(
        'Anything else: map the files in order from MIDI note '
        '$baseNote.',
      )
      ..writeln('')
      ..writeln('MAPPING')
      ..writeln('');
    for (final sample in samples) {
      lines.writeln(
        '  ${sample.note.toString().padLeft(3)}  '
        '${noteName(sample.note).padRight(4)}  '
        '${sample.fileName.padRight(28)}  ${sample.label}',
      );
    }
    if (!beat.sub.isEmpty) {
      lines
        ..writeln('')
        ..writeln(
          'The sub lane is on its own MIDI channel '
          '(${subChannel + 1}) as real pitches,',
        )
        ..writeln(
          'root ${noteName(beat.subRootMidi)}. It is a bass part, not '
          'a sample map: play it with',
        )
        ..writeln('whatever sub you like. Accents are the louder notes.');
    }
    lines
      ..writeln('')
      ..writeln(
        'Slot volume and pitch, and every step modifier that changes '
        'the audio,',
      )
      ..writeln(
        'are already in the files. What you drop in is what the phone '
        'played.',
      );
    return lines.toString();
  }

  static String _numbered(int index, String name) =>
      '${_pad(index + 1)}_$name.wav';

  static String _pad(int value) => value.toString().padLeft(2, '0');
}

class _Variant {
  const _Variant(this.slice, this.mod);

  final int slice;
  final StepMod mod;

  @override
  bool operator ==(Object other) =>
      other is _Variant && other.slice == slice && other.mod == mod;

  @override
  int get hashCode => Object.hash(slice, mod);
}

/// One slice of a break, cut the same way the mixer cuts it.
AudioClip sliceOf(AudioClip clip, int index, int count) {
  final total = clip.frames;
  if (count <= 0 || index < 0 || index >= count) {
    return AudioClip.silent(frames: 1, sampleRate: clip.sampleRate);
  }
  final start = (index * total / count).round();
  final end = ((index + 1) * total / count).round().clamp(0, total);
  if (end <= start) {
    return AudioClip.silent(frames: 1, sampleRate: clip.sampleRate);
  }
  return AudioClip(
    samples: clip.samples.sublist(start * clip.channels, end * clip.channels),
    channels: clip.channels,
    sampleRate: clip.sampleRate,
  );
}

/// A clip read at [rate], backwards when [rate] is negative.
///
/// The same arithmetic the mixer does per sample, done once into a file, so a
/// reversed or half speed step arrives as audio rather than as an instruction
/// the sampler has no way to follow.
AudioClip playedAt(AudioClip clip, double rate) {
  final speed = rate.abs();
  if (speed <= 0) {
    return AudioClip.silent(frames: 1, sampleRate: clip.sampleRate);
  }
  final reverse = rate < 0;
  if (speed == 1.0 && !reverse) return clip;

  final frames = (clip.frames / speed).floor();
  if (frames < 1) {
    return AudioClip.silent(frames: 1, sampleRate: clip.sampleRate);
  }

  final out = Float32List(frames * clip.channels);
  for (var f = 0; f < frames; f++) {
    final source = reverse ? (clip.frames - 1) - f * speed : f * speed;
    final i0 = source.floor().clamp(0, clip.frames - 1);
    final i1 = (i0 + 1).clamp(0, clip.frames - 1);
    final t = source - i0;
    for (var c = 0; c < clip.channels; c++) {
      final a = clip.samples[i0 * clip.channels + c];
      final b = clip.samples[i1 * clip.channels + c];
      out[f * clip.channels + c] = a + (b - a) * t;
    }
  }
  return AudioClip(
    samples: out,
    channels: clip.channels,
    sampleRate: clip.sampleRate,
  );
}

/// A clip at a different level, for baking a Kit slot's volume into its file.
AudioClip scaled(AudioClip clip, double gain) {
  if ((gain - 1).abs() < 0.0001) return clip;
  final out = Float32List(clip.samples.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = clip.samples[i] * gain;
  }
  return AudioClip(
    samples: out,
    channels: clip.channels,
    sampleRate: clip.sampleRate,
  );
}
