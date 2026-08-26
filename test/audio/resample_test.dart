import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/resample.dart';

/// Level of [frequency] in [samples], in dB relative to full scale, by
/// Goertzel. One bin, no FFT, which is all a test that knows what it put in
/// needs.
double _levelDb(
  Float32List samples, {
  required int channels,
  required int channel,
  required int sampleRate,
  required double frequency,
  int skip = 0,
}) {
  final frames = samples.length ~/ channels - skip * 2;
  final w = 2 * math.pi * frequency / sampleRate;
  final coeff = 2 * math.cos(w);
  var s1 = 0.0;
  var s2 = 0.0;
  for (var f = 0; f < frames; f++) {
    final s = samples[(f + skip) * channels + channel] + coeff * s1 - s2;
    s2 = s1;
    s1 = s;
  }
  final real = s1 - s2 * math.cos(w);
  final imag = s2 * math.sin(w);
  final magnitude = 2 * math.sqrt(real * real + imag * imag) / frames;
  return 20 * math.log(magnitude.clamp(1e-12, 2.0)) / math.ln10;
}

AudioClip _tone(double frequency, {required int rate, required int frames}) {
  final samples = Float32List(frames * 2);
  for (var f = 0; f < frames; f++) {
    final v = math.sin(2 * math.pi * frequency * f / rate);
    samples[f * 2] = v;
    samples[f * 2 + 1] = v;
  }
  return AudioClip(samples: samples, channels: 2, sampleRate: rate);
}

void main() {
  group('resample', () {
    test('the rates already agreeing is not a copy', () {
      final clip = _tone(1000, rate: 44100, frames: 128);
      expect(identical(clip.resampledTo(44100), clip), isTrue);
    });

    test('halving the rate halves the frame count', () {
      final clip = AudioClip.silent(
        frames: 1000,
        sampleRate: 44100,
      ).resampledTo(22050);
      expect(clip.sampleRate, 22050);
      expect(clip.frames, 500);
    });

    test('DC comes out at the level it went in', () {
      final samples = Float32List(4410 * 2);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = 0.5;
      }
      final out = AudioClip(
        samples: samples,
        channels: 2,
        sampleRate: 44100,
      ).resampledTo(48000);

      // Away from the ends, where the kernel runs off the clip and the level
      // is meant to fall.
      for (var f = 200; f < out.frames - 200; f++) {
        expect(out.samples[f * 2], closeTo(0.5, 1e-5));
        expect(out.samples[f * 2 + 1], closeTo(0.5, 1e-5));
      }
    });

    test('44100 to 48000 reproduces the tone rather than an approximation', () {
      final out = _tone(1000, rate: 44100, frames: 44100).resampledTo(48000);
      expect(out.sampleRate, 48000);

      var worst = 0.0;
      for (var f = 200; f < out.frames - 200; f++) {
        final want = math.sin(2 * math.pi * 1000 * f / 48000);
        final error = (out.samples[f * 2] - want).abs();
        if (error > worst) worst = error;
      }
      // Linear interpolation is around 5e-3 here and gets worse with pitch.
      expect(worst, lessThan(5e-4));
    });

    test('the top of the band survives going up', () {
      final out = _tone(15000, rate: 44100, frames: 44100).resampledTo(48000);
      final level = _levelDb(
        out.samples,
        channels: 2,
        channel: 0,
        sampleRate: 48000,
        frequency: 15000,
        skip: 200,
      );
      expect(level, closeTo(0, 0.1));
    });

    test('going down folds nothing back into the music', () {
      // 15 kHz cannot exist at 22050 and would land on 7050 if it were simply
      // dropped. That fold is what linear interpolation does, at about -20 dB,
      // and it is why a downsampled break sounds like it has a whistle in it.
      final out = _tone(15000, rate: 44100, frames: 44100).resampledTo(22050);
      final alias = _levelDb(
        out.samples,
        channels: 2,
        channel: 0,
        sampleRate: 22050,
        frequency: 7050,
        skip: 200,
      );
      expect(alias, lessThan(-80));
    });

    test('going down keeps what is under the new Nyquist', () {
      final out = _tone(5000, rate: 44100, frames: 44100).resampledTo(22050);
      final level = _levelDb(
        out.samples,
        channels: 2,
        channel: 0,
        sampleRate: 22050,
        frequency: 5000,
        skip: 200,
      );
      expect(level, closeTo(0, 0.1));
    });

    test('channels do not leak into each other', () {
      final samples = Float32List(44100 * 2);
      for (var f = 0; f < 44100; f++) {
        samples[f * 2] = math.sin(2 * math.pi * 1000 * f / 44100);
        samples[f * 2 + 1] = math.sin(2 * math.pi * 6000 * f / 44100);
      }
      final out = AudioClip(
        samples: samples,
        channels: 2,
        sampleRate: 44100,
      ).resampledTo(48000);

      double at(int channel, double frequency) => _levelDb(
        out.samples,
        channels: 2,
        channel: channel,
        sampleRate: 48000,
        frequency: frequency,
        skip: 200,
      );

      expect(at(0, 1000), closeTo(0, 0.1));
      expect(at(0, 6000), lessThan(-80));
      expect(at(1, 6000), closeTo(0, 0.1));
      expect(at(1, 1000), lessThan(-80));
    });

    test('the isolate returns exactly what the main one would have', () async {
      final clip = _tone(1000, rate: 44100, frames: 4410);
      final here = clip.resampledTo(48000);
      final there = await clip.resampledToOffThread(48000);

      expect(there.sampleRate, 48000);
      expect(there.channels, 2);
      expect(there.samples, orderedEquals(here.samples));
    });

    test('mono goes through the same filter as stereo', () {
      final mono = Float32List(44100);
      for (var f = 0; f < 44100; f++) {
        mono[f] = math.sin(2 * math.pi * 1000 * f / 44100);
      }
      final out = resampleInterleaved(
        mono,
        channels: 1,
        inRate: 44100,
        outRate: 48000,
      );

      var worst = 0.0;
      for (var f = 200; f < out.length - 200; f++) {
        final want = math.sin(2 * math.pi * 1000 * f / 48000);
        final error = (out[f] - want).abs();
        if (error > worst) worst = error;
      }
      expect(worst, lessThan(5e-4));
    });
  });
}
