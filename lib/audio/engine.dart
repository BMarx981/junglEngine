import 'package:flutter/foundation.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/models/kit_pattern.dart';

/// What the UI is allowed to know about playback.
///
/// The clock lives in the audio layer. Widgets subscribe to this and never
/// schedule anything themselves.
@immutable
class TransportState {
  const TransportState({
    this.playing = false,
    this.step = 0,
    this.stepCount = 16,
    this.loopPosition = 0,
    this.beatId = '',
    this.entryIndex = -1,
  });

  final bool playing;

  /// Index of the step currently sounding, within the Beat that is sounding.
  /// In song playback that is the step of the current card, not of the whole
  /// arrangement, so a grid can draw it without knowing what a song is.
  final int step;
  final int stepCount;

  /// Position through the current pattern pass, 0..1.
  final double loopPosition;

  /// Which Beat is sounding. Empty before anything has played.
  final String beatId;

  /// Which Song card is sounding, or -1 outside song playback.
  final int entryIndex;

  TransportState copyWith({
    bool? playing,
    int? step,
    int? stepCount,
    double? loopPosition,
    String? beatId,
    int? entryIndex,
  }) => TransportState(
    playing: playing ?? this.playing,
    step: step ?? this.step,
    stepCount: stepCount ?? this.stepCount,
    loopPosition: loopPosition ?? this.loopPosition,
    beatId: beatId ?? this.beatId,
    entryIndex: entryIndex ?? this.entryIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is TransportState &&
      other.playing == playing &&
      other.step == step &&
      other.stepCount == stepCount &&
      other.loopPosition == loopPosition &&
      other.beatId == beatId &&
      other.entryIndex == entryIndex;

  @override
  int get hashCode =>
      Object.hash(playing, step, stepCount, loopPosition, beatId, entryIndex);
}

/// One edit-to-audible measurement: painting a step, to hearing it.
///
/// The number the M4 gate is answered on. Both engines report it the same way
/// so the two can be compared, and both count the same stretch: from the edit
/// being handed to the engine, to the first sample of it being handed to the
/// platform.
///
/// What each of them is measuring underneath is not the same thing at all, and
/// that is the point. The Lira engine is measuring a wait for the next block
/// boundary. flutter_soloud is measuring the queue it keeps ahead of the
/// playhead, because everything already pushed to the device carries the old
/// pattern.
///
/// Neither can see what the speaker does after the platform has the samples,
/// which is a buffer of the same order on both and is why stage 3 also puts a
/// 240 fps camera on a thumb. This comes back out of the interface when the
/// gate is answered and one of the two engines goes away. See docs/M4.md.
@immutable
class EditLatency {
  const EditLatency({required this.engineMicros, required this.callMicros});

  /// Microseconds between the engine being handed the edit and the first
  /// sample of it reaching the platform.
  final int engineMicros;

  /// What the [AudioEngine.setSpec] call itself cost on the UI thread. Part of
  /// the wait between the paint and the sound, and the part that is Dart's
  /// rather than the engine's: encoding a spec, and on the Lira engine copying
  /// it across the boundary.
  final int callMicros;

  /// The whole wait, as far as the engine can see it.
  Duration get total => Duration(microseconds: callMicros + engineMicros);

  @override
  String toString() =>
      'EditLatency(${total.inMicroseconds / 1000} ms: engine '
      '${engineMicros / 1000} ms, call ${callMicros / 1000} ms)';
}

/// When a new [RenderSpec] takes over.
enum SpecChange {
  /// As soon as the engine can, without interrupting anything that is ringing.
  /// What every edit wants: paint a step and hear it on the next pass.
  now,

  /// At the end of the bar being played. Changing which Beat is playing is a
  /// musical move rather than an edit, so it waits for the bar rather than
  /// chopping it in half. Falls back to [now] with the transport stopped,
  /// because then there is no bar to wait for.
  nextBar,
}

/// The boundary between the app and whatever is making noise.
///
/// M0 is backed by flutter_soloud. The Lira Rust engine is meant to drop in
/// behind this same interface at M2 or M3 without the sequencer, the grid or
/// the exporter noticing, so nothing engine specific may leak through it.
abstract class AudioEngine {
  /// Output sample rate. Callers resample their material to match.
  int get sampleRate;

  bool get isInitialized;

  /// The playhead. Rebuild against this, do not poll.
  ValueListenable<TransportState> get transport;

  /// The most recent edit-to-audible measurement, or null before an edit has
  /// been made while the transport is running. Only the M4 readout listens to
  /// this; nothing in the app's own behaviour depends on it.
  ValueListenable<EditLatency?> get editLatency;

  Future<void> initialize();

  Future<void> shutdown();

  /// Installs what should be playing. Safe to call while the transport is
  /// running: the change takes effect at the next block boundary without
  /// interrupting the loop, or at the end of the bar when [when] says so.
  Future<void> setSpec(RenderSpec spec, {SpecChange when = SpecChange.now});

  /// Drops whatever [SpecChange.nextBar] queued and leaves what is playing
  /// alone. Does nothing when nothing is queued.
  Future<void> cancelQueuedSpec();

  Future<void> start();

  Future<void> stop();

  /// The platform is taking the output away, or is about to: an interruption
  /// beginning, or the app going to the background. Stops the transport and
  /// gives the device back.
  ///
  /// Not a user action and not on any screen. A phone hands its output around
  /// between apps and calls, and an app that holds one it cannot use is a
  /// battery cost with nothing listening at the end of it. Everything the
  /// engine has loaded survives, so [resume] carries on rather than reloads.
  ///
  /// Idempotent.
  Future<void> suspend();

  /// The output is available again: the interruption ended, or the app came
  /// back to the foreground.
  ///
  /// The transport stays stopped. A call ending is not a request to play.
  ///
  /// May come back at a different [sampleRate] than it went away at, because a
  /// phone can return on a different route than it left on. When it does,
  /// everything the app has decoded is at the wrong rate and
  /// [onSampleRateChanged] is what says so.
  ///
  /// Idempotent, and a no-op when the device never went away.
  Future<void> resume();

  /// Called after the engine has reopened at a rate it was not running at
  /// before, so that whoever decoded the audio can decode it again.
  ///
  /// The engine cannot do it: what a clip was decoded *from* is a bundled
  /// asset or an imported file, and neither is something the audio layer
  /// knows about. So it reports the change and the studio reloads. Until it
  /// does, the transport is stopped and what is loaded is at the old rate.
  set onSampleRateChanged(Future<void> Function()? handler);

  /// Plays a single slice of the current break immediately, for tap feedback.
  /// Never affects the transport.
  Future<void> auditionSlice(int sliceIndex);

  /// Plays one Kit slot immediately, at that slot's own volume and pitch, for
  /// tap feedback. Never affects the transport.
  ///
  /// [velocity] is the level the tap wrote, so a step tapped down to soft
  /// previews soft: the preview answers "what did I just write", and one that
  /// always sounded hard would be answering a different question. Null is a
  /// pad tap, which is not a step and so has no velocity on it.
  Future<void> auditionKitSlot(int slot, {KitVelocity? velocity});

  /// Plays an arbitrary clip immediately, optionally looping, and replaces
  /// whatever the previous call started. This is how the import screen lets you
  /// hear a trim before committing to it, so it takes a clip rather than an
  /// index: what is being auditioned is not in the project yet.
  Future<void> auditionClip(AudioClip clip, {bool looping = false});

  /// Stops whatever [auditionClip] started. Never affects the transport.
  Future<void> stopAuditionClip();

  /// Renders [spec] faster than real time. Used by WAV export, which must
  /// produce byte identical audio to what playback produces, so export goes
  /// through the engine rather than around it.
  Future<Float32List> renderOffline(RenderSpec spec, int frameCount);

  /// Frames in one pass of [spec]'s pattern. Export multiplies this by the
  /// number of bars asked for.
  int loopFramesFor(RenderSpec spec);
}
