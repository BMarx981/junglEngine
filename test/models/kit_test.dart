import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/kit_slot.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/sub_lane.dart';

void main() {
  group('KitVelocity', () {
    test('tapping walks hard, medium, soft, empty', () {
      expect(KitVelocity.next(null), KitVelocity.hard);
      expect(KitVelocity.next(KitVelocity.hard), KitVelocity.medium);
      expect(KitVelocity.next(KitVelocity.medium), KitVelocity.soft);
      expect(KitVelocity.next(KitVelocity.soft), isNull);
    });

    test('there are exactly three levels', () {
      expect(KitVelocity.values, hasLength(3));
    });

    test('louder levels have more gain', () {
      expect(KitVelocity.soft.gain, lessThan(KitVelocity.medium.gain));
      expect(KitVelocity.medium.gain, lessThan(KitVelocity.hard.gain));
    });
  });

  group('KitPattern', () {
    test('is eight slots wide, whatever else changes', () {
      expect(KitPattern.empty().slots, hasLength(kitSlotCount));
      expect(KitPattern.empty(bars: 8).slots, hasLength(kitSlotCount));
    });

    test('a bar is sixteen steps and length follows the bar count', () {
      expect(KitPattern.empty().stepCount, 16);
      expect(KitPattern.empty(bars: 4).stepCount, 64);
      expect(KitPattern.empty(bars: 4).bars, 4);
    });

    test('slots are independent: writing one leaves the others alone', () {
      final pattern = KitPattern.empty().withCell(0, 3, KitVelocity.hard);
      expect(pattern.velocityAt(0, 3), KitVelocity.hard);
      expect(pattern.velocityAt(1, 3), isNull);
      expect(pattern.slotIsEmpty(1), isTrue);
    });

    test('two slots can fire on the same step', () {
      final pattern = KitPattern.empty()
          .withCell(0, 4, KitVelocity.hard)
          .withCell(5, 4, KitVelocity.soft);
      expect(pattern.velocityAt(0, 4), KitVelocity.hard);
      expect(pattern.velocityAt(5, 4), KitVelocity.soft);
    });

    test('cycling a cell four times comes back to empty', () {
      var pattern = KitPattern.empty();
      for (var i = 0; i < 4; i++) {
        pattern = pattern.cycled(2, 2);
      }
      expect(pattern.velocityAt(2, 2), isNull);
      expect(pattern.isEmpty, isTrue);
    });

    test('out of range writes are ignored rather than throwing', () {
      final pattern = KitPattern.empty()
          .withCell(99, 0, KitVelocity.hard)
          .withCell(0, 99, KitVelocity.hard);
      expect(pattern.isEmpty, isTrue);
    });

    test('the starter pattern is a groove, and repeats over every bar', () {
      final pattern = KitPattern.starter(bars: 2);
      expect(pattern.velocityAt(0, 0), isNotNull, reason: 'kick on the one');
      expect(pattern.velocityAt(1, 4), isNotNull, reason: 'snare on the two');
      expect(
        pattern.velocityAt(0, 16),
        isNotNull,
        reason: 'and again in bar 2',
      );
      expect(pattern.velocityAt(1, 20), isNotNull);
    });

    test('round trips through JSON', () {
      final pattern = KitPattern.empty()
          .withCell(0, 0, KitVelocity.hard)
          .withCell(4, 7, KitVelocity.soft);
      final restored = KitPattern.fromJson(pattern.toJson());
      expect(restored.velocityAt(0, 0), KitVelocity.hard);
      expect(restored.velocityAt(4, 7), KitVelocity.soft);
      expect(restored.velocityAt(4, 8), isNull);
    });

    test('comes back at the Beat\'s length, not the file\'s', () {
      final short = KitPattern.empty().withCell(0, 0, KitVelocity.hard);
      final grown = KitPattern.fromJson(short.toJson(), bars: 4);
      expect(grown.stepCount, 64);
      expect(grown.velocityAt(0, 0), KitVelocity.hard);
      expect(grown.velocityAt(0, 40), isNull);
    });

    test('rubbish JSON opens as an empty pattern', () {
      expect(KitPattern.fromJson('nonsense').isEmpty, isTrue);
      expect(KitPattern.fromJson([1, 2, 3]).isEmpty, isTrue);
    });
  });

  group('KitSlot', () {
    test('pitch maps to playback rate an octave either way', () {
      expect(const KitSlot().rate, closeTo(1.0, 1e-9));
      expect(const KitSlot(pitch: 12).rate, closeTo(2.0, 1e-6));
      expect(const KitSlot(pitch: -12).rate, closeTo(0.5, 1e-6));
    });

    test('volume and pitch are clamped', () {
      const slot = KitSlot();
      expect(slot.copyWith(volume: 4).volume, 1.0);
      expect(slot.copyWith(volume: -1).volume, 0.0);
      expect(slot.copyWith(pitch: 99).pitch, KitSlot.maxPitch);
      expect(slot.copyWith(pitch: -99).pitch, KitSlot.minPitch);
    });

    test('round trips through JSON', () {
      const slot = KitSlot(volume: 0.35, pitch: -5);
      final restored = KitSlot.fromJson(slot.toJson());
      expect(restored.volume, closeTo(0.35, 1e-9));
      expect(restored.pitch, -5);
    });
  });

  group('Beat', () {
    test('a Kit Beat carries its slots and its sub lane', () {
      final beat = Beat(
        id: 'k',
        name: 'B',
        machineType: MachineType.kit,
        kit: KitPattern.empty().withCell(3, 5, KitVelocity.medium),
        sub: SubLane.empty().withStep(0, const SubStep(semitone: -3)),
      ).withSlot(3, const KitSlot(volume: 0.5, pitch: 4));

      final restored = Beat.fromJson(beat.toJson());
      expect(restored.machineType, MachineType.kit);
      expect(restored.kit.velocityAt(3, 5), KitVelocity.medium);
      expect(restored.slot(3).pitch, 4);
      expect(restored.slot(3).volume, closeTo(0.5, 1e-9));
      expect(restored.sub.stepAt(0).semitone, -3);
    });

    test('duplicate copies the music and nothing else', () {
      final source = Beat(
        id: 'b1',
        name: 'A',
        machineType: MachineType.kit,
        bars: 2,
        kit: KitPattern.starter(bars: 2),
        sub: SubLane.empty(bars: 2).withStep(3, const SubStep(semitone: 5)),
      ).withSlot(0, const KitSlot(volume: 0.3, pitch: -2));

      final copy = source.duplicate(id: 'b2', name: 'B');
      expect(copy.id, 'b2');
      expect(copy.name, 'B');
      expect(copy.machineType, MachineType.kit);
      expect(copy.bars, 2);
      expect(copy.kit.velocityAt(0, 0), source.kit.velocityAt(0, 0));
      expect(copy.sub.stepAt(3).semitone, 5);
      expect(copy.slot(0).volume, closeTo(0.3, 1e-9));
    });

    test('length is fixed at creation and every lane matches it', () {
      final beat = Beat(id: 'b', name: 'A', bars: 4);
      expect(beat.stepCount, 64);
      expect(beat.chop.length, 64);
      expect(beat.kit.stepCount, 64);
      expect(beat.sub.steps, hasLength(64));
    });

    test('a saved Beat reopens with every lane at its own length', () {
      final beat = Beat(
        id: 'b',
        name: 'A',
        bars: 4,
        chop: ChopPattern.identity(bars: 4, sliceCount: 16),
      );
      final restored = Beat.fromJson(beat.toJson());
      expect(restored.bars, 4);
      expect(restored.chop.length, 64);
      expect(restored.kit.stepCount, 64);
      expect(restored.sub.steps, hasLength(64));
    });

    test('a length that is not on the menu opens as one bar', () {
      final json = Beat(id: 'b', name: 'A').toJson()..['bars'] = 3;
      expect(Beat.fromJson(json).bars, 1);
    });

    test('knows whether its own drum machine is empty', () {
      final kit = Beat(id: 'k', name: 'K', machineType: MachineType.kit);
      expect(kit.drumsAreEmpty, isTrue);
      expect(
        kit
            .copyWith(kit: kit.kit.withCell(0, 0, KitVelocity.hard))
            .drumsAreEmpty,
        isFalse,
      );

      final chop = Beat(id: 'c', name: 'C');
      expect(chop.drumsAreEmpty, isTrue);
      // A Chop Beat is not made un-empty by something on its unused kit grid.
      expect(
        chop
            .copyWith(kit: chop.kit.withCell(0, 0, KitVelocity.hard))
            .drumsAreEmpty,
        isTrue,
      );
    });
  });
}
