import 'package:flutter/foundation.dart';

import 'audio_clip.dart';
import 'pattern_renderer.dart';

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

  /// Plays a single slice of the current break immediately, for tap feedback.
  /// Never affects the transport.
  Future<void> auditionSlice(int sliceIndex);

  /// Plays one Kit slot immediately, at that slot's own volume and pitch, for
  /// tap feedback. Never affects the transport.
  Future<void> auditionKitSlot(int slot);

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
