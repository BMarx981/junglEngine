// Generates the bundled Hawkstreak breaks.
//
// Original content, synthesised from scratch, so junglEngine has something to
// chop with no sample clearance attached to it. Drop a real break into
// assets/breaks/ and register it in BreakLibrary to add to these.
//
//   dart run tool/make_break.dart
//
// Five of them, and deliberately five different shapes rather than five
// versions of the same bar: a one bar amen, a one bar half time stepper, and a
// two bar roller in the free starter pack, then a two bar break with the
// backbeat displaced and a one bar broken beat in the Nightshift pack. The two
// bar ones are also what prove slice divisions are per bar and not per break.
//
// The last two are Pro content. Nothing about generating them differs -- a pack
// is a grouping in PackLibrary, not a different kind of file -- but they use
// their own voices, because a pack somebody paid for should not be the same
// four drums in a new order.
//
// See LICENSING.md and docs/PACKS.md.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:junglengine/audio/wav.dart';

const int sampleRate = 44100;
const double bpm = 170;

void main() {
  _write(
    path: 'assets/breaks/hawkstreak_amenish_170.wav',
    bars: 1,
    seed: 1974,
    build: _amenish,
  );
  _write(
    path: 'assets/breaks/hawkstreak_steppa_170.wav',
    bars: 1,
    seed: 1991,
    build: _steppa,
  );
  _write(
    path: 'assets/breaks/hawkstreak_roller_170.wav',
    bars: 2,
    seed: 1996,
    build: _roller,
  );

  // The Nightshift pack.
  _write(
    path: 'assets/breaks/hawkstreak_duppy_170.wav',
    bars: 2,
    seed: 1993,
    build: _duppy,
  );
  _write(
    path: 'assets/breaks/hawkstreak_lurch_170.wav',
    bars: 1,
    seed: 1997,
    build: _lurch,
  );
}

/// A break being built: the mix, and where its steps fall.
class _Take {
  _Take({required this.mix, required this.stepFrames, required this.random});

  final Float32List mix;
  final double stepFrames;
  final math.Random random;

  void at(int step, Float32List voice, {double gain = 1, double pan = 0}) {
    _mixInto(mix, voice, (step * stepFrames).round(), gain: gain, pan: pan);
  }
}

void _write({
  required String path,
  required int bars,
  required int seed,
  required void Function(_Take take) build,
}) {
  final frames = (sampleRate * 4 * bars * 60 / bpm).round();
  final mix = Float32List(frames * 2);
  build(
    _Take(
      mix: mix,
      stepFrames: frames / (16.0 * bars),
      random: math.Random(seed),
    ),
  );

  _room(mix);
  _saturate(mix);
  _normalize(mix, 0.92);
  _wrapTail(mix);

  File(
    path,
  ).writeAsBytesSync(encodeWav(mix, sampleRate: sampleRate, channels: 2));
  stdout.writeln(
    'wrote $path  '
    '$frames frames  ${(frames / sampleRate).toStringAsFixed(3)}s  '
    '$bars bar${bars == 1 ? '' : 's'}  ${bpm.toStringAsFixed(0)} bpm',
  );
}

/// A straight, amen shaped bar. Kick, backbeat, ghosts on the pickups, eighth
/// note hats. Sliced into 16 this gives one hit per row.
void _amenish(_Take take) {
  final random = take.random;
  final kick = _kick(random);
  final snare = _snare(random, 1.0);
  final ghost = _snare(random, 0.34, short: true);
  final hat = _hat(random, open: false);
  final openHat = _hat(random, open: true);

  take.at(0, kick, gain: 1.0);
  take.at(10, kick, gain: 0.94);
  take.at(3, kick, gain: 0.42);

  take.at(4, snare, gain: 1.0);
  take.at(12, snare, gain: 0.98);

  take.at(7, ghost, gain: 0.8, pan: -0.12);
  take.at(11, ghost, gain: 0.62, pan: 0.15);
  take.at(14, ghost, gain: 0.9, pan: -0.05);
  take.at(15, ghost, gain: 0.5, pan: 0.2);

  for (var step = 0; step < 16; step += 2) {
    if (step == 8) continue;
    take.at(step, hat, gain: step % 4 == 0 ? 0.5 : 0.34, pan: 0.22);
  }
  take.at(8, openHat, gain: 0.46, pan: 0.26);
}

/// Half time: one backbeat on step 8 instead of two on 4 and 12, so the same
/// tempo reads at half the speed. This is the one to chop when a tune needs to
/// drop into something heavier.
void _steppa(_Take take) {
  final random = take.random;
  final kick = _kick(random);
  final snare = _snare(random, 1.0);
  final ghost = _snare(random, 0.3, short: true);
  final hat = _hat(random, open: false);
  final openHat = _hat(random, open: true);

  take.at(0, kick, gain: 1.0);
  take.at(11, kick, gain: 0.66);

  take.at(8, snare, gain: 1.0);

  take.at(14, ghost, gain: 0.55, pan: -0.14);
  take.at(15, ghost, gain: 0.34, pan: 0.18);

  for (var step = 0; step < 16; step += 2) {
    if (step == 6) continue;
    take.at(step, hat, gain: step % 4 == 0 ? 0.46 : 0.3, pan: 0.2);
  }
  take.at(6, openHat, gain: 0.42, pan: 0.24);
}

/// Two bars that do not repeat: the second drops a backbeat and rolls into the
/// turnaround. At 16 divisions this is 32 rows, which is the grid a longer
/// break was worth building paging for.
void _roller(_Take take) {
  final random = take.random;
  final kick = _kick(random);
  final snare = _snare(random, 1.0);
  final ghost = _snare(random, 0.36, short: true);
  final hat = _hat(random, open: false);
  final openHat = _hat(random, open: true);

  // Bar one: the statement.
  take.at(0, kick, gain: 1.0);
  take.at(10, kick, gain: 0.9);
  take.at(4, snare, gain: 1.0);
  take.at(12, snare, gain: 0.96);
  take.at(3, ghost, gain: 0.5, pan: -0.1);
  take.at(7, ghost, gain: 0.78, pan: 0.12);
  take.at(14, ghost, gain: 0.66, pan: -0.06);

  // Bar two: the answer. The kick pushes onto the offbeat and the last
  // backbeat is replaced by a drag into the top of the loop.
  take.at(16, kick, gain: 0.98);
  take.at(22, kick, gain: 0.82);
  take.at(26, kick, gain: 0.5);
  take.at(20, snare, gain: 1.0);
  take.at(27, ghost, gain: 0.7, pan: 0.1);
  take.at(29, ghost, gain: 0.86, pan: -0.12);
  take.at(30, ghost, gain: 0.6, pan: 0.16);
  take.at(31, ghost, gain: 0.44, pan: -0.2);

  for (var step = 0; step < 32; step += 2) {
    if (step == 8 || step == 24) continue;
    take.at(step, hat, gain: step % 4 == 0 ? 0.48 : 0.32, pan: 0.22);
  }
  take.at(8, openHat, gain: 0.44, pan: 0.26);
  take.at(24, openHat, gain: 0.5, pan: 0.26);
}

// --- The Nightshift pack ----------------------------------------------------
//
// Two breaks that are not shapes the starter pack already has. The starter
// breaks all put a backbeat where a backbeat goes; these two do not, which is
// the point of them: a chopper wants raw material that is already awkward,
// because the awkward hits are the ones worth moving.

/// Two bars with the backbeat displaced, and no kick on the top of bar two.
///
/// The hole where the downbeat should be is the whole break. Painting a slice
/// onto step 16 puts it back, which is a thing you can only do if the source
/// left the room for it.
void _duppy(_Take take) {
  final random = take.random;
  final kick = _subKick(random);
  final snare = _crack(random, 1.0);
  final ghost = _crack(random, 0.3, short: true);
  final hat = _hat(random, open: false);
  final openHat = _hat(random, open: true);

  // Bar one: the backbeat is late on both halves, on 5 and 13 rather than 4
  // and 12, so the bar leans forward the whole way through.
  take.at(0, kick, gain: 1.0);
  take.at(6, kick, gain: 0.72);
  take.at(10, kick, gain: 0.9);
  take.at(5, snare, gain: 1.0);
  take.at(13, snare, gain: 0.94);
  take.at(3, ghost, gain: 0.52, pan: -0.14);
  take.at(8, ghost, gain: 0.44, pan: 0.16);
  take.at(15, ghost, gain: 0.72, pan: -0.08);

  // Bar two: nothing on 16. The first kick of the bar arrives on 18 and the
  // snare goes back where it belongs, so the bar lands the moment it stops
  // being late.
  take.at(18, kick, gain: 0.96);
  take.at(24, kick, gain: 0.84);
  take.at(28, kick, gain: 0.56);
  take.at(20, snare, gain: 1.0);
  take.at(29, snare, gain: 0.78);
  take.at(22, ghost, gain: 0.6, pan: 0.12);
  take.at(26, ghost, gain: 0.5, pan: -0.16);
  take.at(31, ghost, gain: 0.66, pan: 0.2);

  for (var step = 2; step < 32; step += 2) {
    if (step == 14 || step == 22) continue;
    take.at(step, hat, gain: step % 4 == 0 ? 0.42 : 0.28, pan: 0.24);
  }
  take.at(14, openHat, gain: 0.46, pan: 0.28);
  take.at(22, openHat, gain: 0.4, pan: 0.28);
}

/// One bar that stumbles: kicks in threes against a snare that lands early.
///
/// Sixteen steps grouped 3-3-3-3-4 instead of 4-4-4-4. Chopped at 16 every row
/// is a hit, and the rows are not the ones a straight break would give you.
void _lurch(_Take take) {
  final random = take.random;
  final kick = _subKick(random);
  final snare = _crack(random, 1.0);
  final ghost = _crack(random, 0.32, short: true);
  final hat = _hat(random, open: false);
  final openHat = _hat(random, open: true);

  take.at(0, kick, gain: 1.0);
  take.at(3, kick, gain: 0.62);
  take.at(9, kick, gain: 0.88);

  // On 6, which is neither 4 nor 8. Two steps early against a backbeat and two
  // steps late against a half time one.
  take.at(6, snare, gain: 1.0);
  take.at(11, snare, gain: 0.7);

  take.at(13, ghost, gain: 0.66, pan: -0.16);
  take.at(14, ghost, gain: 0.48, pan: 0.18);
  take.at(15, ghost, gain: 0.8, pan: -0.06);

  for (final step in [0, 3, 6, 9, 12]) {
    take.at(step, hat, gain: step == 0 ? 0.48 : 0.32, pan: 0.22);
  }
  take.at(12, openHat, gain: 0.44, pan: 0.26);
}

/// Longer and lower than [_kick], with the click taken off it.
///
/// The Nightshift breaks are meant to be chopped short, and a kick with a
/// transient spike survives being cut at the eighth note in a way a rounder one
/// does not: the spike is what you hear, so the slice still reads as a kick.
Float32List _subKick(math.Random random) {
  final n = (sampleRate * 0.44).round();
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final freq = 40.0 + 104.0 * math.exp(-t * 40);
    phase += freq / sampleRate;
    final body = math.sin(2 * math.pi * phase) * math.exp(-t * 9);
    final thud = (random.nextDouble() * 2 - 1) * math.exp(-t * 280) * 0.16;
    out[i] = _tanh((body + thud) * 1.6) * 0.95;
  }
  return out;
}

/// A snare with the body pulled out and the crack left in.
///
/// Higher and drier than [_snare], so it cuts through a break that is already
/// busy underneath it and so a reversed slice of it reads as a reverse rather
/// than as mud.
Float32List _crack(math.Random random, double weight, {bool short = false}) {
  final n = (sampleRate * (short ? 0.085 : 0.19)).round();
  final out = Float32List(n);
  final noiseDecay = short ? 74.0 : 26.0;
  var hp = 0.0;
  var previous = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final tone =
        (math.sin(2 * math.pi * 232 * t) +
            0.5 * math.sin(2 * math.pi * 412 * t)) *
        math.exp(-t * 58) *
        0.34;
    final white = random.nextDouble() * 2 - 1;
    // Steeper than the starter snare's highpass: less shell, more wire.
    hp = 0.93 * (hp + white - previous);
    previous = white;
    final noise = hp * math.exp(-t * noiseDecay) * 0.8;
    out[i] = _tanh((tone + noise) * 1.35) * weight;
  }
  return out;
}

Float32List _kick(math.Random random) {
  final n = (sampleRate * 0.34).round();
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final freq = 44.0 + 118.0 * math.exp(-t * 46);
    phase += freq / sampleRate;
    final body = math.sin(2 * math.pi * phase) * math.exp(-t * 15);
    final click = (random.nextDouble() * 2 - 1) * math.exp(-t * 620) * 0.3;
    out[i] = _tanh((body + click) * 1.35) * 0.95;
  }
  return out;
}

Float32List _snare(math.Random random, double weight, {bool short = false}) {
  final n = (sampleRate * (short ? 0.1 : 0.24)).round();
  final out = Float32List(n);
  final noiseDecay = short ? 62.0 : 21.0;
  final toneDecay = short ? 70.0 : 34.0;
  var hp = 0.0;
  var previous = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final tone =
        (math.sin(2 * math.pi * 186 * t) + 0.62 * math.sin(2 * math.pi * 331 * t)) *
        math.exp(-t * toneDecay) *
        0.42;
    final white = random.nextDouble() * 2 - 1;
    // One pole highpass so the noise reads as a snare, not a kick.
    hp = 0.86 * (hp + white - previous);
    previous = white;
    final noise = hp * math.exp(-t * noiseDecay) * 0.72;
    out[i] = _tanh((tone + noise) * 1.2) * weight;
  }
  return out;
}

Float32List _hat(math.Random random, {required bool open}) {
  final n = (sampleRate * (open ? 0.3 : 0.055)).round();
  final out = Float32List(n);
  final decay = open ? 13.0 : 108.0;
  var hp1 = 0.0;
  var hp2 = 0.0;
  var p1 = 0.0;
  var p2 = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final white = random.nextDouble() * 2 - 1;
    hp1 = 0.965 * (hp1 + white - p1);
    p1 = white;
    hp2 = 0.965 * (hp2 + hp1 - p2);
    p2 = hp1;
    out[i] = hp2 * math.exp(-t * decay) * 0.8;
  }
  return out;
}

void _mixInto(
  Float32List target,
  Float32List voice,
  int atFrame, {
  double gain = 1,
  double pan = 0,
}) {
  final frames = target.length ~/ 2;
  final left = gain * (1 - pan.clamp(0.0, 1.0));
  final right = gain * (1 + pan.clamp(-1.0, 0.0));
  for (var i = 0; i < voice.length; i++) {
    final f = atFrame + i;
    if (f >= frames) break;
    target[f * 2] += voice[i] * left;
    target[f * 2 + 1] += voice[i] * right;
  }
}

/// A cheap room so slices have a tail to breathe into.
void _room(Float32List mix) {
  final frames = mix.length ~/ 2;
  final delays = [
    (sampleRate * 0.0231).round(),
    (sampleRate * 0.0317).round(),
    (sampleRate * 0.0411).round(),
  ];
  final gains = [0.16, 0.11, 0.08];
  final wet = Float32List(mix.length);
  for (var d = 0; d < delays.length; d++) {
    final delay = delays[d];
    final gain = gains[d];
    for (var f = delay; f < frames; f++) {
      wet[f * 2] += mix[(f - delay) * 2] * gain;
      wet[f * 2 + 1] += mix[(f - delay) * 2 + 1] * gain;
    }
  }
  for (var i = 0; i < mix.length; i++) {
    mix[i] += wet[i];
  }
}

void _saturate(Float32List mix) {
  for (var i = 0; i < mix.length; i++) {
    mix[i] = _tanh(mix[i] * 1.18) * 0.92;
  }
}

void _normalize(Float32List mix, double target) {
  var peak = 0.0;
  for (final v in mix) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  if (peak <= 0) return;
  final gain = target / peak;
  for (var i = 0; i < mix.length; i++) {
    mix[i] *= gain;
  }
}

/// Folds the last of the room tail back onto the head so the loop joins.
void _wrapTail(Float32List mix) {
  final frames = mix.length ~/ 2;
  final tail = (sampleRate * 0.05).round();
  for (var i = 0; i < tail; i++) {
    final fade = 1 - i / tail;
    mix[i * 2] += mix[(frames - tail + i) * 2] * fade * 0.5;
    mix[i * 2 + 1] += mix[(frames - tail + i) * 2 + 1] * fade * 0.5;
  }
}

double _tanh(double x) {
  if (x < -3) return -1;
  if (x > 3) return 1;
  final x2 = x * x;
  return x * (27 + x2) / (27 + 9 * x2);
}
