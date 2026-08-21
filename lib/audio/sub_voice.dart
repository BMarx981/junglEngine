import 'dart:math' as math;

import '../models/sub_patch.dart';

/// The whole sub synth: one monophonic voice.
///
/// Sine/triangle core, one lowpass, drive, amp envelope, glide. Five knobs.
/// If something wants a sixth, the answer is no. See CLAUDE.md.
class SubVoice {
  SubVoice({required this.sampleRate}) {
    setPatch(const SubPatch());
  }

  final int sampleRate;

  SubPatch _patch = const SubPatch();

  // Oscillator.
  double _phase = 0;
  double _freq = 55;
  double _targetFreq = 55;
  double _glideCoeff = 1;

  // Chamberlin state variable filter.
  double _low = 0;
  double _band = 0;
  double _filterF = 0.2;
  static const double _filterQ = 0.85;

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
    _patch = patch;

    final cutoffHz = 60.0 * math.pow(50.0, patch.cutoff).toDouble();
    // Chamberlin is only stable well below Nyquist/2.
    final safe = math.min(cutoffHz, sampleRate / 6);
    _filterF = 2 * math.sin(math.pi * safe / sampleRate);

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
  }

  /// Starts a note. With [glide] the pitch slides from wherever it is and the
  /// envelope is not retriggered, which is what a tied cell means.
  void noteOn(double frequency, {bool glide = false}) {
    _targetFreq = frequency;
    _gate = true;
    if (!glide) {
      _freq = frequency;
      _phase = 0;
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
    _phase = 0;
    _env = 0;
    _gate = false;
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

    _phase += _freq / sampleRate;
    if (_phase >= 1.0) _phase -= _phase.floorToDouble();

    final sine = math.sin(2 * math.pi * _phase);
    final triangle = 4.0 * (_phase - 0.5).abs() - 1.0;
    var x = sine + (triangle - sine) * _patch.tone;

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

    return _low * _env;
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
