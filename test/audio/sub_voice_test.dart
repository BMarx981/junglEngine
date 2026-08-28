// The sub synth grew a second oscillator so it could make a Reese, and the
// spec in CLAUDE.md pays for that with one promise: DETUNE at 0 is sample for
// sample the sub that shipped before it. A user who never touches the new knob
// never hears that it exists, and every project exported before this change
// re-exports identically.
//
// That promise is only worth something if it is checked, so the voice as it
// was is copied into this file verbatim and the two are run side by side. When
// someone edits `SubVoice` again, this is the file that notices.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/audio/sub_voice.dart';
import 'package:junglengine/models/sub_patch.dart';

const int sampleRate = 44100;

void main() {
  group('detune at 0 is the sub as it was', () {
    /// Renders the same note events through the current voice and through the
    /// pre Reese one, and returns the two buffers.
    ///
    /// [oldTone] is on the old scale, where 0 is sine and 1 is triangle. The
    /// current voice gets it halved, which is exactly what `SubPatch.fromJson`
    /// does to a project saved before the change.
    (List<double>, List<double>) both({
      required double oldTone,
      double cutoff = 0.45,
      double drive = 0.2,
      double decay = 0.35,
      double glide = 0.3,
      bool accent = false,
      bool tie = false,
    }) {
      final now = SubVoice(sampleRate: sampleRate)
        ..setPatch(
          SubPatch(
            tone: oldTone / 2,
            cutoff: cutoff,
            drive: drive,
            decay: decay,
            glide: glide,
          ),
        );
      final before = _PreReeseVoice(sampleRate: sampleRate)
        ..setPatch(
          tone: oldTone,
          cutoff: cutoff,
          drive: drive,
          decay: decay,
          glide: glide,
        );

      final a = <double>[];
      final b = <double>[];
      void run(int frames) {
        for (var i = 0; i < frames; i++) {
          a.add(now.nextSample());
          b.add(before.nextSample());
        }
      }

      now.noteOn(55.0, accent: accent);
      before.noteOn(55.0, accent: accent);
      run(4000);

      // A tied cell: glide to a new pitch without retriggering the envelope.
      if (tie) {
        now.noteOn(82.41, glide: true);
        before.noteOn(82.41, glide: true);
        run(4000);
      }

      now.noteOff();
      before.noteOff();
      run(6000);

      return (a, b);
    }

    void identical(String name, (List<double>, List<double>) buffers) {
      final (now, before) = buffers;
      expect(now, hasLength(before.length));
      var worst = 0.0;
      var worstAt = -1;
      for (var i = 0; i < now.length; i++) {
        final d = (now[i] - before[i]).abs();
        if (d > worst) {
          worst = d;
          worstAt = i;
        }
      }
      // Not "close enough": the two oscillators are the same double at the same
      // phase, summed and halved, which IEEE 754 does exactly. Anything above
      // zero here means the signal path moved.
      expect(
        worst,
        0.0,
        reason: '$name diverged by $worst at sample $worstAt',
      );
      // Guard against both sides being silent and trivially agreeing.
      expect(before.map((s) => s.abs()).reduce(math.max), greaterThan(0.01));
    }

    test('pure sine', () => identical('sine', both(oldTone: 0)));
    test('pure triangle', () => identical('triangle', both(oldTone: 1)));
    test('the old default blend', () => identical('default', both(oldTone: 0.25)));
    test(
      'hard drive',
      () => identical('drive', both(oldTone: 0.6, drive: 1.0)),
    );
    test(
      'filter wide open',
      () => identical('cutoff', both(oldTone: 0.4, cutoff: 1.0)),
    );
    test(
      'filter shut',
      () => identical('cutoff low', both(oldTone: 0.4, cutoff: 0.0)),
    );
    test(
      'an accented note',
      () => identical('accent', both(oldTone: 0.3, accent: true)),
    );
    test(
      'a tied note gliding',
      () => identical('glide', both(oldTone: 0.3, glide: 0.9, tie: true)),
    );
    test(
      'long decay ringing out',
      () => identical('decay', both(oldTone: 0.5, decay: 1.0)),
    );
  });

  group('detune', () {
    /// Peak amplitude per 20 ms window over a held note, past the filter's
    /// settling time.
    List<double> heldNoteEnvelope(double detune) {
      final voice = SubVoice(sampleRate: sampleRate)
        ..setPatch(SubPatch(tone: 0.125, detune: detune));
      voice.noteOn(55.0);

      const window = sampleRate ~/ 50;
      final settle = sampleRate ~/ 4;
      for (var i = 0; i < settle; i++) {
        voice.nextSample();
      }

      final peaks = <double>[];
      // Two seconds, which is about four beats at the widest detune.
      for (var w = 0; w < 100; w++) {
        var peak = 0.0;
        for (var i = 0; i < window; i++) {
          final s = voice.nextSample().abs();
          if (s > peak) peak = s;
        }
        peaks.add(peak);
      }
      return peaks;
    }

    test('at 0 the held note sits perfectly still', () {
      final peaks = heldNoteEnvelope(0);
      final high = peaks.reduce(math.max);
      final low = peaks.reduce(math.min);
      expect(high, greaterThan(0.01));
      // One oscillator, gate held, envelope at its ceiling: nothing should move.
      expect(high - low, lessThan(high * 0.01));
    });

    test('wide open the note beats against itself', () {
      final peaks = heldNoteEnvelope(1);
      final high = peaks.reduce(math.max);
      final low = peaks.reduce(math.min);
      expect(high, greaterThan(0.01));
      // The two oscillators drift in and out of phase, so the note breathes.
      // That breathing is the entire point of the knob.
      expect(low, lessThan(high * 0.5));
    });

    /// How many times a four second held note beats down to a null.
    ///
    /// Depth is the wrong thing to measure for rate: every detune wide enough
    /// to complete a beat nulls all the way to near silence, so the depth is
    /// the same and only the spacing changes. Count the nulls instead.
    int beatNulls(double detune) {
      final voice = SubVoice(sampleRate: sampleRate)
        ..setPatch(SubPatch(tone: 0.125, detune: detune));
      voice.noteOn(55.0);
      for (var i = 0; i < sampleRate ~/ 4; i++) {
        voice.nextSample();
      }

      // 5 ms windows, short enough not to straddle a null at the fastest beat
      // this knob reaches.
      const window = sampleRate ~/ 200;
      final peaks = <double>[];
      for (var w = 0; w < 800; w++) {
        var peak = 0.0;
        for (var i = 0; i < window; i++) {
          final s = voice.nextSample().abs();
          if (s > peak) peak = s;
        }
        peaks.add(peak);
      }

      final threshold = peaks.reduce(math.max) * 0.3;
      var count = 0;
      var below = false;
      for (final p in peaks) {
        if (!below && p < threshold) {
          count++;
          below = true;
        } else if (below && p > threshold * 1.5) {
          below = false;
        }
      }
      return count;
    }

    test('the beat rate rises with the knob', () {
      // 30 cents either side of 55 Hz is about 1.9 Hz apart, so the widest
      // setting beats roughly eight times in four seconds and each step down
      // beats fewer times. This is the knob doing the one thing it is for.
      expect(beatNulls(0), 0);
      expect(beatNulls(0.3), greaterThan(beatNulls(0.15)));
      expect(beatNulls(0.6), greaterThan(beatNulls(0.3)));
      expect(beatNulls(1.0), greaterThan(beatNulls(0.6)));
    });

    test('the widest setting lands in Reese territory, not vibrato', () {
      // A Reese wobbles once or twice a second at the bottom of the register.
      // Much slower is a drone, much faster is an effect.
      final perSecond = beatNulls(1.0) / 4.0;
      expect(perSecond, greaterThan(1.0));
      expect(perSecond, lessThan(4.0));
    });
  });

  group('tone morph', () {
    double peakOf(double tone) {
      final voice = SubVoice(sampleRate: sampleRate)
        ..setPatch(SubPatch(tone: tone, cutoff: 1.0, drive: 0.0));
      voice.noteOn(55.0);
      var peak = 0.0;
      for (var i = 0; i < sampleRate ~/ 4; i++) {
        final s = voice.nextSample().abs();
        if (s > peak) peak = s;
      }
      return peak;
    }

    test('the two halves of the knob meet at triangle', () {
      // 0.5 is the last sample of the sine to triangle branch and the first of
      // the triangle to saw one. A seam here would be audible as a click while
      // dragging the slider.
      final below = peakOf(0.5 - 1e-9);
      final above = peakOf(0.5 + 1e-9);
      expect((below - above).abs(), lessThan(1e-6));
    });

    test('a saw carries more harmonics than a triangle', () {
      // Same fundamental, same filter, so more energy above the corner can only
      // come from the waveshape.
      double energyOf(double tone) {
        final voice = SubVoice(sampleRate: sampleRate)
          ..setPatch(SubPatch(tone: tone, cutoff: 1.0, drive: 0.0));
        voice.noteOn(110.0);
        var sum = 0.0;
        for (var i = 0; i < sampleRate; i++) {
          final s = voice.nextSample();
          sum += s * s;
        }
        return sum;
      }

      expect(energyOf(1.0), greaterThan(energyOf(0.5)));
    });

    test('the saw stays bounded', () {
      // PolyBLEP overshoots by design at the wrap. It must not run away.
      final voice = SubVoice(sampleRate: sampleRate)
        ..setPatch(const SubPatch(tone: 1.0, cutoff: 1.0, drive: 0.0));
      voice.noteOn(220.0);
      for (var i = 0; i < sampleRate; i++) {
        final s = voice.nextSample();
        expect(s.isFinite, isTrue);
        expect(s.abs(), lessThan(2.0));
      }
    });
  });
}

/// The sub voice exactly as it was before the second oscillator, kept here so
/// the current one can be held against it.
///
/// Do not tidy this up and do not share code with `SubVoice`. Its whole value
/// is that it is a copy that cannot be changed by accident when the real one
/// is edited.
class _PreReeseVoice {
  _PreReeseVoice({required this.sampleRate});

  final int sampleRate;

  double _tone = 0.25;
  double _phase = 0;
  double _freq = 55;
  double _targetFreq = 55;
  double _glideCoeff = 1;

  double _low = 0;
  double _band = 0;
  double _filterF = 0.2;
  double _closedF = 0.2;
  double _openF = 0.2;
  bool _accent = false;
  static const double _filterQ = 0.85;
  static const double _accentOpen = 1.8;
  static const double _accentGain = 1.35;

  static const double _attackSeconds = 0.004;
  double _env = 0;
  double _attackStep = 1;
  double _releaseCoeff = 0.999;
  bool _gate = false;

  double _driveAmount = 1;
  double _driveMakeup = 1;

  bool get isSilent => !_gate && _env < 0.0001;

  void setPatch({
    required double tone,
    required double cutoff,
    required double drive,
    required double decay,
    required double glide,
  }) {
    _tone = tone;

    final cutoffHz = 60.0 * math.pow(50.0, cutoff).toDouble();
    final safe = math.min(cutoffHz, sampleRate / 6);
    _closedF = 2 * math.sin(math.pi * safe / sampleRate);
    final open = math.min(cutoffHz * _accentOpen, sampleRate / 6);
    _openF = 2 * math.sin(math.pi * open / sampleRate);
    _filterF = _accent ? _openF : _closedF;

    _attackStep = 1.0 / math.max(1, _attackSeconds * sampleRate);

    final releaseSeconds = 0.02 + decay * decay * 0.88;
    _releaseCoeff = math.exp(-5.0 / (releaseSeconds * sampleRate));

    final glideSeconds = glide * glide * 0.22;
    _glideCoeff = glideSeconds <= 0
        ? 1.0
        : 1.0 - math.exp(-5.0 / (glideSeconds * sampleRate));

    _driveAmount = 1.0 + drive * 11.0;
    _driveMakeup = 1.0 / (1.0 + drive * 2.2);
  }

  void noteOn(double frequency, {bool glide = false, bool accent = false}) {
    _targetFreq = frequency;
    _gate = true;
    _accent = accent;
    _filterF = accent ? _openF : _closedF;
    if (!glide) {
      _freq = frequency;
      _phase = 0;
      _env = _env > 0.35 ? _env : 0;
    }
  }

  void noteOff() {
    _gate = false;
  }

  double nextSample() {
    if (isSilent) {
      _low = 0;
      _band = 0;
      return 0;
    }

    _freq += (_targetFreq - _freq) * _glideCoeff;

    _phase += _freq / sampleRate;
    if (_phase >= 1.0) _phase -= _phase.floorToDouble();

    final sine = math.sin(2 * math.pi * _phase);
    final triangle = 4.0 * (_phase - 0.5).abs() - 1.0;
    var x = sine + (triangle - sine) * _tone;

    x = _tanh(x * _driveAmount) * _driveMakeup;

    final high = x - _low - _filterQ * _band;
    _band += _filterF * high;
    _low += _filterF * _band;

    if (_gate) {
      _env = _env + _attackStep;
      if (_env > 1) _env = 1;
    } else {
      _env *= _releaseCoeff;
    }

    return _low * _env * (_accent ? _accentGain : 1.0);
  }

  static double _tanh(double x) {
    if (x < -3) return -1;
    if (x > 3) return 1;
    final x2 = x * x;
    return x * (27 + x2) / (27 + 9 * x2);
  }
}
