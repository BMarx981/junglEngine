import 'dart:math' as math;

import 'package:junglengine/models/sub_patch.dart';

/// The whole sub synth: one monophonic voice.
///
/// Two detuned oscillators morphing sine to triangle to saw, one lowpass,
/// drive, amp envelope, glide. Six knobs. If something wants a seventh, the
/// answer is no. See CLAUDE.md.
class SubVoice {
  SubVoice({required this.sampleRate}) {
    setPatch(const SubPatch());
  }

  final int sampleRate;

  // Oscillators. Two of them, one voice: the pair is what makes a Reese, and
  // at detune 0 they run in lockstep and sum back to the single oscillator
  // this synth had before.
  double _phaseA = 0;
  double _phaseB = 0;
  double _detuneRatio = 1;
  double _freq = 55;
  double _targetFreq = 55;
  double _glideCoeff = 1;

  /// Whether [SubPatch.tone] is in its upper half, morphing triangle to saw.
  bool _sawMorph = false;

  /// The morph amount within whichever half of the tone knob is in play.
  double _toneBlend = 0.25;

  // Chamberlin state variable filter.
  double _low = 0;
  double _band = 0;
  double _filterF = 0.2;
  double _closedF = 0.2;
  double _openF = 0.2;
  bool _accent = false;
  static const double _filterQ = 0.85;

  /// How much further open an accented note sits, in cutoff multiples.
  static const double _accentOpen = 1.8;

  /// The level an accented note is played at.
  ///
  /// Opening the filter on its own does not read as an accent here, and
  /// measurably goes the wrong way: this filter resonates, the core is close to
  /// a sine, and moving the corner up takes the resonance off the low harmonics
  /// that carry most of the note's energy. So the accent is a corner and a few
  /// dB together, which is what an accent is on any machine that has one. It is
  /// still one thing to the user: hold a note, it speaks.
  static const double _accentGain = 1.35;

  // Amp envelope.
  static const double _attackSeconds = 0.004;
  double _env = 0;
  double _attackStep = 1;
  double _releaseCoeff = 0.999;
  bool _gate = false;

  double _driveAmount = 1;
  double _driveMakeup = 1;

  bool get isSilent => !_gate && _env < 0.0001;

  void setPatch(SubPatch patch) {
    final cutoffHz = 60.0 * math.pow(50.0, patch.cutoff).toDouble();
    // Chamberlin is only stable well below Nyquist/2.
    final safe = math.min(cutoffHz, sampleRate / 6);
    _closedF = 2 * math.sin(math.pi * safe / sampleRate);
    final open = math.min(cutoffHz * _accentOpen, sampleRate / 6);
    _openF = 2 * math.sin(math.pi * open / sampleRate);
    _filterF = _accent ? _openF : _closedF;

    _attackStep = 1.0 / math.max(1, _attackSeconds * sampleRate);

    final releaseSeconds = 0.02 + patch.decay * patch.decay * 0.88;
    // Five time constants to effective silence.
    _releaseCoeff = math.exp(-5.0 / (releaseSeconds * sampleRate));

    final glideSeconds = patch.glide * patch.glide * 0.22;
    _glideCoeff = glideSeconds <= 0
        ? 1.0
        : 1.0 - math.exp(-5.0 / (glideSeconds * sampleRate));

    _driveAmount = 1.0 + patch.drive * 11.0;
    _driveMakeup = 1.0 / (1.0 + patch.drive * 2.2);

    // Lower half of the knob is the sine to triangle blend this synth always
    // had, at half the travel. Upper half carries on into the saw.
    _sawMorph = patch.tone > 0.5;
    _toneBlend = _sawMorph ? (patch.tone - 0.5) * 2 : patch.tone * 2;

    // Cents rather than hertz, so the beat rate stays proportional as the
    // bassline moves. At detune 0 this is exactly 1 and the two oscillators
    // are the same oscillator.
    final cents = patch.detune * SubPatch.maxDetuneCents;
    _detuneRatio = math.pow(2.0, cents / 1200.0).toDouble();
  }

  /// Starts a note. With [glide] the pitch slides from wherever it is and the
  /// envelope is not retriggered, which is what a tied cell means. With
  /// [accent] the filter opens for this note and closes again on the next one.
  void noteOn(double frequency, {bool glide = false, bool accent = false}) {
    _targetFreq = frequency;
    _gate = true;
    _accent = accent;
    _filterF = accent ? _openF : _closedF;
    if (!glide) {
      _freq = frequency;
      // Both oscillators start together every time, so the beating always
      // begins from the same place and a render is repeatable. Free running
      // phase would be more analogue and would make export non deterministic.
      _phaseA = 0;
      _phaseB = 0;
      _env = _env > 0.35 ? _env : 0;
    }
  }

  /// Holds the current pitch without retriggering.
  void hold() {
    _gate = true;
  }

  void noteOff() {
    _gate = false;
  }

  /// Hard reset. Used when the transport rewinds so playback is deterministic.
  void reset() {
    _phaseA = 0;
    _phaseB = 0;
    _env = 0;
    _gate = false;
    _accent = false;
    _filterF = _closedF;
    _low = 0;
    _band = 0;
    _freq = _targetFreq;
  }

  /// One mono sample.
  double nextSample() {
    if (isSilent) {
      _low = 0;
      _band = 0;
      return 0;
    }

    _freq += (_targetFreq - _freq) * _glideCoeff;

    final dtA = _freq * _detuneRatio / sampleRate;
    final dtB = _freq / _detuneRatio / sampleRate;

    _phaseA += dtA;
    if (_phaseA >= 1.0) _phaseA -= _phaseA.floorToDouble();
    _phaseB += dtB;
    if (_phaseB >= 1.0) _phaseB -= _phaseB.floorToDouble();

    // Sum and halve. At detune 0 the two are bit for bit identical and this is
    // the identity, which is the promise the spec makes about this knob.
    var x = (_osc(_phaseA, dtA) + _osc(_phaseB, dtB)) * 0.5;

    // Soft clip into the filter, then take the makeup back out.
    x = _tanh(x * _driveAmount) * _driveMakeup;

    // One lowpass.
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

  /// One oscillator, morphed by the tone knob.
  ///
  /// Sine and triangle both start the cycle at their peak and fall through the
  /// first half, so the saw is a falling ramp too. A rising one is the same
  /// spectrum with the phase flipped, but it would fight the triangle through
  /// the middle of the morph instead of tracking it.
  double _osc(double phase, double dt) {
    final sine = math.sin(2 * math.pi * phase);
    final triangle = 4.0 * (phase - 0.5).abs() - 1.0;
    if (!_sawMorph) {
      // Untouched from the single oscillator days, so a migrated patch renders
      // the samples it always did.
      return sine + (triangle - sine) * _toneBlend;
    }
    final saw = 1.0 - 2.0 * phase + _polyBlep(phase, dt);
    return triangle + (saw - triangle) * _toneBlend;
  }

  /// PolyBLEP: rounds off the saw's jump so it does not fold aliases back down
  /// into the audible band.
  ///
  /// Honest about the size of this: the lowpass tops out at 3 kHz, so it was
  /// already burying most of what a naive ramp folds down, and the difference
  /// is small at the bottom of the register. It matters more with the cutoff
  /// wide open on a note up near the top of the lane, and it costs two
  /// multiplies on the samples either side of the wrap. Cheap enough that
  /// shipping the aliasing instead would be a choice, not a tradeoff.
  static double _polyBlep(double phase, double dt) {
    if (dt <= 0) return 0;
    if (phase < dt) {
      final t = phase / dt;
      return t + t - t * t - 1.0;
    }
    if (phase > 1.0 - dt) {
      final t = (phase - 1.0) / dt;
      return t * t + t + t + 1.0;
    }
    return 0;
  }

  static double _tanh(double x) {
    // Rational approximation; cheaper than dart:math and close enough for a
    // saturator running per sample on a phone.
    if (x < -3) return -1;
    if (x > 3) return 1;
    final x2 = x * x;
    return x * (27 + x2) / (27 + 9 * x2);
  }
}

/// Converts a MIDI note number to Hz.
double midiToHz(num midi) => 440.0 * math.pow(2.0, (midi - 69) / 12.0);
