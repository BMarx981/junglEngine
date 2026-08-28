import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/features/library/break_library.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/step_mod.dart';
import 'package:junglengine/models/sub_lane.dart';
import 'package:junglengine/state/studio.dart';

import '../support/fake_engine.dart';

/// Waits for the break to finish loading off the asset bundle.
Future<ProviderContainer> booted(FakeAudioEngine engine) async {
  final container = ProviderContainer.test(
    overrides: [audioEngineProvider.overrideWithValue(engine)],
  );
  container.listen(studioProvider, (_, _) {});
  for (var i = 0; i < 100; i++) {
    if (container.read(studioProvider).isReady) return container;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('studio never became ready: ${container.read(studioProvider).status}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioEngine engine;
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    // Export writes through path_provider, which has no plugin in a test host.
    tempDir = await Directory.systemTemp.createTemp('junglengine-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
    engine = FakeAudioEngine();
    container = await booted(engine);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  StudioController controller() => container.read(studioProvider.notifier);
  StudioState state() => container.read(studioProvider);

  group('boot', () {
    test('opens on the default bundled break at the break tempo', () {
      expect(state().breakRef.id, BreakLibrary.defaultBreak.id);
      expect(state().project.bpm, BreakLibrary.defaultBreak.bpm);
      expect(state().clip, isNotNull);
      expect(state().analysis, isNotNull);
    });

    test('opens at 16 slices per bar', () {
      expect(state().sliceDivision, 16);
      expect(state().beat.sliceCount, 16 * state().breakBars);
    });

    test('starts on the identity pattern, so play is the break itself', () {
      // On a multi bar break the diagonal is its first bar; the grid is one bar.
      for (var step = 0; step < 16; step++) {
        expect(state().beat.chop.sliceAt(step), step);
      }
    });

    test('has one chop beat and an empty song, per the M0 hierarchy', () {
      expect(state().project.beats, hasLength(1));
      expect(state().project.song.isEmpty, isTrue);
    });

    test('hands the engine a spec on boot', () {
      expect(engine.lastSpec, isNotNull);
      expect(engine.lastSpec!.bpm, 170);
    });
  });

  group('grid editing', () {
    test('placing a slice reaches the engine and auditions', () {
      controller().toggleCell(3, 7);
      expect(state().beat.chop.sliceAt(7), 3);
      expect(engine.lastSpec!.beat.chop.sliceAt(7), 3);
      expect(engine.auditioned, contains(3));
    });

    test('tapping the same cell again clears it and does not audition', () {
      controller().toggleCell(3, 7);
      engine.auditioned.clear();
      controller().toggleCell(3, 7);
      expect(state().beat.chop.sliceAt(7), isNull);
      expect(engine.auditioned, isEmpty);
    });

    test('painting the same cell twice only commits once', () {
      controller().paintCell(2, 5);
      engine.auditioned.clear();
      controller().paintCell(2, 5);
      expect(engine.auditioned, isEmpty);
    });

    test('re-slicing drops slices that no longer exist', () {
      final bars = state().breakBars;
      controller().setSliceDivision(32);
      expect(state().beat.sliceCount, 32 * bars);
      controller().toggleCell(32 * bars - 1, 2);

      controller().setSliceDivision(8);
      expect(state().beat.sliceCount, 8 * bars);
      expect(state().sliceDivision, 8);
      expect(state().beat.chop.sliceAt(2), isNull);
      expect(state().analysis!.sliceCount, 8 * bars);
    });

    // A sixteenth has to stay a sixteenth whatever the break's length, or a
    // four bar break gets quarter note slices and cannot be chopped.
    test('divisions are per bar, so 16 is always a sixteenth note', () {
      controller().setSliceDivision(16);
      final clip = state().clip!;
      final sliceSeconds =
          clip.frames / clip.sampleRate / state().beat.sliceCount;
      final sixteenth = 60 / state().project.bpm / 4;
      expect(sliceSeconds, closeTo(sixteenth, 1e-4));
    });
  });

  group('scramble and undo', () {
    test('scramble changes the bar and can be undone', () {
      final before = List.of(state().beat.chop.steps);
      controller().scramble();
      expect(state().beat.chop.steps, isNot(equals(before)));
      expect(state().canUndo, isTrue);

      controller().undo();
      expect(state().beat.chop.steps, equals(before));
      expect(state().canUndo, isFalse);
    });

    test('undo walks back through several scrambles', () {
      final start = List.of(state().beat.chop.steps);
      controller().scramble();
      controller().scramble();
      controller().scramble();
      controller().undo();
      controller().undo();
      controller().undo();
      expect(state().beat.chop.steps, equals(start));
    });

    test('ordinary edits are not undo steps', () {
      controller().toggleCell(1, 1);
      expect(state().canUndo, isFalse);
    });

    test('clearing the grid is undoable', () {
      controller().clearPattern();
      expect(state().beat.chop.isEmpty, isTrue);
      controller().undo();
      expect(state().beat.chop.isEmpty, isFalse);
    });

    test('undo on an empty stack does nothing', () {
      final before = List.of(state().beat.chop.steps);
      controller().undo();
      expect(state().beat.chop.steps, equals(before));
    });
  });

  group('sub lane', () {
    test('setting and clearing a pitch', () {
      controller().setSubStep(4, -5);
      expect(state().beat.sub.stepAt(4).semitone, -5);
      controller().setSubStep(4, null);
      expect(
        state().beat.sub.stepAt(4),
        isA<SubStep>().having((s) => s.isRest, 'isRest', true),
      );
    });

    test('a tie survives a pitch change on the same cell', () {
      controller().toggleTie(6);
      controller().setSubStep(6, 3);
      expect(state().beat.sub.stepAt(6).tie, isTrue);
      expect(state().beat.sub.stepAt(6).semitone, 3);
    });

    test('synth parameters reach the engine', () {
      controller().setSubParameter(1, 0.9);
      expect(engine.lastSpec!.beat.subPatch.cutoff, closeTo(0.9, 1e-9));
    });
  });

  group('transport', () {
    test('play and stop go through the engine', () async {
      await controller().togglePlay();
      expect(engine.startCount, 1);
      await controller().togglePlay();
      expect(engine.stopCount, 1);
    });

    test('bpm is clamped and pushed to the engine', () {
      controller().setBpm(174);
      expect(engine.lastSpec!.bpm, 174);
      controller().setBpm(9000);
      expect(state().project.bpm, StudioController.maxBpm);
      controller().setBpm(1);
      expect(state().project.bpm, StudioController.minBpm);
    });
  });

  group('export', () {
    test('writes a wav named after the tempo and length', () async {
      controller().setBpm(174);
      controller().setExportRepeats(4);
      final result = await controller().exportWav();

      expect(result, isNotNull);
      expect(result!.fileName, 'junglengine-a-174bpm-4bar.wav');
      expect(result.bars, 4);
      expect(await result.file.length(), greaterThan(44));
      expect(
        result.duration.inMilliseconds,
        closeTo(4 * 4 * 60 / 174 * 1000, 20),
      );
      await result.file.delete();
    });

    test('song mode renders the whole arrangement once', () async {
      controller().addToSong();
      controller().addBeat(MachineType.chop, 2);
      controller().addToSong();
      controller().setSongRepeats(0, 3);
      controller().setExportMode(ExportMode.song);

      final result = await controller().exportWav();
      expect(result, isNotNull);
      // Three passes of a one bar Beat, then one of a two bar Beat.
      expect(result!.bars, 5);
      expect(result.fileName, contains('5bar'));
      expect(
        result.duration.inMilliseconds,
        closeTo(5 * 4 * 60 / state().project.bpm * 1000, 30),
      );
      await result.file.delete();
    });

    test('song mode with nothing arranged renders nothing', () async {
      controller().setExportMode(ExportMode.song);
      expect(await controller().exportWav(), isNull);
      expect(state().exporting, isFalse);
    });
  });

  group('swing', () {
    test('is per Beat and reaches the engine', () {
      controller().setSwing(0.6);
      expect(engine.lastSpec!.beat.swing, closeTo(0.6, 1e-9));

      controller().addBeat(MachineType.chop, 1);
      expect(state().beat.swing, 0);
      expect(state().project.beatById('beat-1')!.swing, closeTo(0.6, 1e-9));
    });

    test('clamps to straight and full shuffle', () {
      controller().setSwing(-1);
      expect(state().beat.swing, 0);
      controller().setSwing(5);
      expect(state().beat.swing, 1);
      expect(state().beat.swingPercent, 75);
    });
  });

  group('step modifiers', () {
    test('a modifier lands on the step and reaches the engine', () {
      controller().toggleCell(4, 2);
      controller().setStepMod(2, StepMod.reverse);
      expect(engine.lastSpec!.beat.chop.modAt(2), StepMod.reverse);
      expect(engine.lastSpec!.beat.chop.sliceAt(2), 4);
    });

    test('an empty step has nothing to modify', () {
      controller().clearStep(3);
      controller().setStepMod(3, StepMod.retrigger);
      expect(state().beat.chop.stepAt(3), isNull);
    });

    test('a Kit Beat has no slices to modify', () {
      controller().addBeat(MachineType.kit, 1);
      controller().setStepMod(0, StepMod.reverse);
      expect(state().beat.chop.isEmpty, isTrue);
    });

    test('modifiers survive a save and load', () async {
      controller().toggleCell(5, 6);
      controller().setStepMod(6, StepMod.halfSpeed);
      await controller().flushSave();

      container.dispose();
      container = await booted(FakeAudioEngine());
      final beat = container.read(studioProvider).beat;
      expect(beat.chop.sliceAt(6), 5);
      expect(beat.chop.modAt(6), StepMod.halfSpeed);
    });
  });

  group('sub accent', () {
    test('accents a note and leaves a rest alone', () {
      controller().setSubStep(2, -5);
      controller().toggleAccent(2);
      expect(engine.lastSpec!.beat.sub.stepAt(2).accent, isTrue);

      controller().toggleAccent(9);
      expect(state().beat.sub.stepAt(9).accent, isFalse);
    });

    test('toggles back off', () {
      controller().setSubStep(2, -5);
      controller().toggleAccent(2);
      controller().toggleAccent(2);
      expect(state().beat.sub.stepAt(2).accent, isFalse);
    });
  });

  group('song', () {
    test('starts empty and on the grid', () {
      expect(state().song.isEmpty, isTrue);
      expect(state().view, StudioView.pattern);
      expect(state().playsSong, isFalse);
    });

    test('adding the open Beat builds the arrangement', () {
      controller().addToSong();
      controller().addBeat(MachineType.kit, 2);
      controller().addToSong();

      expect(state().song.length, 2);
      expect(state().song.entries.first.beatId, 'beat-1');
      expect(state().project.songBars, 3);
    });

    test('the Song view plays the arrangement, not the open Beat', () {
      controller().addToSong();
      controller().setSongRepeats(0, 3);
      controller().setView(StudioView.song);

      final spec = engine.lastSpec!;
      expect(spec.isSong, isTrue);
      expect(spec.sections, hasLength(3));
      expect(spec.sections.first.entryIndex, 0);
      expect(spec.bars, 3);
    });

    test('an empty song still loops what is open', () {
      controller().setView(StudioView.song);
      expect(state().playsSong, isFalse);
      expect(engine.lastSpec!.isSong, isFalse);
      expect(engine.lastSpec!.sections, hasLength(1));
    });

    test('cards can be reordered, repeated and removed', () {
      controller().addToSong();
      controller().addBeat(MachineType.chop, 1);
      controller().addToSong();

      controller().moveSongEntry(0, 1);
      expect(state().song.entries.first.beatId, 'beat-2');

      controller().setSongRepeats(0, 4);
      expect(state().song.entries.first.repeats, 4);

      controller().removeSongEntry(0);
      expect(state().song.length, 1);
      expect(state().song.entries.single.beatId, 'beat-1');
    });

    test('a Beat dropped from the bank lands where it was dropped', () {
      controller().setView(StudioView.song);
      controller().addToSong();
      controller().addBeat(MachineType.chop, 1);
      controller().addToSong();

      controller().insertIntoSong('beat-2', 0);
      expect(state().song.entries.map((e) => e.beatId), [
        'beat-2',
        'beat-1',
        'beat-2',
      ]);

      // Past the end is an append, not a refusal: a drop below the last card
      // is the commonest one there is.
      controller().insertIntoSong('beat-1', 99);
      expect(state().song.entries.last.beatId, 'beat-1');
      expect(engine.lastSpec!.sections, hasLength(4));

      // A Beat that is not in the project is not a card.
      controller().insertIntoSong('beat-nope', 0);
      expect(state().song.length, 4);
    });

    test('deleting a Beat takes its cards with it', () {
      controller().addToSong();
      controller().addBeat(MachineType.kit, 1);
      controller().addToSong();
      expect(state().song.length, 2);

      controller().deleteBeat('beat-1');
      expect(state().song.length, 1);
      expect(state().song.entries.single.beatId, 'beat-2');
    });

    test('tapping a card opens that Beat on the grid', () {
      controller().addBeat(MachineType.kit, 1);
      controller().addToSong();
      controller().selectBeat('beat-1');
      controller().setView(StudioView.song);

      controller().openBeatFromSong('beat-2');
      expect(state().activeBeatId, 'beat-2');
      expect(state().view, StudioView.pattern);
    });

    test('the arrangement survives a save and load', () async {
      controller().addToSong();
      controller().setSongRepeats(0, 6);
      await controller().flushSave();

      container.dispose();
      container = await booted(FakeAudioEngine());
      final song = container.read(studioProvider).song;
      expect(song.entries.single.beatId, 'beat-1');
      expect(song.entries.single.repeats, 6);
    });
  });

  group('project library', () {
    test('switching break re-slices at the same division per bar', () async {
      controller().setSliceDivision(32);
      expect(state().beat.sliceCount, 32 * state().breakBars);

      await controller().setBreak('hawkstreak-amenish-170');
      expect(state().breakRef.bars, 1);
      expect(state().beat.sliceCount, 32);
      expect(state().sliceDivision, 32);
      expect(engine.lastSpec!.beat.sliceCount, 32);
    });

    test('switching break keeps the patterns it can', () async {
      controller().toggleCell(3, 1);
      await controller().setBreak('hawkstreak-roller-170');
      expect(state().beat.chop.sliceAt(1), 3);
      // Two bars at 16 per bar.
      expect(state().beat.sliceCount, 32);
    });

    test('switching kit keeps the Beat settings', () async {
      controller().addBeat(MachineType.kit, 1);
      controller().setSlotPitch(0, -4);
      await controller().setKit('hawkstreak-02');

      expect(state().kitRef.id, 'hawkstreak-02');
      expect(state().kitClips, hasLength(kitSlotCount));
      expect(state().beat.slot(0).pitch, -4);
      expect(engine.lastSpec!.kitClips, hasLength(kitSlotCount));
    });

    test('the chosen break and kit come back after a restart', () async {
      await controller().setBreak('hawkstreak-steppa-170');
      await controller().setKit('hawkstreak-02');
      await controller().flushSave();

      container.dispose();
      container = await booted(FakeAudioEngine());
      final restored = container.read(studioProvider);
      expect(restored.breakRef.id, 'hawkstreak-steppa-170');
      expect(restored.kitRef.id, 'hawkstreak-02');
    });
  });

  group('beat bank', () {
    test('a new Chop Beat opens on the break itself', () {
      controller().addBeat(MachineType.chop, 1);
      expect(state().project.beats, hasLength(2));
      expect(state().beat.machineType, MachineType.chop);
      for (var step = 0; step < 16; step++) {
        expect(state().beat.chop.sliceAt(step), step);
      }
    });

    test('a new Kit Beat opens on a groove, not on silence', () {
      controller().addBeat(MachineType.kit, 1);
      expect(state().beat.machineType, MachineType.kit);
      expect(state().beat.kit.isEmpty, isFalse);
      expect(engine.lastSpec!.beat.isKit, isTrue);
    });

    test('a Beat is created at the length asked for', () {
      controller().addBeat(MachineType.kit, 4);
      expect(state().beat.bars, 4);
      expect(state().beat.stepCount, 64);
      expect(state().beat.kit.stepCount, 64);
      expect(state().beat.sub.steps, hasLength(64));
    });

    test('duplicate copies the open Beat, opens it, and puts it alongside', () {
      controller().toggleCell(3, 7);
      controller().addBeat(MachineType.kit, 1);
      controller().selectBeat('beat-1');

      controller().duplicateActiveBeat();
      final copy = state().beat;
      expect(copy.id, isNot('beat-1'));
      expect(copy.chop.sliceAt(7), 3);
      expect(state().project.beats.map((b) => b.id).toList(), [
        'beat-1',
        copy.id,
        'beat-2',
      ]);
    });

    test('editing a duplicate leaves the original alone', () {
      controller().duplicateActiveBeat();
      // Step 2 starts on slice 2 (the identity), so this is a real change.
      controller().toggleCell(9, 2);
      expect(state().beat.chop.sliceAt(2), 9);
      expect(state().project.beatById('beat-1')!.chop.sliceAt(2), 2);
    });

    test('switching Beats hands the engine that Beat', () {
      controller().addBeat(MachineType.kit, 2);
      final kitId = state().activeBeatId;
      controller().selectBeat('beat-1');
      expect(engine.lastSpec!.beat.id, 'beat-1');
      controller().selectBeat(kitId);
      expect(engine.lastSpec!.beat.id, kitId);
      expect(engine.lastSpec!.beat.bars, 2);
    });

    test('deleting the open Beat opens one of the others', () {
      controller().addBeat(MachineType.kit, 1);
      final kitId = state().activeBeatId;
      controller().deleteBeat(kitId);
      expect(state().project.beatById(kitId), isNull);
      expect(state().activeBeatId, 'beat-1');
      expect(engine.lastSpec!.beat.id, 'beat-1');
    });

    test('deleting a Beat you are not on leaves you where you are', () {
      controller().addBeat(MachineType.kit, 1);
      final kitId = state().activeBeatId;
      controller().deleteBeat('beat-1');
      expect(state().activeBeatId, kitId);
    });

    test('the last Beat cannot be deleted', () {
      controller().deleteBeat('beat-1');
      expect(state().project.beats, hasLength(1));
      expect(state().activeBeatId, 'beat-1');
    });
  });

  group('kit machine', () {
    setUp(() => controller().addBeat(MachineType.kit, 1));

    test('tapping a cell places a hit and auditions the slot', () {
      controller().cycleKitCell(2, 3);
      expect(state().beat.kit.velocityAt(2, 3), KitVelocity.hard);
      expect(engine.lastSpec!.beat.kit.velocityAt(2, 3), KitVelocity.hard);
      expect(engine.auditionedSlots, contains(2));
    });

    test('tapping again walks the level down and then clears', () {
      controller().cycleKitCell(2, 3);
      controller().cycleKitCell(2, 3);
      expect(state().beat.kit.velocityAt(2, 3), KitVelocity.medium);
      controller().cycleKitCell(2, 3);
      expect(state().beat.kit.velocityAt(2, 3), KitVelocity.soft);
      controller().cycleKitCell(2, 3);
      expect(state().beat.kit.velocityAt(2, 3), isNull);
    });

    test('the preview follows the level the tap wrote, down and up', () {
      // The bug this locks out: every tap previewed at full, so walking a hit
      // down to a ghost sounded identical to placing it.
      for (final expected in [
        KitVelocity.hard,
        KitVelocity.medium,
        KitVelocity.soft,
      ]) {
        controller().cycleKitCell(2, 3);
        expect(engine.auditionedKitTaps.last.velocity, expected);
      }
      // Tapping it off is silent, so the run above is all there was.
      controller().cycleKitCell(2, 3);
      expect(engine.auditionedKitTaps, hasLength(3));

      controller().paintKitCell(5, 0, KitVelocity.soft);
      expect(engine.auditionedKitTaps.last.velocity, KitVelocity.soft);
    });

    test('a pad tap has no velocity on it, so it sounds full', () {
      controller().auditionKitSlot(4);
      expect(engine.auditionedKitTaps.last, (slot: 4, velocity: null));
    });

    test('painting writes one level across a run, and can erase', () {
      for (var step = 0; step < 4; step++) {
        controller().paintKitCell(6, step, KitVelocity.soft);
      }
      for (var step = 0; step < 4; step++) {
        expect(state().beat.kit.velocityAt(6, step), KitVelocity.soft);
      }
      engine.auditionedSlots.clear();
      for (var step = 0; step < 4; step++) {
        controller().paintKitCell(6, step, null);
      }
      expect(state().beat.kit.slotIsEmpty(6), isTrue);
      // Erasing is silent: nothing was placed to hear.
      expect(engine.auditionedSlots, isEmpty);
    });

    test('slot volume and pitch reach the engine', () {
      controller().setSlotVolume(0, 0.4);
      controller().setSlotPitch(0, -5);
      expect(engine.lastSpec!.beat.slot(0).volume, closeTo(0.4, 1e-9));
      expect(engine.lastSpec!.beat.slot(0).pitch, -5);
      expect(engine.auditionedSlots, contains(0));
    });

    test('slot settings belong to the Beat, not the project', () {
      controller().setSlotPitch(0, 7);
      controller().selectBeat('beat-1');
      controller().addBeat(MachineType.kit, 1);
      expect(state().beat.slot(0).pitch, 0);
    });

    test('clear empties the kit grid and leaves the sub lane alone', () {
      controller().setSubStep(0, -5);
      controller().clearPattern();
      expect(state().beat.kit.isEmpty, isTrue);
      expect(state().beat.sub.stepAt(0).semitone, -5);
      controller().undo();
      expect(state().beat.kit.isEmpty, isFalse);
    });

    test('scramble does nothing on a Kit Beat', () {
      final before = state().beat.kit.toJson();
      controller().scramble();
      expect(state().beat.kit.toJson(), before);
      expect(state().canUndo, isFalse);
    });

    test('re-slicing does nothing on a Kit Beat', () {
      final sliceCount = state().beat.sliceCount;
      controller().setSliceDivision(32);
      expect(state().beat.sliceCount, sliceCount);
    });
  });

  group('queued Beat switch', () {
    /// Adds a second Beat and goes back to the first, so there is something to
    /// switch to. Returns the new Beat's id.
    String secondBeat() {
      controller().addBeat(MachineType.chop, 1);
      final id = state().activeBeatId;
      controller().selectBeat('beat-1');
      return id;
    }

    test('stopped, a Beat opens the moment it is chosen', () {
      final other = secondBeat();
      controller().selectBeat(other);
      expect(state().activeBeatId, other);
      expect(state().pendingBeatId, isNull);
      expect(engine.lastSpec!.beat.id, other);
    });

    test(
      'playing, the Beat waits for the bar and the grid waits with it',
      () async {
        final other = secondBeat();
        await controller().togglePlay();
        controller().selectBeat(other);

        // Nothing has moved on screen or at the output: the bar is still running.
        expect(state().pendingBeatId, other);
        expect(state().activeBeatId, 'beat-1');
        expect(engine.lastSpec!.beat.id, 'beat-1');
        expect(engine.queuedSpec!.beat.id, other);
      },
    );

    test('the grid follows the bar line, not the tap', () async {
      final other = secondBeat();
      await controller().togglePlay();
      controller().selectBeat(other);
      engine.landQueuedSpec();

      expect(state().activeBeatId, other);
      expect(state().pendingBeatId, isNull);
      expect(state().activeBar, 0);
    });

    test('tapping the waiting Beat again calls the switch off', () async {
      final other = secondBeat();
      await controller().togglePlay();
      controller().selectBeat(other);
      controller().selectBeat(other);

      expect(state().pendingBeatId, isNull);
      expect(state().activeBeatId, 'beat-1');
      expect(engine.queuedSpec, isNull);
      expect(engine.cancelledQueues, 1);
    });

    test('an edit while a Beat waits re-describes what is waiting', () async {
      final other = secondBeat();
      await controller().togglePlay();
      controller().selectBeat(other);
      controller().setBpm(174);

      // The tempo drag has to reach the Beat that is about to take over, or the
      // switch would land at the old tempo.
      expect(engine.queuedSpec!.beat.id, other);
      expect(engine.queuedSpec!.bpm, 174);
      expect(engine.lastSpec!.bpm, 174);
    });

    test('stopping opens the Beat that was waiting', () async {
      final other = secondBeat();
      await controller().togglePlay();
      controller().selectBeat(other);
      await controller().togglePlay();

      expect(state().activeBeatId, other);
      expect(state().pendingBeatId, isNull);
      expect(engine.lastSpec!.beat.id, other);
    });

    test(
      'the Song view switches Beats immediately: the song is what plays',
      () async {
        final other = secondBeat();
        controller().addToSong('beat-1');
        controller().setView(StudioView.song);
        await controller().togglePlay();
        controller().selectBeat(other);

        expect(state().activeBeatId, other);
        expect(state().pendingBeatId, isNull);
        expect(engine.queuedSpec, isNull);
      },
    );

    test('making a Beat calls off anything that was waiting', () async {
      final other = secondBeat();
      await controller().togglePlay();
      controller().selectBeat(other);
      controller().addBeat(MachineType.kit, 1);

      expect(state().pendingBeatId, isNull);
      expect(state().activeBeatId, engine.lastSpec!.beat.id);
      expect(engine.queuedSpec, isNull);
    });

    test('deleting the Beat that was waiting calls the switch off', () async {
      final other = secondBeat();
      await controller().togglePlay();
      controller().selectBeat(other);
      controller().deleteBeat(other);

      expect(state().pendingBeatId, isNull);
      expect(state().activeBeatId, 'beat-1');
      expect(engine.queuedSpec, isNull);
    });
  });

  group('bars', () {
    test('paging is clamped to the Beat that is open', () {
      controller().addBeat(MachineType.chop, 4);
      controller().setActiveBar(2);
      expect(state().activeBar, 2);
      expect(state().windowStart, 32);
      controller().setActiveBar(99);
      expect(state().activeBar, 3);
    });

    test('a one bar Beat has nowhere to page to', () {
      controller().setActiveBar(3);
      expect(state().activeBar, 0);
      expect(state().windowStart, 0);
    });

    test('opening another Beat goes back to bar one', () {
      controller().addBeat(MachineType.chop, 4);
      controller().setActiveBar(3);
      controller().selectBeat('beat-1');
      expect(state().activeBar, 0);
    });
  });

  group('save and load', () {
    test('the project comes back after a restart', () async {
      controller().toggleCell(4, 9);
      controller().addBeat(MachineType.kit, 2);
      controller().cycleKitCell(1, 6);
      controller().setSlotPitch(1, -3);
      controller().setBpm(168);
      final kitId = state().activeBeatId;
      await controller().flushSave();

      container.dispose();
      container = await booted(FakeAudioEngine());

      final restored = container.read(studioProvider);
      expect(restored.project.bpm, 168);
      expect(restored.project.beats, hasLength(2));
      expect(restored.project.beatById('beat-1')!.chop.sliceAt(9), 4);
      final kit = restored.project.beatById(kitId)!;
      expect(kit.machineType, MachineType.kit);
      expect(kit.bars, 2);
      expect(kit.kit.velocityAt(1, 6), KitVelocity.hard);
      expect(kit.slot(1).pitch, -3);
    });

    test('a first run with nothing saved opens a new project', () async {
      expect(state().project.beats, hasLength(1));
      expect(state().beat.id, 'beat-1');
    });

    test('editing schedules a save without being asked', () async {
      controller().toggleCell(9, 1);
      // The debounce is shorter than this wait, so an edit that did not write
      // itself would come back missing from the reload below.
      await Future<void>.delayed(const Duration(milliseconds: 900));

      container.dispose();
      container = await booted(FakeAudioEngine());
      expect(container.read(studioProvider).beat.chop.sliceAt(1), 9);
    });
  });

  group('the output coming back at another rate', () {
    test('decodes the project audio again and republishes', () async {
      // A phone that changed route while the output was closed comes back on
      // another clock. Everything in memory is then at the old rate and would
      // play at the wrong speed, and the engine cannot fix it: it holds
      // samples, not the assets they were decoded from. See docs/M4.md.
      expect(state().clip!.sampleRate, engine.sampleRate);
      final was = state().clip!.sampleRate;

      await engine.resumeAt(48000);
      // The break is resampled on another isolate, so this is not immediate.
      for (var i = 0; i < 200 && state().clip!.sampleRate != 48000; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(was, isNot(48000));
      expect(state().clip!.sampleRate, 48000);
      expect(state().kitClips.first.sampleRate, 48000);
      expect(
        engine.lastSpec!.sampleRate,
        48000,
        reason: 'the reloaded audio has to reach the engine, not just state',
      );
      expect(
        state().analysis,
        isNotNull,
        reason: 'the slice waveforms are drawn from the clip that was replaced',
      );
    });
  });
}
