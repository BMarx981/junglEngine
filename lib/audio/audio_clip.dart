import 'dart:typed_data';

/// Decoded audio held as interleaved 32 bit float, which is the only shape the
/// mixer and the exporter ever deal with.
class AudioClip {
  AudioClip({
    required this.samples,
    required this.channels,
    required this.sampleRate,
  }) : assert(channels > 0),
       assert(sampleRate > 0);

  final Float32List samples;
  final int channels;
  final int sampleRate;

  int get frames => samples.length ~/ channels;

  AudioClip.silent({
    required int frames,
    this.channels = 2,
    this.sampleRate = 44100,
  }) : samples = Float32List(frames * channels);

  /// Duplicates mono to stereo, or folds anything wider down to stereo.
  AudioClip toStereo() {
    if (channels == 2) return this;
    final out = Float32List(frames * 2);
    for (var f = 0; f < frames; f++) {
      if (channels == 1) {
        final v = samples[f];
        out[f * 2] = v;
        out[f * 2 + 1] = v;
      } else {
        out[f * 2] = samples[f * channels];
        out[f * 2 + 1] = samples[f * channels + 1];
      }
    }
    return AudioClip(samples: out, channels: 2, sampleRate: sampleRate);
  }

  /// Linear resample. Only ever runs when a bundled break is not already at the
  /// engine rate, so quality here is not on the critical path.
  AudioClip resampledTo(int rate) {
    if (rate == sampleRate) return this;
    final ratio = sampleRate / rate;
    final outFrames = (frames / ratio).floor();
    final out = Float32List(outFrames * channels);
    for (var f = 0; f < outFrames; f++) {
      final src = f * ratio;
      final i0 = src.floor();
      final i1 = i0 + 1 < frames ? i0 + 1 : i0;
      final t = src - i0;
      for (var c = 0; c < channels; c++) {
        final a = samples[i0 * channels + c];
        final b = samples[i1 * channels + c];
        out[f * channels + c] = a + (b - a) * t;
      }
    }
    return AudioClip(samples: out, channels: channels, sampleRate: rate);
  }

  /// Peak normalise to [target]. Bundled breaks arrive at wildly different
  /// levels; this keeps the mixer's headroom assumptions honest.
  AudioClip normalized({double target = 0.89}) {
    var peak = 0.0;
    for (final s in samples) {
      final a = s.abs();
      if (a > peak) peak = a;
    }
    if (peak <= 0 || (peak - target).abs() < 0.001) return this;
    final gain = target / peak;
    final out = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      out[i] = samples[i] * gain;
    }
    return AudioClip(samples: out, channels: channels, sampleRate: sampleRate);
  }
}
