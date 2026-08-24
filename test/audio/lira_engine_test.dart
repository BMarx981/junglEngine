// The Rust engine, driven the way the app drives it: over the FFI boundary,
// through `AudioEngine`, with a real device open.
//
// The parity test next door proves the two mixers render the same samples.
// This proves the rest of stage 2 -- the C ABI, the control thread, the plan
// ring and the shared transport -- by asking `LiraAudioEngine` for the things
// the grid, the sequencer and the exporter ask it for.
//
// Skipped, loudly, when there is no Rust toolchain or no audio output. A
// checkout that has never built the engine, and a machine with nothing to play
// out of, both still have to pass `flutter test`.

import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/engine.dart';
import 'package:junglengine/audio/lira_engine.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/audio/soloud_engine.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/sub_lane.dart';
import 'package:junglengine_engine/junglengine_engine.dart';

const int rate = 44100;
const double bpm = 170;

/// The same bound the mixer parity test uses, and for the same reason: `sin`,
/// `exp` and `pow` are not obliged to give Dart and Rust the same last bit.
const double tolerance = 5e-6;

final Directory rustDir = Directory('packages/junglengine_engine/rust');

void main() {
  final skip = _prepare();

  group('the Rust engine, over the FFI boundary', () {
    late LiraAudioEngine engine;

    setUp(() async {
      engine = LiraAudioEngine(requestedRate: rate);
      await engine.initialize();
    });

    tearDown(() async => engine.shutdown());

    test('opens a device and reports the rate it actually got', () {
      expect(engine.isInitialized, isTrue);
      // Not necessarily the rate that was asked for: a phone runs its own
      // clock and everything the app decodes is resampled to whatever this
      // says.
      expect(engine.sampleRate, greaterThan(8000));
    });

    test('counts the frames in a pass the way the Dart mixer does', () async {
      for (final spec in [_chopSpec(), _songSpec()]) {
        expect(engine.loopFramesFor(spec), PatternRenderer(spec).loopFrames);
      }
    });

    test('exports what the Dart mixer exports, sample for sample', () async {
      final spec = _chopSpec();
      final frames = engine.loopFramesFor(spec);

      final rust = await engine.renderOffline(spec, frames);
      final dart = renderPatternOffline(spec, frames);

      expect(rust.length, dart.length);
      var worst = 0.0;
      var peak = 0.0;
      for (var i = 0; i < dart.length; i++) {
        worst = math.max(worst, (dart[i] - rust[i]).abs());
        peak = math.max(peak, dart[i].abs());
      }
      expect(
        peak,
        greaterThan(0.05),
        reason: 'the fixture rendered silence, so agreement proves nothing',
      );
      expect(worst, lessThan(tolerance), reason: 'worst difference $worst');
    });

    testWidgets('reports the step, the Beat and the card that are sounding', (
      tester,
    ) async {
      final spec = _songSpec();
      await tester.runAsync(() async {
        await engine.setSpec(spec);
        await engine.start();
        // Long enough for the callback to have produced several blocks and
        // published a playhead from inside them.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      final at = engine.transport.value;
      expect(at.playing, isTrue);
      expect(at.stepCount, spec.sections.first.beat.stepCount);
      expect(at.step, inInclusiveRange(0, at.stepCount - 1));
      expect(at.loopPosition, inInclusiveRange(0.0, 1.0));
      // The engine reports a section index; the Beat id is looked up against
      // the plan that index belongs to.
      expect(at.beatId, spec.sections.first.beat.id);
      expect(at.entryIndex, 0);

      await tester.runAsync(() => engine.stop());
      await tester.pump();
      expect(engine.transport.value.playing, isFalse);
      expect(engine.transport.value.step, 0);
    });

    testWidgets('holds a next-bar swap until the bar line', (tester) async {
      final chop = _chopSpec();
      final other = _kitSpec();
      await tester.runAsync(() async {
        await engine.setSpec(chop);
        await engine.start();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        // Published a fraction of a second into a bar that lasts about one and
        // a half, so this is still waiting when it is checked.
        await engine.setSpec(other, when: SpecChange.nextBar);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pump();

      expect(
        engine.transport.value.beatId,
        chop.beat.id,
        reason: 'a queued Beat must not chop the bar that is playing in half',
      );

      await tester.runAsync(() async {
        await engine.cancelQueuedSpec();
        await engine.stop();
      });
      await tester.pump();
    });

    testWidgets('shuts down cleanly while it is still playing', (tester) async {
      await tester.runAsync(() async {
        await engine.setSpec(_chopSpec());
        await engine.start();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        // Not stopped first. Closing the app mid loop is the normal case.
        await engine.shutdown();
      });
      await tester.pump();
      expect(engine.isInitialized, isFalse);
    });

    testWidgets('auditions without touching the transport', (tester) async {
      await tester.runAsync(() async {
        await engine.setSpec(_chopSpec());
        await engine.auditionSlice(3);
        await engine.auditionKitSlot(0);
        await engine.auditionClip(_oneShot(), looping: true);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await engine.stopAuditionClip();
      });
      await tester.pump();
      expect(engine.transport.value.playing, isFalse);
    });
  }, skip: skip);
}

/// Builds the engine and points the loader at it, then checks there is
/// something to play out of. Returns a skip reason, or null.
String? _prepare() {
  final which = Process.runSync('sh', ['-c', 'command -v cargo']);
  if (which.exitCode != 0) {
    return 'no cargo on PATH: the Rust engine was not built';
  }
  final cargo = (which.stdout as String).trim();

  final build = Process.runSync(cargo, [
    'build',
    '--release',
  ], workingDirectory: rustDir.path);
  if (build.exitCode != 0) {
    return 'cargo build failed:\n${build.stderr}';
  }

  final library = File('${rustDir.path}/target/release/$_libraryName');
  if (!library.existsSync()) {
    return 'the engine built but produced no ${library.path}';
  }
  engineLibraryPathOverride = library.absolute.path;

  // A machine with no audio output cannot run any of this, and saying so is
  // better than four failures that look like the engine is broken.
  final probe = engineBindings.newEngine(rate);
  if (probe == nullptr) {
    return 'no audio output device: ${engineBindings.lastError}';
  }
  engineBindings.freeEngine(probe);
  return null;
}

String get _libraryName {
  if (Platform.isMacOS) return 'libjunglengine_engine.dylib';
  if (Platform.isLinux) return 'libjunglengine_engine.so';
  if (Platform.isWindows) return 'junglengine_engine.dll';
  return 'libjunglengine_engine.dylib';
}

/// One break per project, so one break per test: `canQueue` and `canAdopt`
/// both ask whether the new plan reads the same buffer, and a fixture that
/// handed out a fresh clip each time would answer no and quietly test the
/// wrong path.
final AudioClip _theBreak = _sourceBreak();

RenderSpec _chopSpec() => RenderSpec(
  breakClip: _theBreak,
  beat: Beat(
    id: 'chop',
    name: 'Chop',
    sliceCount: 16,
    swing: 0.58,
    chop: ChopPattern([
      for (var step = 0; step < 16; step++)
        step % 5 == 4 ? null : ChopStep((step * 7 + 3) % 16),
    ]),
    sub: SubLane([
      for (var step = 0; step < 16; step++)
        step % 4 == 0 ? SubStep(semitone: step ~/ 4) : const SubStep.rest(),
    ]),
  ),
  bpm: bpm,
  sampleRate: rate,
);

RenderSpec _kitSpec() => RenderSpec(
  breakClip: _theBreak,
  beat: Beat(id: 'kit', name: 'Kit', chop: ChopPattern.empty()),
  bpm: bpm,
  sampleRate: rate,
);

RenderSpec _songSpec() {
  final chop = _chopSpec();
  return RenderSpec.of(
    breakClip: chop.breakClip,
    sections: [
      RenderSection(beat: chop.beat, entryIndex: 0),
      RenderSection(beat: _kitSpec().beat, entryIndex: 1),
    ],
    bpm: bpm,
    sampleRate: rate,
  );
}

/// A deterministic stand in for a break: noise bursts under a tone, so a wrong
/// slice is audible rather than merely wrong.
AudioClip _sourceBreak() {
  final frames = (rate * 4 * 60 / bpm).round();
  final samples = Float32List(frames * 2);
  var state = 12345;
  var phase = 0.0;
  for (var f = 0; f < frames; f++) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    final noise = state / 0x40000000 - 1.0;
    final hit = f * 16 ~/ frames;
    final into = (f * 16 / frames) - hit;
    final env = (1.0 - into) * (1.0 - into);
    phase += (55.0 + hit * 7.0) / rate;
    if (phase >= 1) phase -= 1;
    final tone = 4.0 * (phase - 0.5).abs() - 1.0;
    final value = (0.55 * noise + 0.45 * tone) * env * 0.8;
    samples[f * 2] = value;
    samples[f * 2 + 1] = value * 0.92;
  }
  return AudioClip(samples: samples, channels: 2, sampleRate: rate);
}

AudioClip _oneShot() {
  const frames = 4000;
  final samples = Float32List(frames * 2);
  for (var f = 0; f < frames; f++) {
    final env = math.pow(1.0 - f / frames, 3).toDouble();
    final value = math.sin(2 * math.pi * 90 * f / rate) * env * 0.6;
    samples[f * 2] = value;
    samples[f * 2 + 1] = value;
  }
  return AudioClip(samples: samples, channels: 2, sampleRate: rate);
}
