import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/features/bass/sub_panel.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/project.dart';
import 'package:junglengine/models/song.dart';
import 'package:junglengine/models/step_mod.dart';
import 'package:junglengine/models/sub_lane.dart';
import 'package:junglengine/models/sub_patch.dart';

void main() {
  group('Project JSON', () {
    test('round trips a chop beat with a sub lane', () {
      final project = Project(
        id: 'p1',
        name: 'test',
        breakId: 'hawkstreak-amenish-170',
        kitId: 'hawkstreak-01',
        bpm: 174,
        beats: [
          Beat(
            id: 'b1',
            name: 'A',
            sliceCount: 16,
            chop: ChopPattern.identity(sliceCount: 16).withStep(3, 9),
            sub: SubLane.empty()
                .withStep(0, const SubStep(semitone: -5))
                .withStep(1, const SubStep(semitone: 2, tie: true)),
            subPatch: const SubPatch(cutoff: 0.7, glide: 0.9),
          ),
        ],
        song: const Song([SongEntry(beatId: 'b1', repeats: 4)]),
      );

      final restored = Project.fromJson(project.toJson());
      final beat = restored.beats.single;

      expect(restored.bpm, 174);
      expect(restored.breakId, 'hawkstreak-amenish-170');
      expect(beat.sliceCount, 16);
      expect(beat.chop.sliceAt(3), 9);
      expect(beat.chop.sliceAt(4), 4);
      expect(beat.sub.stepAt(0).semitone, -5);
      expect(beat.sub.stepAt(1).tie, isTrue);
      expect(beat.subPatch.cutoff, closeTo(0.7, 1e-9));
      expect(restored.song.entries.single.repeats, 4);
    });

    // M1 adds Kit beats. This is the check that it will be additive.
    test('preserves machine type so M1 is not a migration', () {
      final project = Project(
        id: 'p1',
        name: 'test',
        breakId: 'b',
        kitId: 'hawkstreak-01',
        bpm: 170,
        beats: [
          Beat(id: 'chop', name: 'A', machineType: MachineType.chop),
          Beat(id: 'kit', name: 'B', machineType: MachineType.kit),
        ],
      );

      final restored = Project.fromJson(project.toJson());
      expect(restored.beatById('chop')!.machineType, MachineType.chop);
      expect(restored.beatById('kit')!.machineType, MachineType.kit);
    });

    test('an unreadable project still opens with one chop beat', () {
      final restored = Project.fromJson({'id': 'x'});
      expect(restored.beats, hasLength(1));
      expect(restored.beats.single.machineType, MachineType.chop);
    });
  });

  group('ChopPattern', () {
    test('identity maps step n to slice n', () {
      final pattern = ChopPattern.identity(sliceCount: 16);
      for (var i = 0; i < 16; i++) {
        expect(pattern.sliceAt(i), i);
      }
    });

    test('tapping the same cell twice clears it', () {
      var pattern = ChopPattern.empty();
      pattern = pattern.toggled(2, 7);
      expect(pattern.sliceAt(2), 7);
      pattern = pattern.toggled(2, 7);
      expect(pattern.sliceAt(2), isNull);
    });

    test(
      'tapping a different row replaces, because the grid is monophonic',
      () {
        final pattern = ChopPattern.empty().toggled(2, 7).toggled(2, 3);
        expect(pattern.sliceAt(2), 3);
      },
    );

    test('re-slicing drops slices that no longer exist', () {
      final pattern = ChopPattern.identity(sliceCount: 32).clampedTo(8);
      expect(pattern.sliceAt(3), 3);
      expect(pattern.sliceAt(9), isNull);
    });
  });

  group('step modifiers', () {
    test('a plain step is still written as a bare number', () {
      final pattern = ChopPattern.empty().withStep(0, 7);
      expect(pattern.toJson().first, 7);
    });

    test('a modifier round trips and a plain step has none', () {
      final pattern = ChopPattern.empty()
          .withStep(0, 7)
          .withStep(1, 3)
          .withMod(0, StepMod.reverse);
      final restored = ChopPattern.fromJson(pattern.toJson());

      expect(restored.sliceAt(0), 7);
      expect(restored.modAt(0), StepMod.reverse);
      expect(restored.modAt(1), StepMod.none);
    });

    test('an M1 file of bare numbers still opens', () {
      final restored = ChopPattern.fromJson([for (var i = 0; i < 16; i++) i]);
      expect(restored.sliceAt(9), 9);
      expect(restored.modAt(9), StepMod.none);
    });

    test('an unknown modifier reads as plain rather than losing the slice', () {
      final restored = ChopPattern.fromJson([
        {'s': 4, 'm': 'wobble'},
      ]);
      expect(restored.sliceAt(0), 4);
      expect(restored.modAt(0), StepMod.none);
    });

    test('an empty step has nothing to modify', () {
      final pattern = ChopPattern.empty().withMod(0, StepMod.reverse);
      expect(pattern.isEmpty, isTrue);
    });

    test('painting a slice over a modified step starts it clean', () {
      final pattern = ChopPattern.empty()
          .withStep(0, 7)
          .withMod(0, StepMod.halfSpeed)
          .withStep(0, 2);
      expect(pattern.modAt(0), StepMod.none);
    });

    test('re-slicing drops a modified step that no longer exists', () {
      final pattern = ChopPattern.empty()
          .withStep(0, 20)
          .withMod(0, StepMod.reverse)
          .clampedTo(16);
      expect(pattern.stepAt(0), isNull);
    });
  });

  group('swing', () {
    test('is straight by default and reads as a percentage', () {
      final beat = Beat(id: 'b', name: 'A');
      expect(beat.swing, 0);
      expect(beat.swingPercent, 50);
    });

    test('full swing is a 75 percent shuffle, half a step late', () {
      final beat = Beat(id: 'b', name: 'A', swing: 1);
      expect(beat.swingPercent, 75);
      expect(beat.swingOffsetFraction, 0.5);
    });

    test('clamps, and round trips through JSON', () {
      final beat = Beat(id: 'b', name: 'A', swing: 4);
      expect(beat.swing, 1);
      expect(Beat.fromJson(beat.copyWith(swing: 0.4).toJson()).swing, 0.4);
    });
  });

  group('Song', () {
    const song = Song([
      SongEntry(beatId: 'a', repeats: 2),
      SongEntry(beatId: 'b'),
      SongEntry(beatId: 'c', repeats: 4),
    ]);

    test('repeats are clamped to something a card can hold', () {
      expect(const SongEntry(beatId: 'a', repeats: 0).repeats, 1);
      expect(const SongEntry(beatId: 'a', repeats: 99).repeats, 16);
    });

    test('counts the passes it plays', () {
      expect(song.totalPasses, 7);
    });

    test('moving a card puts it where it was dropped', () {
      final moved = song.moved(0, 2);
      expect([for (final e in moved.entries) e.beatId], ['b', 'c', 'a']);
    });

    test('removing a card leaves the rest in order', () {
      final without = song.withoutAt(1);
      expect([for (final e in without.entries) e.beatId], ['a', 'c']);
    });

    test('changing repeats only touches that card', () {
      final next = song.withRepeatsAt(0, 8);
      expect(next.entries[0].repeats, 8);
      expect(next.entries[2].repeats, 4);
    });

    test('bars come from the Beats the cards point at', () {
      final project = Project(
        id: 'p',
        name: 'p',
        breakId: '',
        kitId: '',
        bpm: 170,
        beats: [
          Beat(id: 'a', name: 'A', bars: 2),
          Beat(id: 'b', name: 'B', bars: 4),
        ],
        song: const Song([
          SongEntry(beatId: 'a', repeats: 4),
          SongEntry(beatId: 'b', repeats: 2),
          // A card pointing at a Beat that is gone counts for nothing.
          SongEntry(beatId: 'ghost', repeats: 8),
        ]),
      );
      expect(project.songBars, 16);
      expect(project.songIsPlayable, isTrue);
    });
  });

  group('SubLane', () {
    test('step 0 cannot be tied, there is nothing to glide from', () {
      expect(SubLane.empty().toggledTie(0).stepAt(0).tie, isFalse);
    });

    test('a tie is independent of whether the cell has a pitch', () {
      final lane = SubLane.empty().toggledTie(5);
      expect(lane.stepAt(5).tie, isTrue);
      expect(lane.stepAt(5).semitone, isNull);
    });
  });

  group('SubPatch', () {
    test('exposes exactly six parameters', () {
      expect(SubPatch.parameterCount, 6);
      // The panel must have a word for each one. The labels moved out of the
      // model so they could stay English while everything around them is
      // translated, and this is what keeps the two halves in step.
      expect(subParameterLabels, hasLength(SubPatch.parameterCount));
    });

    test('parameters clamp to 0..1', () {
      const patch = SubPatch();
      expect(patch.withParameter(1, 4).cutoff, 1.0);
      expect(patch.withParameter(1, -2).cutoff, 0.0);
    });

    test('every parameter index round trips through withParameter', () {
      const patch = SubPatch();
      for (var i = 0; i < SubPatch.parameterCount; i++) {
        expect(patch.withParameter(i, 0.6).parameter(i), 0.6, reason: 'index $i');
      }
    });

    test('a fresh patch is the sub as it was before the second oscillator', () {
      // Detune 0 and a tone in the lower half of the morph. A user who never
      // touches the new knob never hears it.
      const patch = SubPatch();
      expect(patch.detune, 0.0);
      expect(patch.tone, lessThanOrEqualTo(0.5));
    });

    group('tone migration', () {
      test('a patch saved before the Reese is rescaled onto the new morph', () {
        // No detune key, so tone still means sine to triangle across 0..1.
        final patch = SubPatch.fromJson(const {
          'tone': 0.25,
          'cutoff': 0.7,
          'drive': 0.2,
          'decay': 0.35,
          'glide': 0.9,
        });
        // Exactly half, not approximately: halving is exact in binary, which is
        // what lets the migrated patch render the samples it always did.
        expect(patch.tone, 0.125);
        expect(patch.detune, 0.0);
        // Nothing else moves.
        expect(patch.cutoff, 0.7);
        expect(patch.glide, 0.9);
      });

      test('full triangle lands at the middle of the new knob', () {
        expect(SubPatch.fromJson(const {'tone': 1.0}).tone, 0.5);
      });

      test('a patch saved after it is read as written', () {
        final patch = SubPatch.fromJson(const {'tone': 0.8, 'detune': 0.4});
        expect(patch.tone, 0.8);
        expect(patch.detune, 0.4);
      });

      test('a round trip is stable, so migration happens exactly once', () {
        const original = SubPatch(tone: 0.9, detune: 0.6);
        final once = SubPatch.fromJson(original.toJson());
        final twice = SubPatch.fromJson(once.toJson());
        expect(once.tone, 0.9);
        expect(twice.tone, 0.9);
        expect(twice.detune, 0.6);
      });

      test('a patch with no tone at all takes the new default', () {
        expect(SubPatch.fromJson(const {'cutoff': 0.5}).tone, const SubPatch().tone);
      });
    });
  });

  group('beat bank', () {
    Project bank(List<Beat> beats, {Song song = const Song.empty()}) => Project(
      id: 'p1',
      name: 'test',
      breakId: 'b',
      kitId: 'k',
      bpm: 170,
      beats: beats,
      song: song,
    );

    test('a new Beat goes on the end', () {
      final project = bank([Beat(id: 'beat-1', name: 'A')]);
      final grown = project.withNewBeat(Beat(id: 'beat-2', name: 'B'));
      expect(grown.beats.map((b) => b.id), ['beat-1', 'beat-2']);
    });

    test('a duplicate lands next to what it came from', () {
      final project = bank([
        Beat(id: 'beat-1', name: 'A'),
        Beat(id: 'beat-2', name: 'B'),
      ]);
      final grown = project.withBeatAfter(
        'beat-1',
        Beat(id: 'beat-3', name: 'C'),
      );
      expect(grown.beats.map((b) => b.id), ['beat-1', 'beat-3', 'beat-2']);
    });

    test('deleting a Beat takes its Song entries with it', () {
      final project = bank(
        [Beat(id: 'beat-1', name: 'A'), Beat(id: 'beat-2', name: 'B')],
        song: const Song([
          SongEntry(beatId: 'beat-1'),
          SongEntry(beatId: 'beat-2', repeats: 4),
          SongEntry(beatId: 'beat-1'),
        ]),
      );
      final smaller = project.withoutBeat('beat-1');
      expect(smaller.beats.map((b) => b.id), ['beat-2']);
      expect(smaller.song.entries.map((e) => e.beatId), ['beat-2']);
    });

    test('the last Beat cannot be deleted: something is always open', () {
      final project = bank([Beat(id: 'beat-1', name: 'A')]);
      expect(project.withoutBeat('beat-1').beats, hasLength(1));
    });

    test('ids are unique among the Beats that exist', () {
      var project = bank([
        Beat(id: 'beat-1', name: 'A'),
        Beat(id: 'beat-2', name: 'B'),
      ]);
      expect(project.nextBeatId(), 'beat-3');
      project = project.withoutBeat('beat-2');
      expect(project.nextBeatId(), 'beat-2');
    });

    test('names walk the alphabet and skip what is taken', () {
      final project = bank([
        Beat(id: 'beat-1', name: 'A'),
        Beat(id: 'beat-2', name: 'C'),
      ]);
      expect(project.nextBeatName(), 'B');
    });

    test('a project of both machine types round trips', () {
      final project = bank([
        Beat(id: 'beat-1', name: 'A', bars: 2),
        Beat(
          id: 'beat-2',
          name: 'B',
          machineType: MachineType.kit,
          bars: 4,
          kit: KitPattern.starter(bars: 4),
        ),
      ]);
      final restored = Project.fromJson(project.toJson());
      expect(restored.kitId, 'k');
      expect(restored.beatById('beat-1')!.bars, 2);
      final kit = restored.beatById('beat-2')!;
      expect(kit.machineType, MachineType.kit);
      expect(kit.bars, 4);
      expect(kit.kit.velocityAt(0, 0), isNotNull);
    });

    test('a version 1 file, from before Kit Beats, still opens', () {
      // Exactly what M0 wrote: no kitId, no kit grid, no slots.
      final restored = Project.fromJson({
        'version': 1,
        'id': 'p1',
        'name': 'junglEngine',
        'breakId': 'dnb-full02-170',
        'bpm': 170.0,
        'beats': [
          {
            'id': 'beat-1',
            'name': 'A',
            'machine': 'chop',
            'bars': 1,
            'sliceCount': 64,
            'chop': [for (var i = 0; i < 16; i++) i],
            'sub': [for (var i = 0; i < 16; i++) <String, Object?>{}],
            'subPatch': const SubPatch().toJson(),
            'subRootMidi': 36,
          },
        ],
        'song': <Object?>[],
      });

      final beat = restored.beats.single;
      expect(restored.breakId, 'dnb-full02-170');
      expect(beat.chop.sliceAt(3), 3);
      expect(beat.kit.isEmpty, isTrue);
      expect(beat.kitSlots, hasLength(kitSlotCount));
      // No kit means the default kit, not a broken reference.
      expect(restored.kitId, '');
    });
  });
}
