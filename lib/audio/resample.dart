import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// Band limited sample rate conversion.
///
/// This used to be linear interpolation, on the reasoning that it only ever
/// ran on the odd asset that was not already at 44100. The Lira engine ended
/// that reasoning: cpal takes the rate the hardware is running at rather than
/// asking for one, and a phone that runs at 48000 puts every bundled break,
/// every one shot and every import through here. See docs/M4.md.
///
/// Linear interpolation between two samples is a triangular filter, and a
/// triangular filter is roughly 6 dB of rejection at Nyquist: going up it
/// leaves the images audible as a dull top end, and going down it folds
/// everything above the new Nyquist back into the music. On a break, which is
/// mostly cymbals and snare transients, that is exactly the material it does
/// the most damage to.
///
/// What replaces it is the ordinary answer: a Kaiser windowed sinc, evaluated
/// per output frame from one shared table. Flat to 20 kHz at 44.1, images and
/// aliases below -90 dB, and it costs a few tens of milliseconds per break at
/// load time rather than anything in the callback. Nothing here runs on the
/// audio thread in either engine; clips are converted once, when they load.

/// Half the kernel width, in zero crossings of the sinc.
///
/// 32 either side is 64 taps at unity ratio. With the window below that puts
/// the transition band between 20 kHz and 22.05 kHz at 44100, which is the
/// point: the part of the band a person can hear stays flat, and the roll off
/// happens in the octave above it where there is nothing to lose.
const int _zeroCrossings = 32;

/// Kaiser beta. 9.0 is about 90 dB of stopband, which is past 16 bit.
const double _kaiserBeta = 9.0;

/// Table points per zero crossing. The table is read at a fractional index and
/// interpolated between neighbours, so this is what decides how much error the
/// *table lookup* adds on top of the filter, and at 512 it is nothing.
const int _phasesPerCrossing = 512;

/// Resamples interleaved float frames from [inRate] to [outRate].
///
/// Returns [input] itself when the rates already agree, which is the common
/// case and the reason the bundled assets are all 44100.
Float32List resampleInterleaved(
  Float32List input, {
  required int channels,
  required int inRate,
  required int outRate,
}) {
  assert(channels > 0);
  assert(inRate > 0 && outRate > 0);
  if (inRate == outRate) return input;

  final inFrames = input.length ~/ channels;
  final outFrames = inFrames * outRate ~/ inRate;
  final out = Float32List(outFrames * channels);
  if (outFrames == 0 || inFrames == 0) return out;

  final kernel = _SincKernel.shared;

  // Input frames per output frame.
  final step = inRate / outRate;

  // Going down, the filter has to cut at the *new* Nyquist rather than the old
  // one, which means stretching the same kernel over more input samples. Going
  // up, the input is already band limited and the kernel stays as it is.
  final scale = outRate < inRate ? outRate / inRate : 1.0;
  final halfWidth = (_zeroCrossings / scale).ceil();

  // Distance in input frames -> index into the table.
  final indexScale = scale * _phasesPerCrossing;

  if (channels == 2) {
    _resampleStereo(
      input,
      out,
      inFrames,
      outFrames,
      step,
      halfWidth,
      indexScale,
      kernel,
    );
  } else {
    _resampleAny(
      input,
      out,
      channels,
      inFrames,
      outFrames,
      step,
      halfWidth,
      indexScale,
      kernel,
    );
  }
  return out;
}

/// The hot path: everything the mixer ever sees is stereo by the time it gets
/// here, because `AudioClip.toStereo` runs first.
void _resampleStereo(
  Float32List input,
  Float32List out,
  int inFrames,
  int outFrames,
  double step,
  int halfWidth,
  double indexScale,
  _SincKernel kernel,
) {
  final table = kernel.values;
  final delta = kernel.deltas;
  final last = kernel.length - 1;

  for (var f = 0; f < outFrames; f++) {
    final pos = f * step;
    final centre = pos.floor();
    var left = 0.0;
    var right = 0.0;
    var weightSum = 0.0;

    for (var j = centre - halfWidth + 1; j <= centre + halfWidth; j++) {
      final x = (pos - j).abs() * indexScale;
      final i = x.toInt();
      if (i >= last) continue;
      final w = table[i] + delta[i] * (x - i);

      // The weights outside the clip count towards the sum even though there
      // is no sample to multiply them by, so the first and last few frames
      // fade rather than being lifted back to full level by the division.
      weightSum += w;
      if (j < 0 || j >= inFrames) continue;
      final at = j * 2;
      left += w * input[at];
      right += w * input[at + 1];
    }

    if (weightSum != 0) {
      final norm = 1.0 / weightSum;
      left *= norm;
      right *= norm;
    }
    final at = f * 2;
    out[at] = left;
    out[at + 1] = right;
  }
}

/// Mono, or something wider that has not been folded down yet.
void _resampleAny(
  Float32List input,
  Float32List out,
  int channels,
  int inFrames,
  int outFrames,
  double step,
  int halfWidth,
  double indexScale,
  _SincKernel kernel,
) {
  final table = kernel.values;
  final delta = kernel.deltas;
  final last = kernel.length - 1;
  final sums = Float64List(channels);

  for (var f = 0; f < outFrames; f++) {
    final pos = f * step;
    final centre = pos.floor();
    sums.fillRange(0, channels, 0);
    var weightSum = 0.0;

    for (var j = centre - halfWidth + 1; j <= centre + halfWidth; j++) {
      final x = (pos - j).abs() * indexScale;
      final i = x.toInt();
      if (i >= last) continue;
      final w = table[i] + delta[i] * (x - i);

      weightSum += w;
      if (j < 0 || j >= inFrames) continue;
      final at = j * channels;
      for (var c = 0; c < channels; c++) {
        sums[c] += w * input[at + c];
      }
    }

    final norm = weightSum != 0 ? 1.0 / weightSum : 0.0;
    final at = f * channels;
    for (var c = 0; c < channels; c++) {
      out[at + c] = sums[c] * norm;
    }
  }
}

/// One half of a Kaiser windowed sinc, sampled densely, plus the differences
/// between neighbours so a lookup is one multiply.
///
/// It does not depend on the ratio -- the ratio only decides how fast the
/// table is read -- so it is built once for the life of the process and every
/// clip that loads shares it. About 500 kB.
class _SincKernel {
  _SincKernel._(this.values, this.deltas);

  final Float64List values;
  final Float64List deltas;

  int get length => values.length;

  static final _SincKernel shared = _build();

  static _SincKernel _build() {
    const points = _zeroCrossings * _phasesPerCrossing;
    final values = Float64List(points + 1);
    final deltas = Float64List(points + 1);
    final scale = 1.0 / _besselI0(_kaiserBeta);

    for (var i = 0; i <= points; i++) {
      final t = i / _phasesPerCrossing;
      final sinc = i == 0 ? 1.0 : math.sin(math.pi * t) / (math.pi * t);
      final r = t / _zeroCrossings;
      final window = i == points
          ? 0.0
          : _besselI0(_kaiserBeta * math.sqrt(1 - r * r)) * scale;
      values[i] = sinc * window;
    }
    for (var i = 0; i < points; i++) {
      deltas[i] = values[i + 1] - values[i];
    }
    return _SincKernel._(values, deltas);
  }
}

/// Modified Bessel function of the first kind, order zero, by its series.
/// Converges in well under thirty terms for the betas a window uses.
double _besselI0(double x) {
  var sum = 1.0;
  var term = 1.0;
  final half = x / 2;
  for (var k = 1; k < 40; k++) {
    term *= half / k;
    final next = term * term;
    sum += next;
    if (next < sum * 1e-17) break;
  }
  return sum;
}

/// The same conversion, on another isolate.
///
/// An import is up to three minutes of audio and the filter is sixty four taps
/// per output frame, which is close to a second of work on a phone: long
/// enough to drop frames if it ran where the UI does. Bundled breaks and one
/// shots are seconds long and go through the synchronous path at load.
///
/// The samples are handed over rather than copied on the way back, so a three
/// minute import does not briefly exist twice.
Future<Float32List> resampleInterleavedOffThread(
  Float32List input, {
  required int channels,
  required int inRate,
  required int outRate,
}) async {
  if (inRate == outRate) return input;
  final sent = TransferableTypedData.fromList([input]);
  final received = await Isolate.run(() {
    final samples = sent.materialize().asFloat32List();
    return TransferableTypedData.fromList([
      resampleInterleaved(
        samples,
        channels: channels,
        inRate: inRate,
        outRate: outRate,
      ),
    ]);
  });
  return received.materialize().asFloat32List();
}
