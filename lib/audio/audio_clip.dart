import 'dart:typed_data';

import 'package:junglengine/audio/resample.dart';

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

  /// Resamples to [rate], band limited. See `resample.dart`: this is on the
  /// load path for every clip under the Lira engine, because a phone runs the
  /// output at whatever rate it likes and the app follows it.
  AudioClip resampledTo(int rate) {
    if (rate == sampleRate) return this;
    return AudioClip(
      samples: resampleInterleaved(
        samples,
        channels: channels,
        inRate: sampleRate,
        outRate: rate,
      ),
      channels: channels,
      sampleRate: rate,
    );
  }

  /// The same conversion, on another isolate. For an import, which can be
  /// three minutes long; a bundled clip is seconds long and uses the one
  /// above.
  Future<AudioClip> resampledToOffThread(int rate) async {
    if (rate == sampleRate) return this;
    return AudioClip(
      samples: await resampleInterleavedOffThread(
        samples,
        channels: channels,
        inRate: sampleRate,
        outRate: rate,
      ),
      channels: channels,
      sampleRate: rate,
    );
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
