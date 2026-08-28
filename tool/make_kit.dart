// Generates the bundled Hawkstreak one shot kits.
//
// Original content, synthesised from scratch, so the Kit machine has something
// to play on day one with no sample clearance attached to it. Drop real one
// shots into assets/kits/<kit>/ under the same file names to replace these;
// nothing in the code has to change.
//
//   dart run tool/make_kit.dart
//
// Three kits: 01 is the bright one the Kit machine shipped with, 02 is the dark
// one, 03 is the metal one and is Pro content in the Nightshift pack. Same
// eight positions in all three, because slots are positional and a project that
// switches kit keeps its pattern -- including a project that switches from a
// free kit to a paid one, which is the point of them lining up.
//
// See LICENSING.md and docs/PACKS.md.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:junglengine/audio/wav.dart';

const int sampleRate = 44100;

/// Peak each voice is normalised to. This is the kit's mix balance: slot volume
/// starts at unity, so what is written here is what you hear before touching
/// anything.
const Map<String, double> _levels = {
  'kick': 0.97,
  'snare': 0.90,
  'rim': 0.62,
  'clap': 0.76,
  'hat_closed': 0.44,
  'hat_open': 0.52,
  'shaker': 0.38,
  'conga': 0.72,
};

/// The dark kit sits lower and quieter on top, so it can carry a busier
/// pattern without the hats taking over.
const Map<String, double> _darkLevels = {
  'kick': 0.98,
  'snare': 0.84,
  'rim': 0.58,
  'clap': 0.70,
  'hat_closed': 0.36,
  'hat_open': 0.44,
  'shaker': 0.32,
  'conga': 0.74,
};

/// The metal kit is the loudest of the three on top and the tightest at the
/// bottom: its kick is short, so it needs the level to land, and its hats are
/// meant to be heard through a break rather than under one.
const Map<String, double> _steelLevels = {
  'kick': 0.95,
  'snare': 0.92,
  'rim': 0.68,
  'clap': 0.72,
  'hat_closed': 0.50,
  'hat_open': 0.56,
  'shaker': 0.42,
  'conga': 0.70,
};

void main() {
  _write(
    directory: 'assets/kits/hawkstreak',
    prefix: 'hawkstreak',
    levels: _levels,
    voices: () {
      final random = math.Random(1994);
      return <String, Float32List>{
        'kick': _kick(random),
        'snare': _snare(random),
        'rim': _rim(random),
        'clap': _clap(random),
        'hat_closed': _hat(random, open: false),
        'hat_open': _hat(random, open: true),
        'shaker': _shaker(random),
        'conga': _conga(random),
      };
    },
  );

  _write(
    directory: 'assets/kits/hawkstreak02',
    prefix: 'hawkstreak02',
    levels: _darkLevels,
    voices: () {
      final random = math.Random(2026);
      return <String, Float32List>{
        'kick': _deepKick(random),
        'snare': _tightSnare(random),
        'rim': _woodRim(random),
        'clap': _gatedClap(random),
        'hat_closed': _darkHat(random, open: false),
        'hat_open': _darkHat(random, open: true),
        'shaker': _tambourine(random),
        'conga': _lowTom(random),
      };
    },
  );

  _write(
    directory: 'assets/kits/hawkstreak03',
    prefix: 'hawkstreak03',
    levels: _steelLevels,
    voices: () {
      final random = math.Random(1988);
      return <String, Float32List>{
        'kick': _steelKick(random),
        'snare': _ringSnare(random),
        'rim': _metalRim(random),
        'clap': _tightClap(random),
        'hat_closed': _sizzleHat(random, open: false),
        'hat_open': _sizzleHat(random, open: true),
        'shaker': _maraca(random),
        'conga': _highTom(random),
      };
    },
  );
}

void _write({
  required String directory,
  required String prefix,
  required Map<String, double> levels,
  required Map<String, Float32List> Function() voices,
}) {
  Directory(directory).createSync(recursive: true);
  voices().forEach((name, voice) {
    _fadeOut(voice);
    _normalize(voice, levels[name]!);
    final path = '$directory/${prefix}_$name.wav';
    File(
      path,
    ).writeAsBytesSync(encodeWav(voice, sampleRate: sampleRate, channels: 1));
    stdout.writeln(
      'wrote $path  ${voice.length} frames  '
      '${(voice.length / sampleRate).toStringAsFixed(3)}s',
    );
  });
}

Float32List _kick(math.Random random) {
  final n = _frames(0.40);
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    // Deep and long, because the sub lane sits under this and the two have to
    // share the bottom without fighting.
    final freq = 46.0 + 130.0 * math.exp(-t * 52);
    phase += freq / sampleRate;
    final body = math.sin(2 * math.pi * phase) * math.exp(-t * 11);
    final click = (random.nextDouble() * 2 - 1) * math.exp(-t * 700) * 0.28;
    out[i] = _tanh((body + click) * 1.45) * 0.95;
  }
  return out;
}

Float32List _snare(math.Random random) {
  final n = _frames(0.26);
  final out = Float32List(n);
  var hp = 0.0;
  var previous = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final tone =
        (math.sin(2 * math.pi * 188 * t) +
            0.6 * math.sin(2 * math.pi * 337 * t)) *
        math.exp(-t * 32) *
        0.44;
    final white = random.nextDouble() * 2 - 1;
    hp = 0.87 * (hp + white - previous);
    previous = white;
    final noise = hp * math.exp(-t * 20) * 0.78;
    out[i] = _tanh((tone + noise) * 1.25);
  }
  return out;
}

Float32List _rim(math.Random random) {
  final n = _frames(0.06);
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final tone =
        (math.sin(2 * math.pi * 1720 * t) +
            0.7 * math.sin(2 * math.pi * 2630 * t)) *
        math.exp(-t * 120);
    final click = (random.nextDouble() * 2 - 1) * math.exp(-t * 900) * 0.5;
    out[i] = _tanh((tone + click) * 1.1);
  }
  return out;
}

Float32List _clap(math.Random random) {
  final n = _frames(0.30);
  final out = Float32List(n);
  // Three fast bursts and then the room. That spacing is the whole trick.
  const bursts = [0.0, 0.011, 0.021];
  var hp = 0.0;
  var previous = 0.0;
  var lp = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var envelope = math.exp(-t * 9) * 0.55;
    for (final at in bursts) {
      if (t >= at) envelope += math.exp(-(t - at) * 260);
    }
    final white = random.nextDouble() * 2 - 1;
    hp = 0.9 * (hp + white - previous);
    previous = white;
    lp += (hp - lp) * 0.42;
    out[i] = _tanh(lp * envelope * 1.1);
  }
  return out;
}

Float32List _hat(math.Random random, {required bool open}) {
  final n = _frames(open ? 0.34 : 0.052);
  final out = Float32List(n);
  final decay = open ? 11.5 : 112.0;
  var hp1 = 0.0;
  var hp2 = 0.0;
  var p1 = 0.0;
  var p2 = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final white = random.nextDouble() * 2 - 1;
    hp1 = 0.968 * (hp1 + white - p1);
    p1 = white;
    hp2 = 0.968 * (hp2 + hp1 - p2);
    p2 = hp1;
    out[i] = hp2 * math.exp(-t * decay) * 0.85;
  }
  return out;
}

Float32List _shaker(math.Random random) {
  final n = _frames(0.10);
  final out = Float32List(n);
  var hp = 0.0;
  var previous = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final white = random.nextDouble() * 2 - 1;
    hp = 0.955 * (hp + white - previous);
    previous = white;
    // Soft attack: a shaker is grains hitting a shell, not a stick hitting a
    // head, and the ramp is what stops it reading as a hat.
    final attack = 1 - math.exp(-t * 260);
    out[i] = hp * attack * math.exp(-t * 46) * 0.9;
  }
  return out;
}

Float32List _conga(math.Random random) {
  final n = _frames(0.24);
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final freq = 196.0 + 58.0 * math.exp(-t * 90);
    phase += freq / sampleRate;
    final body =
        (math.sin(2 * math.pi * phase) + 0.22 * math.sin(4 * math.pi * phase)) *
        math.exp(-t * 17);
    final slap = (random.nextDouble() * 2 - 1) * math.exp(-t * 420) * 0.22;
    out[i] = _tanh((body + slap) * 1.2);
  }
  return out;
}

// --- Kit 02: the dark one ---------------------------------------------------
//
// Same eight positions, further down. A longer, softer kick with no click, a
// short flat snare, wood instead of metal, and hats with the top rolled off, so
// a pattern that is too bright on kit 01 sits under the break on this one.

Float32List _deepKick(math.Random random) {
  final n = _frames(0.52);
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    // Starts lower and falls further: this one is meant to be felt, and it is
    // the reason the sub lane on a kit 02 Beat wants to stay out of the way.
    final freq = 38.0 + 96.0 * math.exp(-t * 38);
    phase += freq / sampleRate;
    final body = math.sin(2 * math.pi * phase) * math.exp(-t * 7.5);
    final thud = (random.nextDouble() * 2 - 1) * math.exp(-t * 240) * 0.14;
    out[i] = _tanh((body + thud) * 1.7) * 0.95;
  }
  return out;
}

Float32List _tightSnare(math.Random random) {
  final n = _frames(0.16);
  final out = Float32List(n);
  var hp = 0.0;
  var previous = 0.0;
  var lp = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final tone = math.sin(2 * math.pi * 168 * t) * math.exp(-t * 46) * 0.5;
    final white = random.nextDouble() * 2 - 1;
    hp = 0.8 * (hp + white - previous);
    previous = white;
    // A lowpass on the noise takes the fizz off, which is what makes it sit
    // behind a break instead of fighting the break's own snare.
    lp += (hp - lp) * 0.35;
    out[i] = _tanh((tone + lp * math.exp(-t * 34) * 0.8) * 1.3);
  }
  return out;
}

Float32List _woodRim(math.Random random) {
  final n = _frames(0.05);
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final tone =
        (math.sin(2 * math.pi * 840 * t) +
            0.5 * math.sin(2 * math.pi * 1290 * t)) *
        math.exp(-t * 150);
    final knock = (random.nextDouble() * 2 - 1) * math.exp(-t * 1400) * 0.35;
    out[i] = _tanh((tone + knock) * 1.15);
  }
  return out;
}

Float32List _gatedClap(math.Random random) {
  final n = _frames(0.13);
  final out = Float32List(n);
  // Two bursts and a hard stop: a clap with the room cut off it, which is the
  // sound a gate leaves behind.
  const bursts = [0.0, 0.009];
  var hp = 0.0;
  var previous = 0.0;
  var lp = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var envelope = math.exp(-t * 46) * 0.5;
    for (final at in bursts) {
      if (t >= at) envelope += math.exp(-(t - at) * 300);
    }
    final white = random.nextDouble() * 2 - 1;
    hp = 0.88 * (hp + white - previous);
    previous = white;
    lp += (hp - lp) * 0.5;
    out[i] = _tanh(lp * envelope * 1.2);
  }
  return out;
}

Float32List _darkHat(math.Random random, {required bool open}) {
  final n = _frames(open ? 0.26 : 0.04);
  final out = Float32List(n);
  final decay = open ? 15.0 : 150.0;
  var hp = 0.0;
  var previous = 0.0;
  var lp = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final white = random.nextDouble() * 2 - 1;
    hp = 0.95 * (hp + white - previous);
    previous = white;
    // One highpass instead of two, then a lowpass over the top: a band, not a
    // hiss.
    lp += (hp - lp) * 0.55;
    out[i] = lp * math.exp(-t * decay) * 0.9;
  }
  return out;
}

Float32List _tambourine(math.Random random) {
  final n = _frames(0.14);
  final out = Float32List(n);
  var hp1 = 0.0;
  var hp2 = 0.0;
  var p1 = 0.0;
  var p2 = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final white = random.nextDouble() * 2 - 1;
    hp1 = 0.975 * (hp1 + white - p1);
    p1 = white;
    hp2 = 0.975 * (hp2 + hp1 - p2);
    p2 = hp1;
    // Jingles rattle after the hit rather than decaying straight off it.
    final rattle = 1 + 0.35 * math.sin(2 * math.pi * 62 * t);
    out[i] = hp2 * rattle * math.exp(-t * 30) * 0.85;
  }
  return out;
}

Float32List _lowTom(math.Random random) {
  final n = _frames(0.34);
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final freq = 104.0 + 46.0 * math.exp(-t * 60);
    phase += freq / sampleRate;
    final body =
        (math.sin(2 * math.pi * phase) + 0.18 * math.sin(4 * math.pi * phase)) *
        math.exp(-t * 11);
    final stick = (random.nextDouble() * 2 - 1) * math.exp(-t * 500) * 0.18;
    out[i] = _tanh((body + stick) * 1.3);
  }
  return out;
}

// --- Kit 03: the metal one, in the Nightshift pack --------------------------
//
// The third corner. 01 is bright and round, 02 is dark and soft, and this one
// is hard and inharmonic: short kick, ringing snare, and tuned metal where the
// other two have skin and wood. It is the kit for a Beat that has to sit on top
// of a break rather than under it, which is what the Nightshift breaks want.
//
// Everything here is built from inharmonic partials -- ratios that are not
// whole numbers -- because that is the difference between a struck metal bar
// and a drum, and it is the whole character of the kit.

Float32List _steelKick(math.Random random) {
  final n = _frames(0.24);
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    // A fast, deep sweep and a short body: this one is a punch, not a weight,
    // and it leaves the bottom of the mix to the sub lane on purpose.
    final freq = 52.0 + 210.0 * math.exp(-t * 95);
    phase += freq / sampleRate;
    final body = math.sin(2 * math.pi * phase) * math.exp(-t * 26);
    final click = (random.nextDouble() * 2 - 1) * math.exp(-t * 1100) * 0.34;
    out[i] = _tanh((body + click) * 1.9) * 0.95;
  }
  return out;
}

Float32List _ringSnare(math.Random random) {
  final n = _frames(0.30);
  final out = Float32List(n);
  var hp = 0.0;
  var previous = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    // Two partials at 1 : 2.41, which is not a musical interval and is why it
    // rings rather than sounding tuned.
    final ring =
        (math.sin(2 * math.pi * 246 * t) * math.exp(-t * 18) +
            0.55 * math.sin(2 * math.pi * 593 * t) * math.exp(-t * 26)) *
        0.5;
    final white = random.nextDouble() * 2 - 1;
    hp = 0.94 * (hp + white - previous);
    previous = white;
    final noise = hp * math.exp(-t * 30) * 0.7;
    out[i] = _tanh((ring + noise) * 1.3);
  }
  return out;
}

Float32List _metalRim(math.Random random) {
  final n = _frames(0.09);
  final out = Float32List(n);
  // Four partials off a 2100 Hz fundamental, none of them harmonic. A bell in
  // miniature, which is what a rim shot on a metal shell is.
  const partials = [1.0, 1.73, 2.41, 3.19];
  const weights = [1.0, 0.62, 0.44, 0.28];
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var tone = 0.0;
    for (var p = 0; p < partials.length; p++) {
      tone +=
          math.sin(2 * math.pi * 2100 * partials[p] * t) *
          weights[p] *
          math.exp(-t * (70 + 26 * p));
    }
    final strike = (random.nextDouble() * 2 - 1) * math.exp(-t * 1600) * 0.4;
    out[i] = _tanh((tone * 0.5 + strike) * 1.2);
  }
  return out;
}

Float32List _tightClap(math.Random random) {
  final n = _frames(0.09);
  final out = Float32List(n);
  // One burst and no room at all. Next to the other two claps this is the one
  // that can go on every sixteenth without turning into a wash.
  var hp = 0.0;
  var previous = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final white = random.nextDouble() * 2 - 1;
    hp = 0.92 * (hp + white - previous);
    previous = white;
    out[i] = _tanh(hp * math.exp(-t * 84) * 1.4);
  }
  return out;
}

Float32List _sizzleHat(math.Random random, {required bool open}) {
  final n = _frames(open ? 0.30 : 0.045);
  final out = Float32List(n);
  final decay = open ? 12.5 : 130.0;
  var hp1 = 0.0;
  var hp2 = 0.0;
  var p1 = 0.0;
  var p2 = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final white = random.nextDouble() * 2 - 1;
    hp1 = 0.978 * (hp1 + white - p1);
    p1 = white;
    hp2 = 0.978 * (hp2 + hp1 - p2);
    p2 = hp1;
    // A pair of high partials rung by the noise, so it sizzles instead of
    // hissing. Two hats hitting each other, not sand in a tube.
    final metal =
        (math.sin(2 * math.pi * 7400 * t) + math.sin(2 * math.pi * 9130 * t)) *
        0.14;
    out[i] = (hp2 + metal) * math.exp(-t * decay) * 0.8;
  }
  return out;
}

Float32List _maraca(math.Random random) {
  final n = _frames(0.075);
  final out = Float32List(n);
  var hp = 0.0;
  var previous = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final white = random.nextDouble() * 2 - 1;
    hp = 0.94 * (hp + white - previous);
    previous = white;
    // Harder and shorter than kit 01's shaker: beads against a shell, hit
    // rather than swung, so it works on the offbeat sixteenths.
    final attack = 1 - math.exp(-t * 900);
    out[i] = hp * attack * math.exp(-t * 68) * 0.95;
  }
  return out;
}

Float32List _highTom(math.Random random) {
  final n = _frames(0.19);
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final freq = 268.0 + 92.0 * math.exp(-t * 80);
    phase += freq / sampleRate;
    final body =
        (math.sin(2 * math.pi * phase) + 0.3 * math.sin(5.6 * math.pi * phase)) *
        math.exp(-t * 22);
    final stick = (random.nextDouble() * 2 - 1) * math.exp(-t * 800) * 0.24;
    out[i] = _tanh((body + stick) * 1.35);
  }
  return out;
}

int _frames(double seconds) => (sampleRate * seconds).round();

/// Every one shot ends at zero. A sample that stops mid cycle clicks, and eight
/// slots clicking on every bar is what makes a kit sound cheap.
void _fadeOut(Float32List voice) {
  final tail = math.min(voice.length, _frames(0.004));
  for (var i = 0; i < tail; i++) {
    voice[voice.length - tail + i] *= 1 - i / tail;
  }
}

void _normalize(Float32List voice, double target) {
  var peak = 0.0;
  for (final v in voice) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  if (peak <= 0) return;
  final gain = target / peak;
  for (var i = 0; i < voice.length; i++) {
    voice[i] *= gain;
  }
}

double _tanh(double x) {
  if (x < -3) return -1;
  if (x > 3) return 1;
  final x2 = x * x;
  return x * (27 + x2) / (27 + 9 * x2);
}
