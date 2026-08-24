// The A/B for M4: how long each mixer takes to render the same music.
//
//   dart run tool/engine_bench.dart              # JIT, quick
//   dart compile exe tool/engine_bench.dart -o build/engine_bench
//   ./build/engine_bench                         # AOT, the honest number
//
// The AOT run is the one to quote. A release build of the app is AOT, and JIT
// Dart on a warm desktop loop flatters itself.
//
// Both mixers render the same arrangement, from the same bundled break and the
// same bundled kit, in 1024 frame blocks, which is the size a device asks for.
// The Rust side runs through `je_bench` so it reads the very bytes this script
// rendered with.
//
// What this measures is CPU per second of audio, which is the battery half of
// the M4 gate. The latency half needs a device and is in docs/M4.md.

import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/audio/wav.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/kit_slot.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/step_mod.dart';
import 'package:junglengine/models/sub_lane.dart';
import 'package:junglengine/models/sub_patch.dart';

const int sampleRate = 44100;
const int blockFrames = 1024;
const double bpm = 174;

/// A minute of audio. Long enough that the arrangement comes round several
/// times and short enough to run between two edits.
const int benchFrames = sampleRate * 60;

const int repeats = 3;

const String breakPath = 'assets/breaks/DnB_full02_loop_170.wav';
const List<String> kitPaths = [
  'assets/kits/hawkstreak/hawkstreak_kick.wav',
  'assets/kits/hawkstreak/hawkstreak_snare.wav',
  'assets/kits/hawkstreak/hawkstreak_rim.wav',
  'assets/kits/hawkstreak/hawkstreak_clap.wav',
  'assets/kits/hawkstreak/hawkstreak_hat_closed.wav',
  'assets/kits/hawkstreak/hawkstreak_hat_open.wav',
  'assets/kits/hawkstreak/hawkstreak_shaker.wav',
  'assets/kits/hawkstreak/hawkstreak_conga.wav',
];

const String rustDir = 'packages/junglengine_engine/rust';

void main(List<String> args) {
  final spec = _benchSpec();

  final dartSeconds = _timeDart(spec);
  final audioSeconds = benchFrames / sampleRate;
  _report('dart', dartSeconds, audioSeconds);

  final rustSeconds = _timeRust(spec);
  if (rustSeconds == null) {
    stdout.writeln(
      '\nrust: not run. Build it with '
      '`cargo build --release --bin je_bench` in $rustDir.',
    );
    return;
  }
  _report('rust', rustSeconds, audioSeconds);
  stdout.writeln(
    '\nrust is ${(dartSeconds / rustSeconds).toStringAsFixed(2)}x '
    'the speed of dart on this machine.',
  );
}

void _report(String name, double seconds, double audioSeconds) {
  final blocks = benchFrames / blockFrames;
  stdout.writeln(
    '$name: ${(seconds * 1000).toStringAsFixed(1)} ms to render '
    '${audioSeconds.toStringAsFixed(0)} s of audio '
    '(${(audioSeconds / seconds).toStringAsFixed(0)}x realtime, '
    '${(seconds * 1e6 / blocks).toStringAsFixed(1)} us per $blockFrames frame block, '
    '${(seconds / audioSeconds * 100).toStringAsFixed(2)}% of one core)',
  );
}

double _timeDart(RenderSpec spec) {
  final block = Float32List(blockFrames * 2);
  var best = double.infinity;
  for (var run = 0; run <= repeats; run++) {
    final renderer = PatternRenderer(spec);
    final watch = Stopwatch()..start();
    var done = 0;
    while (done < benchFrames) {
      final count = math.min(blockFrames, benchFrames - done);
      renderer.render(block, count);
      done += count;
    }
    watch.stop();
    final elapsed = watch.elapsedMicroseconds / 1e6;
    // The first pass is the warm up, whichever runtime this is.
    if (run > 0 && elapsed < best) best = elapsed;
  }
  return best;
}

double? _timeRust(RenderSpec spec) {
  final binary = File('$rustDir/target/release/je_bench');
  if (!binary.existsSync()) return null;

  final work = Directory.systemTemp.createTempSync('junglengine_bench');
  try {
    final breakFile = '${work.path}/break.f32';
    _writeClip(breakFile, spec.breakClip);
    final kits = <String>[];
    for (var i = 0; i < spec.kitClips.length; i++) {
      final path = '${work.path}/kit$i.f32';
      _writeClip(path, spec.kitClips[i]);
      kits.add(path);
    }
    final specFile = '${work.path}/spec.json';
    File(specFile).writeAsStringSync(
      jsonEncode({
        'sampleRate': spec.sampleRate,
        'bpm': spec.bpm,
        'drumGain': spec.drumGain,
        'subGain': spec.subGain,
        'breakPath': breakFile,
        'kitPaths': kits,
        'sections': [
          for (final section in spec.sections)
            {'entryIndex': section.entryIndex, 'beat': section.beat.toJson()},
        ],
      }),
    );

    final run = Process.runSync(binary.path, [
      specFile,
      '$benchFrames',
      '$repeats',
    ]);
    if (run.exitCode != 0) {
      stderr.writeln('je_bench failed:\n${run.stderr}');
      return null;
    }
    final parts = (run.stdout as String).trim().split(' ');
    return double.parse(parts[1]);
  } finally {
    work.deleteSync(recursive: true);
  }
}

void _writeClip(String path, AudioClip clip) {
  final samples = clip.samples;
  File(path).writeAsBytesSync(
    Uint8List.view(samples.buffer, samples.offsetInBytes, samples.lengthInBytes),
  );
}

AudioClip _loadBreak() => decodeWav(File(breakPath).readAsBytesSync())
    .toStereo()
    .resampledTo(sampleRate)
    .normalized();

List<AudioClip> _loadKit() => [
  for (final path in kitPaths)
    decodeWav(File(path).readAsBytesSync()).toStereo().resampledTo(sampleRate),
];

/// A song that works the mixer the way a real one does: both machines, every
/// step modifier, swing, a busy sub lane and a kit with all eight slots in use.
RenderSpec _benchSpec() {
  final breakClip = _loadBreak();
  const mods = [
    StepMod.none,
    StepMod.reverse,
    StepMod.retrigger,
    StepMod.pitchDown,
    StepMod.halfSpeed,
  ];

  SubLane busySub(int bars) => SubLane([
    for (var step = 0; step < bars * 16; step++)
      switch (step % 8) {
        0 => SubStep(semitone: -5 + (step ~/ 8) % 5, accent: step % 32 == 0),
        1 => const SubStep(tie: true),
        3 => const SubStep(semitone: 3, tie: true),
        6 => const SubStep(semitone: -12),
        _ => const SubStep.rest(),
      },
  ]);

  Beat chop(String id, int bars) => Beat(
    id: id,
    name: id,
    bars: bars,
    // The bundled break is four bars, so sixteen divisions a bar is 64.
    sliceCount: 64,
    swing: 0.4,
    subPatch: const SubPatch(
      tone: 0.35,
      cutoff: 0.5,
      drive: 0.35,
      decay: 0.5,
      glide: 0.25,
    ),
    chop: ChopPattern([
      for (var step = 0; step < bars * 16; step++)
        step % 7 == 6
            ? null
            : ChopStep((step * 5 + 11) % 64, mod: mods[step % mods.length]),
    ]),
    sub: busySub(bars),
  );

  Beat kit(String id, int bars) => Beat(
    id: id,
    name: id,
    machineType: MachineType.kit,
    bars: bars,
    swing: 0.25,
    kit: KitPattern([
      for (var slot = 0; slot < kitSlotCount; slot++)
        [
          for (var step = 0; step < bars * 16; step++)
            (step + slot) % (slot + 2) == 0
                ? KitVelocity.values[(step + slot) % 3]
                : null,
        ],
    ]),
    kitSlots: [
      for (var slot = 0; slot < kitSlotCount; slot++)
        KitSlot(volume: 0.45 + slot * 0.06, pitch: (slot % 5) * 3 - 6),
    ],
    sub: busySub(bars),
  );

  return RenderSpec.of(
    breakClip: breakClip,
    kitClips: _loadKit(),
    bpm: bpm,
    sampleRate: sampleRate,
    sections: [
      RenderSection(beat: chop('intro', 2), entryIndex: 0),
      RenderSection(beat: kit('drop', 1), entryIndex: 1),
      RenderSection(beat: chop('roll', 1), entryIndex: 2),
      RenderSection(beat: kit('out', 2), entryIndex: 3),
    ],
  );
}
