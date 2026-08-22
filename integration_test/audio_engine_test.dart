// Runs against the real flutter_soloud engine on a real device.
//
//   flutter test integration_test -d macos
//   flutter test integration_test -d <phone>
//
// Unit tests can prove the renderer produces the right samples. Only this can
// prove the samples reach an output device, because the check is that the
// device consumed them.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/audio/soloud_engine.dart';
import 'package:junglengine/features/library/break_library.dart';
import 'package:junglengine/features/library/kit_library.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/sub_lane.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SoLoudAudioEngine engine;

  setUp(() => engine = SoLoudAudioEngine());
  tearDown(() => engine.shutdown());

  Future<RenderSpec> loadedSpec({double bpm = 170}) async {
    final ref = BreakLibrary.defaultBreak;
    final clip = await BreakLibrary.load(ref, engine.sampleRate);
    // Divisions are per bar, matching what the app opens with.
    final sliceCount = 16 * ref.bars;
    return RenderSpec(
      breakClip: clip,
      beat: Beat(
        id: 'b',
        name: 'A',
        sliceCount: sliceCount,
        chop: ChopPattern.identity(sliceCount: sliceCount),
        sub: SubLane.empty()
            .withStep(0, const SubStep(semitone: -5))
            .withStep(1, const SubStep(tie: true)),
      ),
      bpm: bpm,
      sampleRate: engine.sampleRate,
    );
  }

  testWidgets('initialises against a real audio device', (tester) async {
    await engine.initialize();
    expect(engine.isInitialized, isTrue);
  });

  testWidgets('playback advances, which means the device is consuming audio', (
    tester,
  ) async {
    await engine.initialize();
    await engine.setSpec(await loadedSpec());
    await engine.start();

    expect(engine.transport.value.playing, isTrue);

    // One bar at 170 BPM is 1.41s. Sample well short of that, or the reading
    // wraps back past zero and looks like it never moved.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final early = engine.transport.value;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final later = engine.transport.value;

    expect(
      early.loopPosition,
      greaterThan(0.05),
      reason: 'the playhead never moved, so nothing was consumed',
    );
    expect(
      later.loopPosition,
      greaterThan(early.loopPosition),
      reason: 'the playhead stalled after starting',
    );
    expect(later.step, greaterThan(early.step));
    expect(later.step, lessThan(16));

    await engine.stop();
    expect(engine.transport.value.playing, isFalse);
    expect(engine.transport.value.step, 0);
  });

  testWidgets('the loop wraps rather than running out of audio', (
    tester,
  ) async {
    await engine.initialize();
    await engine.setSpec(await loadedSpec());
    await engine.start();

    // Two bars and change: if the feeder stalled, the playhead would freeze.
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    final first = engine.transport.value;
    expect(first.playing, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    final second = engine.transport.value;
    expect(
      second.loopPosition,
      isNot(closeTo(first.loopPosition, 0.001)),
      reason: 'the playhead stopped moving partway through',
    );

    await engine.stop();
  });

  testWidgets('editing the pattern while playing does not stop the loop', (
    tester,
  ) async {
    final spec = await loadedSpec();
    await engine.initialize();
    await engine.setSpec(spec);
    await engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final before = engine.transport.value.loopPosition;
    await engine.setSpec(
      RenderSpec(
        breakClip: spec.breakClip,
        beat: spec.beat.copyWith(chop: spec.beat.chop.withStep(9, 2)),
        bpm: spec.bpm,
        sampleRate: spec.sampleRate,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(engine.transport.value.playing, isTrue);
    expect(engine.transport.value.loopPosition, isNot(equals(before)));

    await engine.stop();
  });

  testWidgets('tempo changes keep the loop running', (tester) async {
    final spec = await loadedSpec();
    await engine.initialize();
    await engine.setSpec(spec);
    await engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    await engine.setSpec(
      RenderSpec(
        breakClip: spec.breakClip,
        beat: spec.beat,
        bpm: 174,
        sampleRate: spec.sampleRate,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(engine.transport.value.playing, isTrue);

    await engine.stop();
  });

  testWidgets('auditioning a slice does not disturb the transport', (
    tester,
  ) async {
    await engine.initialize();
    await engine.setSpec(await loadedSpec());
    await engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    await engine.auditionSlice(4);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(engine.transport.value.playing, isTrue);
    await engine.stop();
  });

  Future<RenderSpec> loadedKitSpec({double bpm = 170}) async {
    final breakRef = BreakLibrary.defaultBreak;
    final kitRef = KitLibrary.defaultKit;
    return RenderSpec(
      breakClip: await BreakLibrary.load(breakRef, engine.sampleRate),
      kitClips: await KitLibrary.load(kitRef, engine.sampleRate),
      beat: Beat(
        id: 'k',
        name: 'B',
        machineType: MachineType.kit,
        kit: KitPattern.starter(),
        sub: SubLane.empty().withStep(0, const SubStep(semitone: -5)),
      ),
      bpm: bpm,
      sampleRate: engine.sampleRate,
    );
  }

  testWidgets('a Kit Beat plays on a real device too', (tester) async {
    await engine.initialize();
    await engine.setSpec(await loadedKitSpec());
    await engine.start();

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final early = engine.transport.value;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final later = engine.transport.value;

    expect(early.loopPosition, greaterThan(0.05));
    expect(later.loopPosition, greaterThan(early.loopPosition));

    await engine.stop();
  });

  testWidgets('auditioning a kit slot does not disturb the transport', (
    tester,
  ) async {
    await engine.initialize();
    await engine.setSpec(await loadedKitSpec());
    await engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    await engine.auditionKitSlot(0);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(engine.transport.value.playing, isTrue);
    await engine.stop();
  });

  testWidgets('switching machine while playing keeps playing', (tester) async {
    await engine.initialize();
    await engine.setSpec(await loadedSpec());
    await engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // A different Beat, and a different machine: the renderer is rebuilt and
    // the stream restarted underneath a transport that must stay running.
    await engine.setSpec(await loadedKitSpec());
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(engine.transport.value.playing, isTrue);
    expect(engine.transport.value.loopPosition, greaterThan(0.0));

    await engine.stop();
  });

  /// A two card song: a Chop Beat, then a Kit Beat.
  Future<RenderSpec> loadedSongSpec() async {
    final chop = await loadedSpec();
    final kit = await loadedKitSpec();
    return RenderSpec.of(
      breakClip: chop.breakClip,
      kitClips: kit.kitClips,
      sections: [
        RenderSection(beat: chop.beat, entryIndex: 0),
        RenderSection(beat: kit.beat, entryIndex: 1),
      ],
      bpm: chop.bpm,
      sampleRate: engine.sampleRate,
    );
  }

  testWidgets('a song crosses from one machine to the next without a gap', (
    tester,
  ) async {
    await engine.initialize();
    await engine.setSpec(await loadedSongSpec());
    await engine.start();

    // One bar at 170 BPM is 1.41s, so this lands inside the first card.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final first = engine.transport.value;
    expect(first.playing, isTrue);
    expect(first.entryIndex, 0);
    expect(first.beatId, 'b');

    // And this lands inside the second, without the transport having stopped.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    final second = engine.transport.value;
    expect(second.playing, isTrue);
    expect(second.entryIndex, 1);
    expect(second.beatId, 'k');
    expect(second.step, lessThan(16));

    await engine.stop();
    expect(engine.transport.value.entryIndex, -1);
  });

  testWidgets('a card can be added while the song is playing', (tester) async {
    final song = await loadedSongSpec();
    await engine.initialize();
    await engine.setSpec(song);
    await engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final before = engine.transport.value.loopPosition;
    await engine.setSpec(
      RenderSpec.of(
        breakClip: song.breakClip,
        kitClips: song.kitClips,
        sections: [
          ...song.sections,
          RenderSection(beat: song.sections.first.beat, entryIndex: 2),
        ],
        bpm: song.bpm,
        sampleRate: song.sampleRate,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Still in the first card, still moving: adding to the end of an
    // arrangement must not send the playhead back to the top of it.
    final now = engine.transport.value;
    expect(now.playing, isTrue);
    expect(now.entryIndex, 0);
    expect(now.loopPosition, greaterThan(before));

    await engine.stop();
  });
}
