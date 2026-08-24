import 'dart:math' as math;
import 'dart:typed_data';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/sub_voice.dart';
import 'package:junglengine/models/beat.dart';
import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/steps.dart';

/// One Beat's turn on the timeline.
///
/// A pattern is a spec with a single section. A song is the same spec with one
/// section per pass, so the sequencer has no idea whether it is looping a bar
/// or playing an arrangement: it is always walking a list of sections.
class RenderSection {
  const RenderSection({required this.beat, this.entryIndex = -1});

  final Beat beat;

  /// Which Song card this pass came from, or -1 when this is not song
  /// playback. The transport reports it so the Song view can light up the card
  /// that is sounding.
  final int entryIndex;
}

/// Everything the renderer needs to turn pattern data into samples.
class RenderSpec {
  const RenderSpec.of({
    required this.breakClip,
    required this.sections,
    required this.bpm,
    required this.sampleRate,
    this.kitClips = const [],
    this.drumGain = 0.92,
    this.subGain = 0.80,
  });

  /// One Beat, looping. What the grid plays.
  factory RenderSpec({
    required AudioClip breakClip,
    required Beat beat,
    required double bpm,
    required int sampleRate,
    List<AudioClip> kitClips = const [],
    double drumGain = 0.92,
    double subGain = 0.80,
  }) => RenderSpec.of(
    breakClip: breakClip,
    sections: [RenderSection(beat: beat)],
    bpm: bpm,
    sampleRate: sampleRate,
    kitClips: kitClips,
    drumGain: drumGain,
    subGain: subGain,
  );

  /// Stereo, already at [sampleRate].
  final AudioClip breakClip;

  /// One clip per Kit slot, in slot order. Empty until the project kit has
  /// loaded, which only silences Kit Beats.
  final List<AudioClip> kitClips;

  /// The timeline, in play order. Never empty.
  final List<RenderSection> sections;

  final double bpm;
  final int sampleRate;
  final double drumGain;
  final double subGain;

  /// The Beat this spec is about. In song mode that is whatever plays first,
  /// which is all anything other than the sequencer needs to know.
  Beat get beat => sections.first.beat;

  /// Whether this is an arrangement rather than one looping pattern.
  bool get isSong => sections.first.entryIndex >= 0;

  /// This spec as the engine's wire format.
  ///
  /// Deliberately the shape a saved project holds: a section's `beat` is
  /// exactly what [Beat.toJson] writes, so the file format, the FFI boundary
  /// and the parity fixtures are one format and there is only one thing for
  /// `packages/junglengine_engine/rust/src/spec.rs` to keep in step with.
  ///
  /// The audio itself is not in here. Clips cross the boundary once, when they
  /// are loaded, and a spec published sixty times a second during a drag
  /// refers to what is already there.
  Map<String, Object?> toEngineJson() => {
    'sampleRate': sampleRate,
    'bpm': bpm,
    'drumGain': drumGain,
    'subGain': subGain,
    'sections': [
      for (final section in sections)
        {'entryIndex': section.entryIndex, 'beat': section.beat.toJson()},
    ],
  };

  /// Bars in one pass of the timeline: one Beat's length, or the whole
  /// arrangement's.
  int get bars {
    var total = 0;
    for (final section in sections) {
      total += section.beat.bars;
    }
    return total;
  }
}

/// Where the sequencer is, in terms the UI understands.
class RenderPosition {
  const RenderPosition({
    required this.step,
    required this.stepCount,
    required this.beatId,
    required this.entryIndex,
    required this.position,
  });

  /// Step within the Beat that is sounding, not within the whole arrangement.
  final int step;

  /// Steps in that Beat, so a grid can scale the playhead against it.
  final int stepCount;

  final String beatId;

  /// Which Song card is playing, or -1 outside song playback.
  final int entryIndex;

  /// Position through the current pass, 0..1.
  final double position;
}

/// Where every step of one [RenderSpec] starts, in frames.
///
/// Immutable, and rebuilt rather than edited whenever the tempo, the swing or
/// the section list moves. That matters because blocks are rendered ahead of
/// what is audible: whatever pushes them keeps the timeline each block was
/// rendered against, so a block still resolves to the right position after the
/// sequencer has moved on to another timeline. See [PatternRenderer.queueSpec].
class RenderTimeline {
  factory RenderTimeline(RenderSpec spec) {
    final fps = spec.sampleRate * 60.0 / spec.bpm / 4.0;
    final boundaries = <int>[];
    final sectionOfStep = <int>[];
    final sectionStartStep = <int>[];
    var frame = 0.0;

    for (var section = 0; section < spec.sections.length; section++) {
      final beat = spec.sections[section].beat;
      sectionStartStep.add(sectionOfStep.length);
      // Swing pushes the odd sixteenths late and leaves the even ones where
      // they were, so the bar still starts and ends where it should however
      // hard the pattern is shuffled.
      final offset = beat.swingOffsetFraction * fps;
      for (var local = 0; local < beat.stepCount; local++) {
        boundaries.add(
          (frame + local * fps + (local.isOdd ? offset : 0)).round(),
        );
        sectionOfStep.add(section);
      }
      frame += beat.stepCount * fps;
    }
    boundaries.add(frame.round());

    return RenderTimeline._(
      spec,
      boundaries,
      sectionOfStep,
      sectionStartStep,
      fps,
    );
  }

  const RenderTimeline._(
    this.spec,
    this._boundaries,
    this._sectionOfStep,
    this._sectionStartStep,
    this.framesPerStep,
  );

  final RenderSpec spec;

  /// Frame each step starts on, plus one past the end. Rounded from an exact
  /// running position, so rounding cannot accumulate into drift.
  final List<int> _boundaries;

  /// Which section each step belongs to.
  final List<int> _sectionOfStep;

  /// First step of each section.
  final List<int> _sectionStartStep;

  /// How many frames one step lasts at this tempo, before swing.
  final double framesPerStep;

  /// Steps in the whole timeline: one bar for a one bar pattern, the entire
  /// arrangement in song mode.
  int get stepCount => _sectionOfStep.length;

  /// Frames in one pass of the timeline.
  int get loopFrames => _boundaries.last;

  int startFrameOf(int step) => _boundaries[step];

  int stepLength(int step) => _boundaries[step + 1] - _boundaries[step];

  int sectionOf(int step) => _sectionOfStep[step];

  int sectionStart(int section) => _sectionStartStep[section];

  Beat beatAt(int step) => spec.sections[_sectionOfStep[step]].beat;

  /// Whether [step] is the first step of a bar. Every Beat is a whole number of
  /// bars, so this is also true of the top of the timeline.
  bool isBarLine(int step) => step % stepsPerBar == 0;

  /// Resolves a frame of the timeline to something the UI can draw.
  RenderPosition positionAt(int frame) {
    final total = loopFrames;
    final wrapped = total <= 0 ? 0 : frame % total;
    final step = stepAtFrame(wrapped);
    final section = _sectionOfStep[step];
    final start = _sectionStartStep[section];
    final beat = spec.sections[section].beat;
    final passStart = _boundaries[start];
    final passFrames = _boundaries[start + beat.stepCount] - passStart;
    return RenderPosition(
      step: step - start,
      stepCount: beat.stepCount,
      beatId: beat.id,
      entryIndex: spec.sections[section].entryIndex,
      position: passFrames <= 0 ? 0 : (wrapped - passStart) / passFrames,
    );
  }

  int stepAtFrame(int frame) {
    var low = 0;
    var high = stepCount - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (_boundaries[mid] <= frame) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }
}

/// Turns [RenderSpec] sections into interleaved stereo float samples.
///
/// This is the only thing in the app that makes sound. Live playback pulls
/// blocks from it and pushes them to the output device; WAV export pulls the
/// same blocks into a file. There is deliberately no second code path, so what
/// you hear is exactly what you export.
///
/// Both machines render here, and so does the Song. Which machine a section
/// runs is a branch at step fire time, not a second renderer, so the sub lane,
/// the tempo handling and the master saturation are shared by construction.
class PatternRenderer {
  PatternRenderer(this._spec) {
    _sub = SubVoice(sampleRate: _spec.sampleRate);
    _fadeFrames = math.max(1, (_spec.sampleRate * 0.0015).round());
    _attackFrames = math.max(1, (_spec.sampleRate * 0.0004).round());
    _buildTimeline();
    rewind();
  }

  RenderSpec _spec;

  RenderSpec get spec => _spec;

  /// Whether [next] can be swapped in under the running playhead.
  ///
  /// The test is deliberately narrow: whatever is sounding right now has to
  /// still be sounding afterwards. Everything else about the timeline may
  /// change, which is what lets a card be added to a song, a repeat count be
  /// nudged or the tempo be dragged while the arrangement keeps playing.
  bool canAdopt(RenderSpec next) {
    if (next.sampleRate != _spec.sampleRate) return false;
    if (!identical(next.breakClip, _spec.breakClip)) return false;
    if (next.sections.isEmpty) return false;
    final section = _timeline.sectionOf(_stepIndex);
    if (section >= next.sections.length) return false;
    final playing = _spec.sections[section].beat;
    final replacement = next.sections[section].beat;
    return playing.id == replacement.id &&
        playing.stepCount == replacement.stepCount &&
        playing.machineType == replacement.machineType;
  }

  /// Whether [next] could be queued to take over at a bar line.
  ///
  /// Much narrower than what [canAdopt] asks, because nothing has to survive a
  /// queued swap except the material the ringing voices are reading from: the
  /// pattern is allowed to change completely, that is the point of it.
  bool canQueue(RenderSpec next) =>
      next.sampleRate == _spec.sampleRate &&
      identical(next.breakClip, _spec.breakClip) &&
      next.sections.isNotEmpty;

  /// Lines [next] up to take over at the end of the bar being rendered.
  ///
  /// This is how a Beat is changed under a running transport: the swap lands on
  /// the bar line rather than the instant it was asked for, so choosing another
  /// Beat mid bar never chops the bar in half. It is deliberately not
  /// [updateSpec]'s job, which is the opposite promise: an edit is heard as
  /// soon as possible and never moves the playhead.
  void queueSpec(RenderSpec next) {
    assert(
      canQueue(next),
      'queued spec must read the same clip at the same rate',
    );
    _queued = next;
  }

  /// Drops the queued spec, leaving whatever is playing alone.
  void clearQueuedSpec() => _queued = null;

  bool get hasQueuedSpec => _queued != null;

  /// Takes the queued spec over, at the bar line the render loop has just
  /// reached.
  ///
  /// The playhead goes to the top of the new timeline and every voice is left
  /// alone, so a slice or a one shot ringing across the join keeps ringing,
  /// exactly as it does when a song moves from one card to the next.
  void _adoptQueued() {
    _spec = _queued!;
    _queued = null;
    _buildTimeline();
    _stepIndex = 0;
    // -1 rather than 0, so the next fired step installs the new Beat's patch.
    _sectionIndex = -1;
  }

  /// Swaps in edited data without disturbing the playhead or any voice that is
  /// currently ringing, so painting a step never interrupts the loop.
  ///
  /// Tempo, swing and the section list are all allowed to move here: the
  /// timeline is rebuilt underneath a playhead that keeps its place in the
  /// section it is in. Only [canAdopt] decides what is too much; anything it
  /// refuses needs a new renderer.
  void updateSpec(RenderSpec next) {
    assert(
      canAdopt(next),
      'updateSpec cannot change what is sounding; build a new renderer instead',
    );
    final section = _timeline.sectionOf(_stepIndex);
    final local = _stepIndex - _timeline.sectionStart(section);
    final previous = _stepLength(_stepIndex);

    _spec = next;
    _buildTimeline();

    _stepIndex = _timeline.sectionStart(section) + local;
    final now = _stepLength(_stepIndex);
    if (previous > 0 && now != previous) {
      _framesToNextStep = math.max(
        1,
        math.min(now, (_framesToNextStep * now / previous).round()),
      );
    }
    _sectionIndex = section;
    _sub.setPatch(_beatAt(_stepIndex).subPatch);
  }

  static const int _maxSliceVoices = 4;

  /// Kit voices. Eight slots can fire on one step and the tails of the step
  /// before are still ringing, so this is deliberately more than eight.
  static const int _maxKitVoices = 16;

  late final SubVoice _sub;
  late final int _fadeFrames;
  late final int _attackFrames;

  /// Every step boundary of [_spec], rebuilt on any tempo, swing or section
  /// change.
  late RenderTimeline _timeline;

  /// What takes over at the next bar line, if anything. See [queueSpec].
  RenderSpec? _queued;

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
  int _sectionIndex = -1;
  bool _tail = false;

  /// The timeline the next block will be rendered against. Whatever pushes
  /// those blocks holds on to this, because a queued swap can replace it while
  /// blocks rendered from it are still waiting to be heard.
  RenderTimeline get timeline => _timeline;

  /// Steps in the whole timeline: one bar for a one bar pattern, the entire
  /// arrangement in song mode.
  int get stepCount => _timeline.stepCount;

  /// Frames in one pass of the timeline.
  int get loopFrames => _timeline.loopFrames;

  /// How many frames one step lasts at the current tempo, before swing.
  double get framesPerStep => _timeline.framesPerStep;

  /// Position within the timeline, in frames. Wraps with the loop.
  int get loopFrame =>
      _timeline.startFrameOf(_stepIndex) +
      (_stepLength(_stepIndex) - _framesToNextStep);

  int _stepLength(int step) => _timeline.stepLength(step);

  Beat _beatAt(int step) => _timeline.beatAt(step);

  void _buildTimeline() => _timeline = RenderTimeline(_spec);

  /// Returns to the top of the timeline and clears all voice state, so two
  /// renders from the same spec are sample identical.
  void rewind() {
    _stepIndex = 0;
    _sectionIndex = -1;
    _tail = false;
    // A rewind is a fresh start, so anything waiting for a bar line that is
    // never going to arrive goes with it.
    _queued = null;
    for (final v in _voices) {
      v.active = false;
    }
    for (final v in _kitVoices) {
      v.active = false;
      v.clip = null;
    }
    _sub.setPatch(_spec.sections.first.beat.subPatch);
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
        final next = (_stepIndex + 1) % stepCount;
        // The one place a queued Beat can land: on a bar line, between the last
        // step of the bar and the first step of the next one.
        if (_queued != null && _timeline.isBarLine(next)) {
          _adoptQueued();
        } else {
          _stepIndex = next;
        }
        _framesToNextStep = _stepLength(_stepIndex);
        _fireStep(_stepIndex);
      }
    }
  }

  /// Resolves a frame of the current timeline to something the UI can draw.
  RenderPosition positionAt(int frame) => _timeline.positionAt(frame);

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
        if (!v.advanceable(clipFrames)) {
          if (!v.restart()) {
            v.active = false;
            continue;
          }
        }

        // Short ramps at both ends of a slice, and on a choke, so rearranging
        // mid transient does not click. Measured in output frames, so a half
        // speed slice ramps over the same amount of time as a plain one.
        var g = v.gain;
        final since = v.framesSinceStart;
        final until = v.framesUntilEnd(clipFrames);
        if (since < _attackFrames) g *= since / _attackFrames;
        if (until < _fadeFrames) g *= until / _fadeFrames;

        final index = v.position.floor();
        final next = index + 1 < clipFrames ? index + 1 : index;
        final t = v.position - index;
        final a = index * 2;
        final b = next * 2;
        l += (clip[a] + (clip[b] - clip[a]) * t) * g;
        r += (clip[a + 1] + (clip[b + 1] - clip[a + 1]) * t) * g;

        v.advance();
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
    final section = _timeline.sectionOf(step);
    final beat = _spec.sections[section].beat;
    if (section != _sectionIndex) {
      // A song can run a different patch on the next card, and the patch is
      // per Beat. Nothing else about the voice is reset, so a note ringing
      // across the join keeps ringing.
      _sectionIndex = section;
      _sub.setPatch(beat.subPatch);
    }
    final local = step - _timeline.sectionStart(section);

    if (beat.isKit) {
      for (var slot = 0; slot < kitSlotCount; slot++) {
        final velocity = beat.kit.velocityAt(slot, local);
        if (velocity != null) _triggerKit(beat, slot, velocity);
      }
    } else {
      final cell = beat.chop.stepAt(local);
      if (cell != null) _triggerSlice(beat, cell, _stepLength(step));
    }

    final cell = beat.sub.stepAt(local);
    if (cell.semitone != null) {
      final hz = midiToHz(beat.subRootMidi + cell.semitone!);
      _sub.noteOn(hz, glide: cell.tie, accent: cell.accent);
    } else if (cell.tie) {
      _sub.hold();
    } else {
      _sub.noteOff();
    }
  }

  void _triggerSlice(Beat beat, ChopStep cell, int stepFrames) {
    final total = _spec.breakClip.frames;
    final count = beat.sliceCount;
    final index = cell.slice;
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

    final mod = cell.mod;
    final reverse = mod.rate < 0;
    _freeVoice()
      ..active = true
      ..fading = false
      ..fadeStep = 0
      ..gain = 1
      ..startFrame = start
      ..endFrame = end
      ..reverse = reverse
      ..rate = mod.rate.abs()
      // A retrigger is the head of the slice, fired again on each subdivision
      // of the step. Everything else plays once, all the way through.
      ..hitFrames = mod.retriggers > 1 ? stepFrames / mod.retriggers : 0
      ..hitsLeft = mod.retriggers - 1
      ..restartHead();
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
    var nearest = _voices.first;
    for (final v in _voices) {
      if (v.remaining < nearest.remaining) nearest = v;
    }
    return nearest;
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

/// A slice of the break, playing.
///
/// Reads at a rate and in a direction, which is what the step modifiers come
/// down to: reverse walks backwards, pitch down and half speed read slower, and
/// a retrigger is the same voice sent back to the head of the slice.
class _SliceVoice {
  bool active = false;
  bool fading = false;
  bool reverse = false;
  int startFrame = 0;
  int endFrame = 0;
  double position = 0;
  double rate = 1;
  double gain = 1;
  double fadeStep = 0;

  /// Output frames one retrigger hit lasts, or 0 when the slice plays once.
  double hitFrames = 0;

  /// Retrigger hits still to come after this one.
  int hitsLeft = 0;

  /// Output frames played since this hit started.
  double _played = 0;

  /// Puts the read head at the top of the slice, which for a reversed voice is
  /// its last frame.
  void restartHead() {
    position = reverse ? (endFrame - 1).toDouble() : startFrame.toDouble();
    _played = 0;
  }

  double get framesSinceStart => _played;

  /// Output frames left before this hit ends, whichever comes first: the end of
  /// the slice or the end of the retrigger subdivision.
  double framesUntilEnd(int clipFrames) {
    final limit = reverse
        ? position - startFrame
        : math.min(endFrame, clipFrames) - position;
    final toSliceEnd = rate <= 0 ? limit : limit / rate;
    if (hitFrames <= 0) return toSliceEnd;
    return math.min(toSliceEnd, hitFrames - _played);
  }

  bool advanceable(int clipFrames) {
    if (hitFrames > 0 && _played >= hitFrames) return false;
    if (reverse) return position > startFrame;
    return position < endFrame - 1 && position < clipFrames - 1;
  }

  /// Starts the next retrigger hit. False when there is none, which retires the
  /// voice.
  bool restart() {
    if (hitsLeft <= 0) return false;
    hitsLeft--;
    restartHead();
    return true;
  }

  void advance() {
    position += reverse ? -rate : rate;
    _played += 1;
  }

  /// Output frames of audio left in this voice, counting the hits still to
  /// come. -1 when idle, so an idle voice always wins voice stealing.
  double get remaining {
    if (!active) return -1;
    final left = reverse ? position - startFrame : endFrame - position;
    final base = rate <= 0 ? left : left / rate;
    return base + hitsLeft * (hitFrames > 0 ? hitFrames : 0);
  }
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
