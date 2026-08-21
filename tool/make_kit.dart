// Generates the bundled Hawkstreak one shot kit.
//
// Original content, synthesised from scratch, so the Kit machine has something
// to play on day one with no sample clearance attached to it. Drop real one
// shots into assets/kits/hawkstreak/ under the same file names to replace
// these; nothing in the code has to change.
//
//   dart run tool/make_kit.dart
//
// See LICENSING.md.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:junglengine/audio/wav.dart';

const int sampleRate = 44100;
const String outputDir = 'assets/kits/hawkstreak';

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

void main() {
  final random = math.Random(1994);
  final voices = <String, Float32List>{
    'kick': _kick(random),
    'snare': _snare(random),
    'rim': _rim(random),
    'clap': _clap(random),
    'hat_closed': _hat(random, open: false),
    'hat_open': _hat(random, open: true),
    'shaker': _shaker(random),
    'conga': _conga(random),
  };

  Directory(outputDir).createSync(recursive: true);
  voices.forEach((name, voice) {
    _fadeOut(voice);
    _normalize(voice, _levels[name]!);
    final path = '$outputDir/hawkstreak_$name.wav';
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
