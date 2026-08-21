import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/audio/soloud_engine.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/chop_pattern.dart';
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
      final spec = specFor(
        beatWith(chop: ChopPattern.empty().withStep(0, 5)),
      );
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
        beatWith(
          chop: ChopPattern.empty().withStep(0, 15).withStep(1, 0),
        ),
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
        beatWith(chop: ChopPattern(List<int?>.filled(16, 99))),
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
}
