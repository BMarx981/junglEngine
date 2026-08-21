import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/project.dart';
import 'package:junglengine/models/song.dart';
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
    test('exposes exactly five parameters', () {
      expect(SubPatch.parameterNames, hasLength(5));
    });

    test('parameters clamp to 0..1', () {
      const patch = SubPatch();
      expect(patch.withParameter(1, 4).cutoff, 1.0);
      expect(patch.withParameter(1, -2).cutoff, 0.0);
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
