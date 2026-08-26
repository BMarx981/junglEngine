// What replacing the linear resampler bought, and what it costs.
//
//   dart run tool/resample_bench.dart            # JIT, quick
//   dart compile exe tool/resample_bench.dart -o build/resample_bench
//   ./build/resample_bench                       # AOT, the honest number
//
// The AOT run is the one to quote: a release build of the app is AOT, and this
// runs at load time on a phone, once per clip.
//
// Two halves. The quality half puts a tone through both converters and reads
// off what came out. The cost half converts the bundled break the way the app
// does when the device runs at 48000. See docs/M4.md.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/wav.dart';

const String breakPath = 'assets/breaks/DnB_full02_loop_170.wav';
const int repeats = 5;

void main() {
  _quality();
  stdout.writeln();
  _cost();
}

void _quality() {
  stdout.writeln('quality');
  stdout.writeln('  1 kHz, 44100 -> 48000, worst sample error');
  final tone = _tone(1000, rate: 44100, frames: 44100);
  stdout.writeln(
    '    linear  ${_toneError(_linear(tone, 48000), 1000, 48000)}',
  );
  stdout.writeln(
    '    sinc    ${_toneError(tone.resampledTo(48000), 1000, 48000)}',
  );

  stdout.writeln('  15 kHz, 44100 -> 22050, level of the 7050 Hz fold');
  final high = _tone(15000, rate: 44100, frames: 44100);
  stdout.writeln('    linear  ${_db(_linear(high, 22050), 7050, 22050)} dB');
  stdout.writeln('    sinc    ${_db(high.resampledTo(22050), 7050, 22050)} dB');

  stdout.writeln('  15 kHz, 44100 -> 48000, level of the tone itself');
  stdout.writeln('    linear  ${_db(_linear(high, 48000), 15000, 48000)} dB');
  stdout.writeln(
    '    sinc    ${_db(high.resampledTo(48000), 15000, 48000)} dB',
  );
}

void _cost() {
  final file = File(breakPath);
  if (!file.existsSync()) {
    stdout.writeln('cost: no $breakPath, run from the repository root');
    return;
  }
  final clip = decodeWav(file.readAsBytesSync()).toStereo();
  final seconds = clip.frames / clip.sampleRate;
  stdout.writeln(
    'cost: ${seconds.toStringAsFixed(2)} s of stereo, '
    '${clip.sampleRate} -> 48000, best of $repeats',
  );

  Duration best(AudioClip Function() convert) {
    var best = const Duration(days: 1);
    for (var i = 0; i < repeats; i++) {
      final watch = Stopwatch()..start();
      final out = convert();
      watch.stop();
      if (out.frames == 0) throw StateError('nothing came out');
      if (watch.elapsed < best) best = watch.elapsed;
    }
    return best;
  }

  final linear = best(() => _linear(clip, 48000));
  final sinc = best(() => clip.resampledTo(48000));
  stdout.writeln('  linear  ${_ms(linear)} ms');
  stdout.writeln('  sinc    ${_ms(sinc)} ms');
}

String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);

/// What `AudioClip.resampledTo` was before stage 4: linear interpolation.
AudioClip _linear(AudioClip clip, int rate) {
  if (rate == clip.sampleRate) return clip;
  final channels = clip.channels;
  final frames = clip.frames;
  final ratio = clip.sampleRate / rate;
  final outFrames = (frames / ratio).floor();
  final out = Float32List(outFrames * channels);
  for (var f = 0; f < outFrames; f++) {
    final src = f * ratio;
    final i0 = src.floor();
    final i1 = i0 + 1 < frames ? i0 + 1 : i0;
    final t = src - i0;
    for (var c = 0; c < channels; c++) {
      final a = clip.samples[i0 * channels + c];
      final b = clip.samples[i1 * channels + c];
      out[f * channels + c] = a + (b - a) * t;
    }
  }
  return AudioClip(samples: out, channels: channels, sampleRate: rate);
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

String _toneError(AudioClip clip, double frequency, int rate) {
  var worst = 0.0;
  for (var f = 200; f < clip.frames - 200; f++) {
    final want = math.sin(2 * math.pi * frequency * f / rate);
    final error = (clip.samples[f * 2] - want).abs();
    if (error > worst) worst = error;
  }
  return worst.toStringAsExponential(2);
}

/// Level at [frequency] in dBFS, by Goertzel.
String _db(AudioClip clip, double frequency, int rate) {
  const skip = 200;
  final frames = clip.frames - skip * 2;
  final w = 2 * math.pi * frequency / rate;
  final coeff = 2 * math.cos(w);
  var s1 = 0.0;
  var s2 = 0.0;
  for (var f = 0; f < frames; f++) {
    final s = clip.samples[(f + skip) * 2] + coeff * s1 - s2;
    s2 = s1;
    s1 = s;
  }
  final real = s1 - s2 * math.cos(w);
  final imag = s2 * math.sin(w);
  final magnitude = 2 * math.sqrt(real * real + imag * imag) / frames;
  return (20 * math.log(magnitude.clamp(1e-12, 2.0)) / math.ln10)
      .toStringAsFixed(1);
}
