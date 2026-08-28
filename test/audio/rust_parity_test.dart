// The Rust engine has to produce the same samples as the Dart mixer, because
// M4 swaps one for the other underneath an app whose exports people already
// have. This renders the same specs through both and compares them frame by
// frame, on both paths: playback, block by block, and export, in one call with
// the ring out folded back over the head of the file.
//
// Not a golden file: nothing is committed. The Dart side writes the source
// audio it rendered with and the Rust binary reads exactly those bytes, so
// what is being compared is the two mixers, not two noise generators agreeing.
//
// Skipped, loudly, when there is no Rust toolchain on the machine. `flutter
// test` still has to pass on a checkout that has never built the engine.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/audio/soloud_engine.dart';
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

/// Three seconds. Long enough for a two bar song to come round twice and for
/// the sub's release to run into the next note.
const int renderFrames = sampleRate * 3;

/// What a difference has to stay under to count as the same mixer.
///
/// Not zero: the sub synth's filter coefficients come out of `sin`, `exp` and
/// `pow`, and libm is not obliged to give Dart and Rust the same last bit. A
/// resonant filter carries that difference forward, so this is the honest
/// bound on a quarter of a second of ringing bass, and it is still 100 dB
/// below anything audible.
const double tolerance = 5e-6;

final Directory rustDir = Directory('packages/junglengine_engine/rust');

void main() {
  final cargo = _cargoPath();

  group('the Rust engine renders what the Dart mixer renders', () {
    late File binary;
    late Directory work;

    setUpAll(() {
      final build = Process.runSync(cargo!, [
        'build',
        '--release',
        '--bin',
        'je_render',
      ], workingDirectory: rustDir.path);
      expect(
        build.exitCode,
        0,
        reason: 'cargo build failed:\n${build.stderr}',
      );
      binary = File('${rustDir.path}/target/release/je_render');
      expect(binary.existsSync(), isTrue);
      work = Directory.systemTemp.createTempSync('junglengine_parity');
    });

    tearDownAll(() {
      if (work.existsSync()) work.deleteSync(recursive: true);
    });

    void parity(String name, RenderSpec spec) {
      test(name, () {
        final dart = _renderInDart(spec);
        final rust = _renderInRust(binary, work, name, spec);

        expect(rust.length, dart.length);

        var worst = 0.0;
        var worstAt = -1;
        for (var i = 0; i < dart.length; i++) {
          final diff = (dart[i] - rust[i]).abs();
          if (diff > worst) {
            worst = diff;
            worstAt = i;
          }
        }

        // A fixture that rendered silence would agree with anything.
        var peak = 0.0;
        for (final sample in dart) {
          final level = sample.abs();
          if (level > peak) peak = level;
        }
        expect(
          peak,
          greaterThan(0.05),
          reason: 'the fixture rendered silence, so parity proves nothing',
        );
        expect(
          worst,
          lessThan(tolerance),
          reason: worstAt < 0
              ? 'sample identical'
              : 'worst sample differs by $worst at frame ${worstAt ~/ 2} '
                    '(dart ${dart[worstAt]}, rust ${rust[worstAt]})',
        );
        printOnFailure('$name: worst difference $worst');
      });
    }

    /// Export takes a different route through the same mixer: one call rather
    /// than a block loop, and a tail rendered past the end and folded back over
    /// the start. It has to agree sample for sample too, or moving playback to
    /// Rust quietly forks the mixer in two and an exported file stops being
    /// what was playing.
    void offlineParity(String name, RenderSpec spec) {
      test('$name, exported', () {
        final dart = _renderOfflineInDart(spec);
        final rust = _renderInRust(binary, work, '${name}_offline', spec,
            offline: true);

        expect(rust.length, dart.length);
        var worst = 0.0;
        var worstAt = -1;
        for (var i = 0; i < dart.length; i++) {
          final diff = (dart[i] - rust[i]).abs();
          if (diff > worst) {
            worst = diff;
            worstAt = i;
          }
        }
        expect(
          worst,
          lessThan(tolerance),
          reason: worstAt < 0
              ? 'sample identical'
              : 'worst sample differs by $worst at frame ${worstAt ~/ 2} '
                    '(dart ${dart[worstAt]}, rust ${rust[worstAt]})',
        );
      });
    }

    parity('a chop pattern with every step modifier and swing', _chopSpec());
    parity('a kit pattern with velocities, volumes and pitch', _kitSpec());
    parity('a song running both machines back to back', _songSpec());
    parity('a sub lane of ties, accents and glide', _subSpec());
    parity('the same lane as a Reese', _subSpec(patch: _reesePatch));

    offlineParity('a chop pattern with every step modifier and swing',
        _chopSpec());
    offlineParity('a kit pattern with velocities, volumes and pitch',
        _kitSpec());
    offlineParity('a song running both machines back to back', _songSpec());
    offlineParity('a sub lane of ties, accents and glide', _subSpec());
    offlineParity('the same lane as a Reese', _subSpec(patch: _reesePatch));
  }, skip: cargo == null ? 'no cargo on PATH: the Rust engine was not built' : null);
}

String? _cargoPath() {
  final which = Process.runSync('sh', ['-c', 'command -v cargo']);
  if (which.exitCode != 0) return null;
  final path = (which.stdout as String).trim();
  return path.isEmpty ? null : path;
}

Float32List _renderOfflineInDart(RenderSpec spec) =>
    renderPatternOffline(spec, renderFrames);

Float32List _renderInDart(RenderSpec spec) {
  final renderer = PatternRenderer(spec);
  final out = Float32List(renderFrames * 2);
  final block = Float32List(blockFrames * 2);
  var done = 0;
  while (done < renderFrames) {
    final count = math.min(blockFrames, renderFrames - done);
    renderer.render(block, count);
    out.setRange(done * 2, (done + count) * 2, block);
    done += count;
  }
  return out;
}

Float32List _renderInRust(
  File binary,
  Directory work,
  String name,
  RenderSpec spec, {
  bool offline = false,
}) {
  final slug = name.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final breakPath = '${work.path}/$slug.break.f32';
  _writeClip(breakPath, spec.breakClip);
  final kitPaths = <String>[];
  for (var i = 0; i < spec.kitClips.length; i++) {
    final path = '${work.path}/$slug.kit$i.f32';
    _writeClip(path, spec.kitClips[i]);
    kitPaths.add(path);
  }

  // The engine's own wire format, plus where this fixture's audio was written.
  // Using [RenderSpec.toEngineJson] rather than a second hand rolled encoder
  // is the point: what the parity test compares is what the app actually
  // sends.
  final specPath = '${work.path}/$slug.json';
  File(specPath).writeAsStringSync(
    jsonEncode({
      ...spec.toEngineJson(),
      'breakPath': breakPath,
      'kitPaths': kitPaths,
    }),
  );

  final outPath = '${work.path}/$slug.out.f32';
  final run = Process.runSync(binary.path, [
    specPath,
    '$renderFrames',
    outPath,
    if (offline) '--offline',
  ]);
  expect(run.exitCode, 0, reason: 'je_render failed:\n${run.stderr}');

  final bytes = File(outPath).readAsBytesSync();
  return bytes.buffer.asFloat32List(
    bytes.offsetInBytes,
    bytes.lengthInBytes ~/ 4,
  );
}

void _writeClip(String path, AudioClip clip) {
  final samples = clip.samples;
  File(path).writeAsBytesSync(
    Uint8List.view(samples.buffer, samples.offsetInBytes, samples.lengthInBytes),
  );
}

/// A deterministic stand in for a break: noise bursts under a tone, so every
/// slice sounds different and interpolation has something to interpolate.
/// Anything flat would let a rate error through unnoticed.
AudioClip _sourceBreak({required double bpm, int bars = 1, int seed = 12345}) {
  final frames = (sampleRate * 4 * 60 / bpm * bars).round();
  final samples = Float32List(frames * 2);
  var state = seed;
  var phase = 0.0;
  for (var f = 0; f < frames; f++) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    final noise = state / 0x40000000 - 1.0;
    final hit = f * 16 ~/ frames;
    final into = (f * 16 / frames) - hit;
    final env = (1.0 - into) * (1.0 - into);
    phase += (55.0 + hit * 7.0) / sampleRate;
    if (phase >= 1) phase -= 1;
    final tone = 4.0 * (phase - 0.5).abs() - 1.0;
    final value = (0.55 * noise + 0.45 * tone) * env * 0.8;
    samples[f * 2] = value;
    samples[f * 2 + 1] = value * 0.92;
  }
  return AudioClip(samples: samples, channels: 2, sampleRate: sampleRate);
}

/// Eight one shots of different lengths and shapes, so slot pitch and volume
/// have something to move.
List<AudioClip> _sourceKit() => [
  for (var slot = 0; slot < kitSlotCount; slot++)
    _oneShot(frames: 2000 + slot * 900, seed: 7 + slot * 31, hz: 60.0 + slot * 90),
];

AudioClip _oneShot({
  required int frames,
  required int seed,
  required double hz,
}) {
  final samples = Float32List(frames * 2);
  var state = seed;
  var phase = 0.0;
  for (var f = 0; f < frames; f++) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    final noise = state / 0x40000000 - 1.0;
    final env = math.pow(1.0 - f / frames, 3).toDouble();
    phase += hz / sampleRate;
    if (phase >= 1) phase -= 1;
    final tone = 4.0 * (phase - 0.5).abs() - 1.0;
    samples[f * 2] = (0.4 * noise + 0.6 * tone) * env;
    samples[f * 2 + 1] = (0.35 * noise + 0.65 * tone) * env;
  }
  return AudioClip(samples: samples, channels: 2, sampleRate: sampleRate);
}

SubLane _subLane(List<SubStep> steps) => SubLane(steps);

RenderSpec _chopSpec() {
  const mods = [
    StepMod.none,
    StepMod.reverse,
    StepMod.retrigger,
    StepMod.pitchDown,
    StepMod.halfSpeed,
  ];
  final beat = Beat(
    id: 'chop',
    name: 'Chop',
    sliceCount: 16,
    swing: 0.62,
    subPatch: const SubPatch(
      tone: 0.7,
      cutoff: 0.55,
      drive: 0.45,
      decay: 0.6,
      glide: 0.4,
    ),
    chop: ChopPattern([
      for (var step = 0; step < 16; step++)
        step % 5 == 4
            ? null
            : ChopStep((step * 7 + 3) % 16, mod: mods[step % mods.length]),
    ]),
    sub: _subLane([
      for (var step = 0; step < 16; step++)
        step % 4 == 0
            ? SubStep(semitone: step ~/ 4 - 2, accent: step == 8)
            : (step % 4 == 1
                  ? const SubStep(tie: true)
                  : const SubStep.rest()),
    ]),
  );
  return RenderSpec(
    breakClip: _sourceBreak(bpm: 172),
    beat: beat,
    bpm: 172,
    sampleRate: sampleRate,
  );
}

RenderSpec _kitSpec() {
  final kit = KitPattern([
    for (var slot = 0; slot < kitSlotCount; slot++)
      [
        for (var step = 0; step < 16; step++)
          (step + slot) % (slot + 2) == 0
              ? KitVelocity.values[(step + slot) % 3]
              : null,
      ],
  ]);
  final beat = Beat(
    id: 'kit',
    name: 'Kit',
    machineType: MachineType.kit,
    swing: 0.3,
    kit: kit,
    kitSlots: [
      for (var slot = 0; slot < kitSlotCount; slot++)
        KitSlot(volume: 0.3 + slot * 0.09, pitch: slot * 3 - 9),
    ],
    sub: _subLane([
      for (var step = 0; step < 16; step++)
        step % 8 == 0 ? const SubStep(semitone: -5) : const SubStep.rest(),
    ]),
  );
  return RenderSpec(
    breakClip: _sourceBreak(bpm: 168),
    beat: beat,
    bpm: 168,
    sampleRate: sampleRate,
    kitClips: _sourceKit(),
  );
}

RenderSpec _songSpec() {
  final chop = _chopSpec().beat;
  final kit = _kitSpec().beat;
  return RenderSpec.of(
    breakClip: _sourceBreak(bpm: 174),
    sections: [
      RenderSection(beat: chop, entryIndex: 0),
      RenderSection(beat: kit, entryIndex: 1),
      RenderSection(beat: chop, entryIndex: 0),
    ],
    bpm: 174,
    sampleRate: sampleRate,
    kitClips: _sourceKit(),
  );
}

/// The sub lane on its own, over an empty drum grid, so nothing masks a
/// difference in the synth.
/// Both oscillators well into the saw half of the tone knob and pushed as far
/// apart as the knob goes.
///
/// The default patch leaves detune at 0, where the two oscillators are the same
/// double and any porting mistake in the pair cancels itself out. This is the
/// patch that would catch one: a wrong detune ratio, a PolyBLEP branch that
/// disagrees, or a tone morph split at a different point.
const SubPatch _reesePatch = SubPatch(
  tone: 0.85,
  cutoff: 0.8,
  drive: 0.4,
  decay: 0.9,
  glide: 0.75,
  detune: 1.0,
);

RenderSpec _subSpec({
  SubPatch patch = const SubPatch(
    tone: 0.1,
    cutoff: 0.8,
    drive: 0.9,
    decay: 0.9,
    glide: 0.75,
  ),
}) {
  final beat = Beat(
    id: 'sub',
    name: 'Sub',
    swing: 0,
    subPatch: patch,
    chop: ChopPattern.empty(),
    sub: _subLane(const [
      SubStep(semitone: 0),
      SubStep(tie: true),
      SubStep(semitone: 7, tie: true),
      SubStep.rest(),
      SubStep(semitone: -3, accent: true),
      SubStep(tie: true),
      SubStep(tie: true),
      SubStep(semitone: 12, tie: true, accent: true),
      SubStep.rest(),
      SubStep(semitone: 5),
      SubStep.rest(),
      SubStep(semitone: -12),
      SubStep(tie: true),
      SubStep(semitone: 3, tie: true),
      SubStep.rest(),
      SubStep(semitone: 0, accent: true),
    ]),
  );
  return RenderSpec(
    breakClip: _sourceBreak(bpm: 160),
    beat: beat,
    bpm: 160,
    sampleRate: sampleRate,
  );
}
