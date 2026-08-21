import 'package:flutter/foundation.dart';

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
  });

  final bool playing;

  /// Index of the step currently sounding.
  final int step;
  final int stepCount;

  /// Position through the pattern, 0..1.
  final double loopPosition;

  TransportState copyWith({
    bool? playing,
    int? step,
    int? stepCount,
    double? loopPosition,
  }) => TransportState(
    playing: playing ?? this.playing,
    step: step ?? this.step,
    stepCount: stepCount ?? this.stepCount,
    loopPosition: loopPosition ?? this.loopPosition,
  );

  @override
  bool operator ==(Object other) =>
      other is TransportState &&
      other.playing == playing &&
      other.step == step &&
      other.stepCount == stepCount &&
      other.loopPosition == loopPosition;

  @override
  int get hashCode => Object.hash(playing, step, stepCount, loopPosition);
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
  /// interrupting the loop.
  Future<void> setSpec(RenderSpec spec);

  Future<void> start();

  Future<void> stop();

  /// Plays a single slice of the current break immediately, for tap feedback.
  /// Never affects the transport.
  Future<void> auditionSlice(int sliceIndex);

  /// Plays one Kit slot immediately, at that slot's own volume and pitch, for
  /// tap feedback. Never affects the transport.
  Future<void> auditionKitSlot(int slot);

  /// Renders [spec] faster than real time. Used by WAV export, which must
  /// produce byte identical audio to what playback produces, so export goes
  /// through the engine rather than around it.
  Future<Float32List> renderOffline(RenderSpec spec, int frameCount);

  /// Frames in one pass of [spec]'s pattern. Export multiplies this by the
  /// number of bars asked for.
  int loopFramesFor(RenderSpec spec);
}
