import 'dart:math' as math;
import 'dart:typed_data';

import '../models/beat.dart';
import '../models/kit_pattern.dart';
import 'audio_clip.dart';
import 'sub_voice.dart';

/// Everything the renderer needs to turn pattern data into samples.
class RenderSpec {
  const RenderSpec({
    required this.breakClip,
    required this.beat,
    required this.bpm,
    required this.sampleRate,
    this.kitClips = const [],
    this.drumGain = 0.92,
    this.subGain = 0.80,
  });

  /// Stereo, already at [sampleRate].
  final AudioClip breakClip;

  /// One clip per Kit slot, in slot order. Empty until the project kit has
  /// loaded, which only silences Kit Beats.
  final List<AudioClip> kitClips;

  final Beat beat;
  final double bpm;
  final int sampleRate;
  final double drumGain;
  final double subGain;
}

/// Turns a [Beat] into interleaved stereo float samples.
///
/// This is the only thing in the app that makes sound. Live playback pulls
/// blocks from it and pushes them to the output device; WAV export pulls the
/// same blocks into a file. There is deliberately no second code path, so what
/// you hear is exactly what you export.
///
/// Both machines render here. Which one a Beat runs is a branch at step fire
/// time, not a second renderer, so the sub lane, the tempo handling and the
/// master saturation are shared by construction.
class PatternRenderer {
  PatternRenderer(this._spec) {
    _sub = SubVoice(sampleRate: _spec.sampleRate);
    _sub.setPatch(_spec.beat.subPatch);
    _framesPerStep = _spec.sampleRate * 60.0 / _spec.bpm / 4.0;
    _fadeFrames = math.max(1, (_spec.sampleRate * 0.0015).round());
    _attackFrames = math.max(1, (_spec.sampleRate * 0.0004).round());
    rewind();
  }

  RenderSpec _spec;

  RenderSpec get spec => _spec;

  /// Swaps in edited pattern data without disturbing the playhead or any voice
  /// that is currently ringing, so painting a step never interrupts the loop.
  ///
  /// Only valid while the timeline is unchanged. Anything that moves step
  /// boundaries (tempo, bar count, a different Beat) needs a new renderer.
  void updateSpec(RenderSpec next) {
    assert(
      next.sampleRate == _spec.sampleRate &&
          next.beat.stepCount == _spec.beat.stepCount &&
          next.beat.machineType == _spec.beat.machineType &&
          identical(next.breakClip, _spec.breakClip),
      'updateSpec cannot change sample rate, length, machine or break; '
      'build a new renderer instead',
    );
    if (next.bpm != _spec.bpm) _retempo(next.bpm);
    _spec = next;
    _sub.setPatch(next.beat.subPatch);
  }

  /// Changes tempo without losing the playhead, so dragging BPM slides the loop
  /// rather than restarting the bar. The remainder of the current step is
  /// rescaled into the new step length.
  void _retempo(double bpm) {
    final previous = _framesPerStep;
    _framesPerStep = _spec.sampleRate * 60.0 / bpm / 4.0;
    if (previous > 0) {
      _framesToNextStep = math.max(
        1,
        (_framesToNextStep * _framesPerStep / previous).round(),
      );
    }
  }

  static const int _maxSliceVoices = 4;

  /// Kit voices. Eight slots can fire on one step and the tails of the step
  /// before are still ringing, so this is deliberately more than eight.
  static const int _maxKitVoices = 16;

  late final SubVoice _sub;
  late double _framesPerStep;
  late final int _fadeFrames;
  late final int _attackFrames;

  final List<_SliceVoice> _voices = List.generate(
    _maxSliceVoices,
    (_) => _SliceVoice(),
  );

  final List<_KitVoice> _kitVoices = List.generate(
    _maxKitVoices,
    (_) => _KitVoice(),
  );

  int _stepIndex = 0;
  int _framesToNextStep = 0;
  bool _tail = false;

  int get stepCount => _spec.beat.stepCount;

  /// Frames in one pass of the pattern. Boundaries are rounded per step and the
  /// loop length is taken from the last boundary, so rounding never drifts.
  int get loopFrames => _boundary(stepCount);

  /// How many frames one step lasts at the current tempo.
  double get framesPerStep => _framesPerStep;

  /// Position within the pattern, in frames. Wraps with the loop.
  int get loopFrame =>
      _boundary(_stepIndex) + (_stepLength(_stepIndex) - _framesToNextStep);

  int _boundary(int step) => (step * _framesPerStep).round();

  int _stepLength(int step) => _boundary(step + 1) - _boundary(step);

  /// Returns to the top of the pattern and clears all voice state, so two
  /// renders from the same spec are sample identical.
  void rewind() {
    _stepIndex = 0;
    _tail = false;
    for (final v in _voices) {
      v.active = false;
    }
    for (final v in _kitVoices) {
      v.active = false;
      v.clip = null;
    }
    _sub.reset();
    _framesToNextStep = _stepLength(0);
    _fireStep(0);
  }

  /// Renders [frameCount] frames of interleaved stereo into [out].
  ///
  /// [out] must hold at least `frameCount * 2` floats. Its contents are
  /// overwritten, not mixed into.
  void render(Float32List out, int frameCount) {
    out.fillRange(0, frameCount * 2, 0);
    var written = 0;
    while (written < frameCount) {
      final chunk = math.min(frameCount - written, _framesToNextStep);
      if (chunk > 0) {
        _renderChunk(out, written, chunk);
        written += chunk;
        _framesToNextStep -= chunk;
      }
      if (_framesToNextStep <= 0) {
        _stepIndex = (_stepIndex + 1) % stepCount;
        _framesToNextStep = _stepLength(_stepIndex);
        _fireStep(_stepIndex);
      }
    }
  }

  void _renderChunk(Float32List out, int atFrame, int count) {
    final clip = _spec.breakClip.samples;
    final clipFrames = _spec.breakClip.frames;
    final drumGain = _spec.drumGain;
    final subGain = _spec.subGain;

    for (var i = 0; i < count; i++) {
      var l = 0.0;
      var r = 0.0;

      for (final v in _voices) {
        if (!v.active) continue;
        if (v.readFrame >= v.endFrame || v.readFrame >= clipFrames) {
          v.active = false;
          continue;
        }
        // Short ramps at both ends of a slice, and on a choke, so rearranging
        // mid transient does not click.
        final sinceStart = v.readFrame - v.startFrame;
        final untilEnd = v.endFrame - v.readFrame;
        var g = v.gain;
        if (sinceStart < _attackFrames) g *= sinceStart / _attackFrames;
        if (untilEnd < _fadeFrames) g *= untilEnd / _fadeFrames;

        final base = v.readFrame * 2;
        l += clip[base] * g;
        r += clip[base + 1] * g;

        v.readFrame++;
        if (v.fading) {
          v.gain -= v.fadeStep;
          if (v.gain <= 0) v.active = false;
        }
      }

      for (final v in _kitVoices) {
        if (!v.active) continue;
        final samples = v.clip!;
        final index = v.position.floor();
        if (index >= v.frames - 1) {
          v.active = false;
          v.clip = null;
          continue;
        }
        // One shots are pitched by playback rate, so a slot tuned down is also
        // a slot that rings longer. Interpolated, because a rate of 1.06 read
        // without it is audibly grainy on a hat.
        final t = v.position - index;
        final a = index * 2;
        final b = a + 2;
        l += (samples[a] + (samples[b] - samples[a]) * t) * v.gain;
        r += (samples[a + 1] + (samples[b + 1] - samples[a + 1]) * t) * v.gain;
        v.position += v.rate;
      }

      l *= drumGain;
      r *= drumGain;

      final sub = _sub.nextSample() * subGain;
      l += sub;
      r += sub;

      final o = (atFrame + i) * 2;
      out[o] = softClip(l);
      out[o + 1] = softClip(r);
    }
  }

  /// Stops the sequencer but keeps rendering, so whatever is ringing can decay
  /// naturally. Used to capture the ring out at the end of an export.
  void beginTail() {
    _tail = true;
    _sub.noteOff();
  }

  void _fireStep(int step) {
    if (_tail) return;
    final beat = _spec.beat;

    if (beat.isKit) {
      for (var slot = 0; slot < kitSlotCount; slot++) {
        final velocity = beat.kit.velocityAt(slot, step);
        if (velocity != null) _triggerKit(beat, slot, velocity);
      }
    } else {
      final slice = beat.chop.sliceAt(step);
      if (slice != null) _triggerSlice(slice);
    }

    final cell = beat.sub.stepAt(step);
    if (cell.semitone != null) {
      final hz = midiToHz(beat.subRootMidi + cell.semitone!);
      _sub.noteOn(hz, glide: cell.tie);
    } else if (cell.tie) {
      _sub.hold();
    } else {
      _sub.noteOff();
    }
  }

  void _triggerSlice(int index) {
    final total = _spec.breakClip.frames;
    final count = _spec.beat.sliceCount;
    if (count <= 0 || index < 0 || index >= count) return;

    final start = (index * total / count).round();
    final end = ((index + 1) * total / count).round().clamp(0, total);
    if (end <= start) return;

    // Monophonic grid: the new hit chokes whatever is ringing, but the old
    // voice is faded rather than cut dead.
    for (final v in _voices) {
      if (v.active && !v.fading) {
        v.fading = true;
        v.fadeStep = v.gain / _fadeFrames;
      }
    }

    final voice = _freeVoice();
    voice
      ..active = true
      ..fading = false
      ..fadeStep = 0
      ..gain = 1
      ..startFrame = start
      ..readFrame = start
      ..endFrame = end;
  }

  /// Fires one Kit slot. Nothing is choked: slots are independent by spec, so
  /// an open hat rings under the next closed hat exactly as it would on a
  /// machine with no choke groups.
  void _triggerKit(Beat beat, int slot, KitVelocity velocity) {
    final clips = _spec.kitClips;
    if (slot < 0 || slot >= clips.length) return;
    final clip = clips[slot];
    if (clip.frames < 2) return;

    final settings = beat.slot(slot);
    final voice = _freeKitVoice();
    voice
      ..active = true
      ..clip = clip.samples
      ..frames = clip.frames
      ..position = 0
      ..rate = settings.rate
      ..gain = settings.volume * velocity.gain;
  }

  /// Prefers an idle slot, otherwise steals the one closest to finishing.
  _SliceVoice _freeVoice() {
    for (final v in _voices) {
      if (!v.active) return v;
    }
    var oldest = _voices.first;
    for (final v in _voices) {
      if (v.endFrame - v.readFrame < oldest.endFrame - oldest.readFrame) {
        oldest = v;
      }
    }
    return oldest;
  }

  /// Same rule as the slice pool: steal from whatever has least left to play,
  /// which is the voice you are least likely to hear disappear.
  _KitVoice _freeKitVoice() {
    for (final v in _kitVoices) {
      if (!v.active) return v;
    }
    var nearest = _kitVoices.first;
    for (final v in _kitVoices) {
      if (v.remaining < nearest.remaining) nearest = v;
    }
    return nearest;
  }

  /// Gentle saturation on the master so a dense pattern glues instead of
  /// clipping into the 16 bit export.
  ///
  /// Public because it is part of what the mixer promises: every sample that
  /// leaves here has been through this curve.
  static double softClip(double x) {
    if (x < -3) return -1;
    if (x > 3) return 1;
    final x2 = x * x;
    return x * (27 + x2) / (27 + 9 * x2);
  }
}

class _SliceVoice {
  bool active = false;
  bool fading = false;
  int startFrame = 0;
  int readFrame = 0;
  int endFrame = 0;
  double gain = 1;
  double fadeStep = 0;
}

class _KitVoice {
  bool active = false;

  /// Interleaved stereo samples of the slot's one shot, held directly so the
  /// inner loop never goes through an object.
  Float32List? clip;
  int frames = 0;
  double position = 0;
  double rate = 1;
  double gain = 1;

  /// Frames of audio left to play, at this voice's rate.
  double get remaining => active ? (frames - position) / rate : -1;
}
