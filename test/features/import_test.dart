import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/features/import/audio_import.dart';
import 'package:junglengine/features/import/tap_tempo.dart';
import 'package:junglengine/features/import/waveform.dart';
import 'package:junglengine/features/library/import_store.dart';

/// A stereo clip of [frames] frames whose samples say where they came from, so
/// a trim can be checked by reading the audio rather than by counting bytes.
AudioClip ramp(int frames, {int sampleRate = 44100}) {
  final samples = Float32List(frames * 2);
  for (var f = 0; f < frames; f++) {
    samples[f * 2] = f / frames;
    samples[f * 2 + 1] = -f / frames;
  }
  return AudioClip(samples: samples, channels: 2, sampleRate: sampleRate);
}

void main() {
  group('trim and tempo', () {
    const rate = 44100;

    test('a one bar trim at 170 BPM is the length 170 BPM says it is', () {
      // One bar of four beats at 170 BPM is 60 * 4 / 170 seconds.
      final frames = TrimSelection.framesFor(
        bpm: 170,
        bars: 1,
        sampleRate: rate,
      );
      expect(frames, (rate * 4 * 60 / 170).round());

      final trim = TrimSelection(startFrame: 0, lengthFrames: frames, bars: 1);
      expect(trim.bpmAt(rate), closeTo(170, 0.01));
    });

    test('the same region read as two bars is half the tempo', () {
      const length = 62235;
      const one = TrimSelection(startFrame: 0, lengthFrames: length, bars: 1);
      const two = TrimSelection(startFrame: 0, lengthFrames: length, bars: 2);
      expect(two.bpmAt(rate), closeTo(one.bpmAt(rate) * 2, 0.001));
    });

    test('tempo and length are inverses of each other', () {
      for (final bpm in [88.0, 140.0, 172.5, 200.0]) {
        for (final bars in [1, 2, 4, 8]) {
          final frames = TrimSelection.framesFor(
            bpm: bpm,
            bars: bars,
            sampleRate: rate,
          );
          final back = TrimSelection(
            startFrame: 0,
            lengthFrames: frames,
            bars: bars,
          ).bpmAt(rate);
          expect(back, closeTo(bpm, 0.01), reason: '$bpm at $bars bars');
        }
      }
    });

    test('slicing takes exactly the trimmed region', () {
      final clip = ramp(1000);
      final slice = sliceOf(
        clip,
        const TrimSelection(startFrame: 200, lengthFrames: 300, bars: 1),
      );
      expect(slice.frames, 300);
      expect(slice.samples[0], closeTo(0.2, 1e-6));
      expect(slice.samples[299 * 2], closeTo(0.499, 1e-3));
    });

    test('a trim running past the end stops at the end', () {
      final clip = ramp(1000);
      final slice = sliceOf(
        clip,
        const TrimSelection(startFrame: 900, lengthFrames: 500, bars: 1),
      );
      expect(slice.frames, 100);
    });
  });

  group('one shot conditioning', () {
    test('silence is trimmed off both ends', () {
      final samples = Float32List(1000 * 2);
      for (var f = 300; f < 500; f++) {
        samples[f * 2] = 0.5;
        samples[f * 2 + 1] = 0.5;
      }
      final clip = AudioClip(samples: samples, channels: 2, sampleRate: 44100);
      final trimmed = trimSilence(clip);
      expect(trimmed.frames, 200);
      expect(trimmed.samples[0], closeTo(0.5, 1e-6));
    });

    test('a clip that is silent all through is left alone', () {
      final clip = AudioClip.silent(frames: 500);
      expect(trimSilence(clip).frames, 500);
    });
  });

  group('import names', () {
    test('a file name becomes a file safe slug', () {
      expect(ImportStore.slug('Amen Break (170).wav'), 'amen-break-170');
      expect(ImportStore.slug('../../etc/passwd'), 'etc-passwd');
      expect(ImportStore.slug('%%%.mp3'), 'import');
    });

    test('the display name drops the extension and stays short', () {
      expect(ImportStore.displayName('Think Break.aiff'), 'Think Break');
      expect(ImportStore.displayName('/tmp/a/b/Apache.mp3'), 'Apache');
      expect(ImportStore.displayName('x' * 60).length, 24);
    });

    test('a slot label is four upper case characters', () {
      expect(ImportStore.slotLabel('my kick.wav'), 'MYKI');
      expect(ImportStore.slotLabel('808.wav'), '808');
      expect(ImportStore.slotLabel('___.wav'), 'USER');
    });
  });

  group('tap tempo', () {
    test('one tap is not a tempo', () {
      final taps = TapTempo();
      expect(taps.tap(Duration.zero), isNull);
      expect(taps.hasTempo, isFalse);
    });

    test('four taps at 120 BPM read as 120 BPM', () {
      final taps = TapTempo();
      double? bpm;
      for (var i = 0; i < 4; i++) {
        bpm = taps.tap(Duration(milliseconds: 500 * i));
      }
      expect(bpm, closeTo(120, 0.001));
    });

    test('a long pause starts the count again', () {
      final taps = TapTempo();
      taps.tap(Duration.zero);
      taps.tap(const Duration(milliseconds: 500));
      // Three seconds later is a new count in, not a very slow beat.
      expect(taps.tap(const Duration(seconds: 4)), isNull);
      expect(taps.taps, 1);
    });

    test('only the last few taps count, so a drift can be corrected', () {
      final taps = TapTempo();
      var at = Duration.zero;
      // Four taps at 100 BPM, then six at 170. The window has moved on by then.
      for (var i = 0; i < 4; i++) {
        at += const Duration(milliseconds: 600);
        taps.tap(at);
      }
      double? bpm;
      for (var i = 0; i < 6; i++) {
        at += const Duration(microseconds: 352941);
        bpm = taps.tap(at);
      }
      expect(bpm, closeTo(170, 0.5));
    });
  });

  group('waveform', () {
    test('peaks cover the whole clip and keep the extremes', () {
      final samples = Float32List(400 * 2);
      for (var f = 0; f < 400; f++) {
        samples[f * 2] = sin(f / 20) * 0.8;
        samples[f * 2 + 1] = -sin(f / 20) * 0.8;
      }
      final peaks = WaveformPeaks.of(
        AudioClip(samples: samples, channels: 2, sampleRate: 44100),
        columns: 40,
      );
      expect(peaks.columns, 40);
      expect(peaks.highs.reduce(max), closeTo(0.8, 0.02));
      expect(peaks.lows.reduce(min), closeTo(-0.8, 0.02));
    });

    test('a clip shorter than the column count does not invent columns', () {
      final peaks = WaveformPeaks.of(ramp(7), columns: 100);
      expect(peaks.columns, 7);
    });
  });
}
