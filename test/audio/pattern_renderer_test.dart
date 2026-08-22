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
const double bpm = 170;
const int sliceCount = 16;

/// One bar at 170 BPM, with each slice holding a distinct DC level so a
/// rendered block says plainly which slice played.
AudioClip testBreak() {
  final frames = (sampleRate * 4 * 60 / bpm).round();
  final samples = Float32List(frames * 2);
  for (var f = 0; f < frames; f++) {
    final slice = (f * sliceCount ~/ frames).clamp(0, sliceCount - 1);
    final value = (slice + 1) / 32.0;
    samples[f * 2] = value;
    samples[f * 2 + 1] = value;
  }
  return AudioClip(samples: samples, channels: 2, sampleRate: sampleRate);
}

RenderSpec specFor(Beat beat, {double tempo = bpm, AudioClip? clip}) =>
    RenderSpec(
      breakClip: clip ?? testBreak(),
      beat: beat,
      bpm: tempo,
      sampleRate: sampleRate,
    );

/// Two flat kit clips at different levels, so a rendered block says plainly
/// which slot fired. Everything past slot 1 is silence.
List<AudioClip> testKit() {
  AudioClip flat(double value) {
    const frames = 4410;
    return AudioClip(
      samples: Float32List(frames * 2)..fillRange(0, frames * 2, value),
      channels: 2,
      sampleRate: sampleRate,
    );
  }

  return [
    flat(0.5),
    flat(0.25),
    for (var i = 2; i < kitSlotCount; i++) flat(0),
  ];
}

Beat kitBeat({required KitPattern kit, List<KitSlot>? slots, SubLane? sub}) =>
    Beat(
      id: 'k',
      name: 'K',
      machineType: MachineType.kit,
      sliceCount: sliceCount,
      kit: kit,
      kitSlots: slots,
      sub: sub ?? SubLane.empty(),
    );

RenderSpec kitSpec(Beat beat, [List<AudioClip>? clips]) => RenderSpec(
  breakClip: testBreak(),
  kitClips: clips ?? testKit(),
  beat: beat,
  bpm: bpm,
  sampleRate: sampleRate,
);

Beat beatWith({ChopPattern? chop, SubLane? sub, SubPatch? patch}) => Beat(
  id: 'b',
  name: 'A',
  sliceCount: sliceCount,
  chop: chop ?? ChopPattern.empty(),
  sub: sub ?? SubLane.empty(),
  subPatch: patch ?? const SubPatch(),
);

Float32List renderAll(RenderSpec spec, int frames) {
  final out = Float32List(frames * 2);
  PatternRenderer(spec).render(out, frames);
  return out;
}

double peakOf(Float32List samples) {
  var peak = 0.0;
  for (final s in samples) {
    if (s.abs() > peak) peak = s.abs();
  }
  return peak;
}

void main() {
  group('timeline', () {
    test('loop length is one bar at the given tempo', () {
      final renderer = PatternRenderer(specFor(beatWith()));
      expect(renderer.loopFrames, (sampleRate * 4 * 60 / bpm).round());
    });

    test('rounding of step boundaries does not drift over the bar', () {
      // 174 does not divide evenly into frames per step.
      final renderer = PatternRenderer(specFor(beatWith(), tempo: 174));
      expect(renderer.loopFrames, closeTo(sampleRate * 4 * 60 / 174, 1));
    });

    test('a slower tempo makes a longer loop', () {
      final fast = PatternRenderer(specFor(beatWith(), tempo: 174)).loopFrames;
      final slow = PatternRenderer(specFor(beatWith(), tempo: 87)).loopFrames;
      expect(slow, closeTo(fast * 2, 2));
    });
  });

  group('chop playback', () {
    test('an empty pattern is silent', () {
      final out = renderAll(specFor(beatWith()), 20000);
      expect(peakOf(out), 0);
    });

    test('a painted step plays the slice that was painted', () {
      final spec = specFor(beatWith(chop: ChopPattern.empty().withStep(0, 5)));
      final renderer = PatternRenderer(spec);
      final stepFrames = renderer.loopFrames ~/ 16;
      final out = Float32List(stepFrames * 2);
      renderer.render(out, stepFrames);

      // Halfway into the step: past the click guard ramps at either end.
      final mid = out[(stepFrames ~/ 2) * 2];
      final expected = PatternRenderer.softClip((5 + 1) / 32.0 * 0.92);
      expect(mid, closeTo(expected, 0.01));
    });

    test('the identity pattern reconstructs the break in order', () {
      final spec = specFor(
        beatWith(chop: ChopPattern.identity(sliceCount: sliceCount)),
      );
      final renderer = PatternRenderer(spec);
      final out = Float32List(renderer.loopFrames * 2);
      renderer.render(out, renderer.loopFrames);

      final stepFrames = renderer.loopFrames / 16;
      for (var step = 0; step < 16; step++) {
        final mid = ((step + 0.5) * stepFrames).round();
        expect(
          out[mid * 2],
          closeTo(PatternRenderer.softClip((step + 1) / 32.0 * 0.92), 0.005),
          reason: 'step $step should be playing slice $step',
        );
      }
    });

    test('the grid is monophonic: a new hit chokes the last one', () {
      final spec = specFor(
        beatWith(chop: ChopPattern.empty().withStep(0, 15).withStep(1, 0)),
      );
      final renderer = PatternRenderer(spec);
      final stepFrames = renderer.loopFrames ~/ 16;
      final out = Float32List(stepFrames * 2 * 2);
      renderer.render(out, stepFrames * 2);

      // Slice 15 is the loudest, slice 0 the quietest. If the choke did not
      // happen, step 1 would still be carrying slice 15's level.
      final second = out[(stepFrames + stepFrames ~/ 2) * 2];
      expect(second, closeTo(PatternRenderer.softClip(1 / 32.0 * 0.92), 0.005));
    });

    test('slices out of range are ignored rather than crashing', () {
      final spec = specFor(
        beatWith(chop: ChopPattern.ofSlices(List<int?>.filled(16, 99))),
      );
      expect(peakOf(renderAll(spec, 20000)), 0);
    });
  });

  group('sub lane', () {
    test('a note makes sound and a rest does not', () {
      final withNote = renderAll(
        specFor(
          beatWith(
            sub: SubLane.empty().withStep(0, const SubStep(semitone: 0)),
          ),
        ),
        20000,
      );
      expect(peakOf(withNote), greaterThan(0.01));
      expect(peakOf(renderAll(specFor(beatWith()), 20000)), 0);
    });

    test('a tied cell glides instead of retriggering', () {
      final tied = renderAll(
        specFor(
          beatWith(
            sub: SubLane.empty()
                .withStep(0, const SubStep(semitone: -12))
                .withStep(1, const SubStep(semitone: 0, tie: true)),
            patch: const SubPatch(glide: 0.9),
          ),
        ),
        20000,
      );
      final retriggered = renderAll(
        specFor(
          beatWith(
            sub: SubLane.empty()
                .withStep(0, const SubStep(semitone: -12))
                .withStep(1, const SubStep(semitone: 0)),
            patch: const SubPatch(glide: 0.9),
          ),
        ),
        20000,
      );
      expect(tied, isNot(equals(retriggered)));
    });

    test('a held cell keeps the note going through the rest', () {
      final held = renderAll(
        specFor(
          beatWith(
            sub: SubLane.empty()
                .withStep(0, const SubStep(semitone: 0))
                .withStep(1, const SubStep(tie: true))
                .withStep(2, const SubStep(tie: true)),
            patch: const SubPatch(decay: 0.0),
          ),
        ),
        20000,
      );
      final cut = renderAll(
        specFor(
          beatWith(
            sub: SubLane.empty().withStep(0, const SubStep(semitone: 0)),
            patch: const SubPatch(decay: 0.0),
          ),
        ),
        20000,
      );
      // With the fastest release, the un-held note is long gone by step 2.
      final stepFrames = PatternRenderer(specFor(beatWith())).loopFrames ~/ 16;
      final at = (stepFrames * 2 + 100) * 2;
      expect(held[at].abs(), greaterThan(0.01));
      expect(cut[at].abs(), lessThan(0.001));
    });
  });

  group('determinism', () {
    test('two renders of the same spec are sample identical', () {
      final clip = testBreak();
      final beat = beatWith(
        chop: ChopPattern.identity(sliceCount: sliceCount),
        sub: SubLane.empty().withStep(0, const SubStep(semitone: -7)),
      );
      final a = renderAll(specFor(beat, clip: clip), 40000);
      final b = renderAll(specFor(beat, clip: clip), 40000);
      expect(a, equals(b));
    });

    test('rewind puts the renderer back exactly where it started', () {
      final spec = specFor(
        beatWith(chop: ChopPattern.identity(sliceCount: sliceCount)),
      );
      final renderer = PatternRenderer(spec);
      final first = Float32List(8000 * 2);
      renderer.render(first, 8000);
      renderer.rewind();
      final second = Float32List(8000 * 2);
      renderer.render(second, 8000);
      expect(first, equals(second));
    });

    test('block size does not change the result', () {
      final spec = specFor(
        beatWith(
          chop: ChopPattern.identity(sliceCount: sliceCount),
          sub: SubLane.empty().withStep(4, const SubStep(semitone: 3)),
        ),
      );
      const frames = 30000;
      final oneGo = renderAll(spec, frames);

      final chunked = Float32List(frames * 2);
      final renderer = PatternRenderer(spec);
      final scratch = Float32List(777 * 2);
      var done = 0;
      while (done < frames) {
        final n = (frames - done) < 777 ? frames - done : 777;
        renderer.render(scratch, n);
        chunked.setRange(done * 2, (done + n) * 2, scratch);
        done += n;
      }
      expect(chunked, equals(oneGo));
    });
  });

  group('offline render', () {
    test('produces exactly the frames asked for', () {
      final spec = specFor(
        beatWith(chop: ChopPattern.identity(sliceCount: sliceCount)),
      );
      final frames = PatternRenderer(spec).loopFrames * 2;
      expect(renderPatternOffline(spec, frames).length, frames * 2);
    });

    test('matches live playback for the whole loop', () {
      final spec = specFor(
        beatWith(
          chop: ChopPattern.identity(sliceCount: sliceCount),
          sub: SubLane.empty().withStep(0, const SubStep(semitone: -5)),
        ),
      );
      final frames = PatternRenderer(spec).loopFrames;
      final live = renderAll(spec, frames);
      final offline = renderPatternOffline(spec, frames);

      // The tail fold only touches the head of the file, so past the fold the
      // exported samples have to be the live samples exactly.
      final foldFrames = (sampleRate * 1.2).round();
      expect(foldFrames, lessThan(frames), reason: 'fold must not cover all');
      for (var i = foldFrames * 2; i < frames * 2; i++) {
        expect(offline[i], closeTo(live[i], 1e-6));
      }
    });

    test('folds the ring out back onto the head so the file loops', () {
      final spec = specFor(
        beatWith(
          sub: SubLane.empty().withStep(15, const SubStep(semitone: 0)),
          patch: const SubPatch(decay: 1.0),
        ),
      );
      final frames = PatternRenderer(spec).loopFrames;
      final offline = renderPatternOffline(spec, frames);
      // The last note's tail has to be audible at the top of the file.
      expect(offline[0].abs() + offline[200].abs(), greaterThan(0.0001));
    });
  });

  group('kit playback', () {
    test('an empty kit is silent', () {
      final out = renderAll(kitSpec(kitBeat(kit: KitPattern.empty())), 20000);
      expect(peakOf(out), 0);
    });

    test('a placed hit plays that slot at that step', () {
      final spec = kitSpec(
        kitBeat(kit: KitPattern.empty().withCell(0, 0, KitVelocity.hard)),
      );
      final renderer = PatternRenderer(spec);
      final stepFrames = renderer.loopFrames ~/ 16;
      final out = Float32List(stepFrames * 2 * 2);
      renderer.render(out, stepFrames * 2);

      // Slot 0's clip is flat, so the level says which slot fired.
      const expected = 0.5 * 0.8 * 1.0 * 0.92;
      expect(out[100 * 2], closeTo(PatternRenderer.softClip(expected), 1e-4));
      // One shots ring past the step boundary rather than being cut at it, so
      // the check for "nothing else fired" is past the end of the clip.
      expect(out[5000 * 2].abs(), lessThan(1e-6));
    });

    test('velocity scales the hit', () {
      double levelOf(KitVelocity velocity) {
        final out = renderAll(
          kitSpec(kitBeat(kit: KitPattern.empty().withCell(0, 0, velocity))),
          2000,
        );
        return out[100 * 2];
      }

      final hard = levelOf(KitVelocity.hard);
      final medium = levelOf(KitVelocity.medium);
      final soft = levelOf(KitVelocity.soft);
      expect(medium, lessThan(hard));
      expect(soft, lessThan(medium));
      expect(soft / hard, closeTo(KitVelocity.soft.gain, 0.02));
    });

    test('slots are independent: two on one step both sound', () {
      final one = renderAll(
        kitSpec(
          kitBeat(kit: KitPattern.empty().withCell(0, 0, KitVelocity.hard)),
        ),
        2000,
      );
      final both = renderAll(
        kitSpec(
          kitBeat(
            kit: KitPattern.empty()
                .withCell(0, 0, KitVelocity.hard)
                .withCell(1, 0, KitVelocity.hard),
          ),
        ),
        2000,
      );
      expect(both[100 * 2], greaterThan(one[100 * 2]));
    });

    test('slot volume turns a slot down', () {
      final quiet = renderAll(
        kitSpec(
          kitBeat(
            kit: KitPattern.empty().withCell(0, 0, KitVelocity.hard),
            slots: [
              const KitSlot(volume: 0.2),
              ...KitSlot.defaults(kitSlotCount - 1),
            ],
          ),
        ),
        2000,
      );
      expect(
        quiet[100 * 2],
        closeTo(PatternRenderer.softClip(0.5 * 0.2 * 0.92), 1e-4),
      );
    });

    test('pitching a slot down makes it ring longer', () {
      Float32List render(int pitch) => renderAll(
        kitSpec(
          kitBeat(
            kit: KitPattern.empty().withCell(0, 0, KitVelocity.hard),
            slots: [
              KitSlot(pitch: pitch),
              ...KitSlot.defaults(kitSlotCount - 1),
            ],
          ),
        ),
        7000,
      );

      // The slot's clip is 4410 frames at unity. An octave down reads it at
      // half speed, so it is still playing where the untouched slot has ended.
      expect(render(0)[6000 * 2].abs(), lessThan(1e-6));
      expect(render(-12)[6000 * 2].abs(), greaterThan(0.01));
    });

    test('a Kit Beat ignores whatever is on its chop grid', () {
      final beat = Beat(
        id: 'k',
        name: 'K',
        machineType: MachineType.kit,
        sliceCount: sliceCount,
        chop: ChopPattern.identity(sliceCount: sliceCount),
        kit: KitPattern.empty(),
      );
      expect(peakOf(renderAll(kitSpec(beat), 20000)), 0);
    });

    test('a Chop Beat ignores whatever is on its kit grid', () {
      final beat = beatWith();
      final spec = RenderSpec(
        breakClip: testBreak(),
        kitClips: testKit(),
        beat: beat.copyWith(
          kit: KitPattern.empty().withCell(0, 0, KitVelocity.hard),
        ),
        bpm: bpm,
        sampleRate: sampleRate,
      );
      expect(peakOf(renderAll(spec, 20000)), 0);
    });

    test('the sub lane plays under the Kit machine too', () {
      final out = renderAll(
        kitSpec(
          kitBeat(
            kit: KitPattern.empty(),
            sub: SubLane.empty().withStep(0, const SubStep(semitone: 0)),
          ),
        ),
        20000,
      );
      expect(peakOf(out), greaterThan(0.01));
    });

    test('two renders of the same kit spec are sample identical', () {
      final clips = testKit();
      final beat = kitBeat(kit: KitPattern.starter());
      final a = renderAll(kitSpec(beat, clips), 40000);
      final b = renderAll(kitSpec(beat, clips), 40000);
      expect(a, equals(b));
    });
  });

  group('swing', () {
    /// One click at the head of every slice, so a rendered onset says exactly
    /// where a step fired.
    AudioClip clickBreak() {
      final frames = (sampleRate * 4 * 60 / bpm).round();
      final samples = Float32List(frames * 2);
      final sliceFrames = frames / sliceCount;
      for (var f = 0; f < frames; f++) {
        if (f % sliceFrames.round() < 300) {
          samples[f * 2] = 0.8;
          samples[f * 2 + 1] = 0.8;
        }
      }
      return AudioClip(samples: samples, channels: 2, sampleRate: sampleRate);
    }

    final clip = clickBreak();

    Beat swung(double swing) => beatWith(
      chop: ChopPattern.empty().withStep(0, 0).withStep(1, 0),
    ).copyWith(swing: swing);

    RenderSpec spec(double swing) => specFor(swung(swing), clip: clip);

    /// First frame past [from] where the mix is loud.
    int onsetAfter(Float32List out, int from) {
      for (var f = from; f < out.length ~/ 2; f++) {
        if (out[f * 2].abs() > 0.4) return f;
      }
      return -1;
    }

    test('swing does not change how long the bar is', () {
      expect(
        PatternRenderer(spec(1)).loopFrames,
        PatternRenderer(spec(0)).loopFrames,
      );
    });

    test('the offbeat is pushed late and the downbeat is not', () {
      final stepFrames = PatternRenderer(spec(0)).framesPerStep;

      final straight = renderAll(spec(0), 40000);
      final hard = renderAll(spec(1), 40000);

      expect(onsetAfter(straight, 0), lessThan(20));
      expect(onsetAfter(hard, 0), lessThan(20));

      // Full swing puts the second sixteenth two thirds of the way through the
      // pair, which is half a step later than straight.
      expect(
        onsetAfter(straight, (stepFrames * 0.5).round()),
        closeTo(stepFrames, 30),
      );
      expect(
        onsetAfter(hard, (stepFrames * 0.5).round()),
        closeTo(stepFrames * 1.5, 30),
      );
    });

    test('half swing lands halfway between straight and triplets', () {
      final stepFrames = PatternRenderer(spec(0)).framesPerStep;
      final half = renderAll(spec(0.5), 40000);
      expect(
        onsetAfter(half, (stepFrames * 0.5).round()),
        closeTo(stepFrames * 1.25, 30),
      );
    });

    test('swing can be dragged without restarting the loop', () {
      final renderer = PatternRenderer(spec(0));
      final before = renderer.loopFrames;
      expect(renderer.canAdopt(spec(0.6)), isTrue);
      renderer.updateSpec(spec(0.6));
      expect(renderer.loopFrames, before);
      expect(renderer.spec.beat.swing, 0.6);
    });
  });

  group('step modifiers', () {
    /// A break whose every slice ramps from quiet to loud, so the level of a
    /// rendered sample says how far into its slice the read head is.
    AudioClip rampBreak() {
      final frames = (sampleRate * 4 * 60 / bpm).round();
      final samples = Float32List(frames * 2);
      final sliceFrames = frames / sliceCount;
      for (var f = 0; f < frames; f++) {
        final into = (f % sliceFrames) / sliceFrames;
        final value = 0.05 + 0.9 * into;
        samples[f * 2] = value;
        samples[f * 2 + 1] = value;
      }
      return AudioClip(samples: samples, channels: 2, sampleRate: sampleRate);
    }

    /// Renders one step of a Beat holding slice 0 with [mod] on step 0, and
    /// reports the level at [fraction] of the way through that step.
    double levelAt(StepMod mod, double fraction) {
      final beat = beatWith(
        chop: ChopPattern.empty().withCell(0, ChopStep(0, mod: mod)),
      );
      final spec = specFor(beat, clip: rampBreak());
      final renderer = PatternRenderer(spec);
      final stepFrames = renderer.loopFrames ~/ 16;
      final out = Float32List(stepFrames * 2);
      renderer.render(out, stepFrames);
      return out[(stepFrames * fraction).round() * 2];
    }

    test('a plain step reads the slice forwards', () {
      expect(levelAt(StepMod.none, 0.2), lessThan(levelAt(StepMod.none, 0.8)));
    });

    test('reverse reads it backwards', () {
      expect(
        levelAt(StepMod.reverse, 0.2),
        greaterThan(levelAt(StepMod.reverse, 0.8)),
      );
      // Backwards from the top of the slice, so early in the step is loud.
      expect(
        levelAt(StepMod.reverse, 0.2),
        greaterThan(levelAt(StepMod.none, 0.2)),
      );
    });

    test('half speed gets half as far through the slice', () {
      final plain = levelAt(StepMod.none, 0.8);
      final half = levelAt(StepMod.halfSpeed, 0.8);
      expect(half, lessThan(plain));
      // Half the distance along a straight ramp, allowing for the offset the
      // ramp starts at.
      expect(half - 0.05, closeTo((plain - 0.05) / 2, 0.08));
    });

    test('pitch down is slower than plain and faster than half speed', () {
      final plain = levelAt(StepMod.none, 0.8);
      final pitched = levelAt(StepMod.pitchDown, 0.8);
      final half = levelAt(StepMod.halfSpeed, 0.8);
      expect(pitched, lessThan(plain));
      expect(pitched, greaterThan(half));
    });

    test('retrigger starts the slice again four times inside the step', () {
      // Just after each subdivision the read head is back at the head of the
      // slice, so the ramp is quiet again where a plain step would be loud.
      for (final at in [0.27, 0.52, 0.77]) {
        expect(
          levelAt(StepMod.retrigger, at),
          lessThan(levelAt(StepMod.none, at)),
          reason: 'retrigger should have restarted before $at of the step',
        );
      }
    });

    test('a modifier does not leak onto the next step', () {
      final beat = beatWith(
        chop: ChopPattern.empty()
            .withCell(0, const ChopStep(0, mod: StepMod.reverse))
            .withStep(1, 0),
      );
      final spec = specFor(beat, clip: rampBreak());
      final renderer = PatternRenderer(spec);
      final stepFrames = renderer.loopFrames ~/ 16;
      final out = Float32List(stepFrames * 2 * 2);
      renderer.render(out, stepFrames * 2);
      final first = out[(stepFrames * 0.2).round() * 2];
      final second = out[(stepFrames * 1.2).round() * 2];
      expect(second, lessThan(first));
    });
  });

  group('song', () {
    // One clip for every spec in this group: the renderer only swaps a spec in
    // under a running playhead when the break behind it is the same object.
    final clip = testBreak();
    final kit = testKit();

    RenderSpec songSpec(List<Beat> beats) => RenderSpec.of(
      breakClip: clip,
      kitClips: kit,
      sections: [
        for (var i = 0; i < beats.length; i++)
          RenderSection(beat: beats[i], entryIndex: i),
      ],
      bpm: bpm,
      sampleRate: sampleRate,
    );

    Beat chopBeat(String id, int slice) => Beat(
      id: id,
      name: id,
      sliceCount: sliceCount,
      chop: ChopPattern.empty().withStep(0, slice),
      sub: SubLane.empty(),
    );

    test('the timeline is every section, end to end', () {
      final one = PatternRenderer(specFor(beatWith())).loopFrames;
      final renderer = PatternRenderer(
        songSpec([chopBeat('a', 0), chopBeat('b', 1)]),
      );
      expect(renderer.stepCount, 32);
      expect(renderer.loopFrames, closeTo(one * 2, 2));
    });

    test('sections play in order, across machine types', () {
      final kit = kitBeat(
        kit: KitPattern.empty().withCell(0, 0, KitVelocity.hard),
      );
      final spec = songSpec([chopBeat('a', 5), kit]);
      final renderer = PatternRenderer(spec);
      final barFrames = renderer.loopFrames ~/ 2;
      final out = Float32List(renderer.loopFrames * 2);
      renderer.render(out, renderer.loopFrames);

      // First bar: slice 5 of the break. Second: slot 0 of the kit.
      expect(
        out[100 * 2],
        closeTo(PatternRenderer.softClip((5 + 1) / 32.0 * 0.92), 0.01),
      );
      expect(
        out[(barFrames + 100) * 2],
        closeTo(PatternRenderer.softClip(0.5 * 0.8 * 0.92), 1e-3),
      );
    });

    test('the playhead reports the card and the step within its Beat', () {
      final renderer = PatternRenderer(
        songSpec([chopBeat('a', 0), chopBeat('b', 1)]),
      );
      final stepFrames = renderer.framesPerStep;

      final first = renderer.positionAt((stepFrames * 2).round() + 5);
      expect(first.entryIndex, 0);
      expect(first.beatId, 'a');
      expect(first.step, 2);
      expect(first.stepCount, 16);

      final second = renderer.positionAt((stepFrames * 19).round() + 5);
      expect(second.entryIndex, 1);
      expect(second.beatId, 'b');
      expect(second.step, 3);
      expect(second.position, closeTo(3 / 16, 0.02));
    });

    test('a card can be added while the song plays', () {
      final renderer = PatternRenderer(songSpec([chopBeat('a', 0)]));
      final longer = songSpec([chopBeat('a', 0), chopBeat('b', 1)]);
      expect(renderer.canAdopt(longer), isTrue);
      renderer.updateSpec(longer);
      expect(renderer.stepCount, 32);
    });

    test('a different Beat under the playhead needs a new renderer', () {
      final renderer = PatternRenderer(songSpec([chopBeat('a', 0)]));
      expect(renderer.canAdopt(songSpec([chopBeat('c', 0)])), isFalse);
    });
  });

  group('sub accent', () {
    /// How much of the signal is above the fundamental, roughly: the sum of
    /// sample to sample movement. A more open filter passes more harmonics and
    /// the waveform moves faster, which is what an accent sounds like.
    double brightnessOf(bool accent) {
      final out = renderAll(
        specFor(
          beatWith(
            sub: SubLane.empty().withStep(
              0,
              SubStep(semitone: 0, accent: accent),
            ),
            patch: const SubPatch(cutoff: 0.3, decay: 0.5),
          ),
        ),
        20000,
      );
      var sum = 0.0;
      for (var i = 2; i < out.length; i += 2) {
        sum += (out[i] - out[i - 2]).abs();
      }
      return sum;
    }

    test('an accented note opens the filter and speaks up', () {
      expect(brightnessOf(true), greaterThan(brightnessOf(false) * 1.1));

      double peakFor(bool accent) => peakOf(
        renderAll(
          specFor(
            beatWith(
              sub: SubLane.empty().withStep(
                0,
                SubStep(semitone: 0, accent: accent),
              ),
              patch: const SubPatch(cutoff: 0.3, decay: 0.5),
            ),
          ),
          20000,
        ),
      );
      expect(peakFor(true), greaterThan(peakFor(false)));
    });

    test('the accent does not carry into the next note', () {
      final out = renderAll(
        specFor(
          beatWith(
            sub: SubLane.empty()
                .withStep(0, const SubStep(semitone: 0, accent: true))
                .withStep(4, const SubStep(semitone: 0)),
            patch: const SubPatch(cutoff: 0.3, decay: 0.2),
          ),
        ),
        40000,
      );
      final plain = renderAll(
        specFor(
          beatWith(
            sub: SubLane.empty()
                .withStep(0, const SubStep(semitone: 0))
                .withStep(4, const SubStep(semitone: 0)),
            patch: const SubPatch(cutoff: 0.3, decay: 0.2),
          ),
        ),
        40000,
      );
      // Second note in both renders is unaccented, so from there on the two
      // have to agree.
      final stepFrames = PatternRenderer(specFor(beatWith())).loopFrames ~/ 16;
      final from = (stepFrames * 4 + 400) * 2;
      for (var i = from; i < from + 2000; i++) {
        expect(out[i], closeTo(plain[i], 1e-6));
      }
    });
  });
}
