import 'package:flutter/foundation.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/engine.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/audio/soloud_engine.dart';
import 'package:junglengine/models/kit_pattern.dart';

/// An [AudioEngine] that makes no sound but records everything it was asked to
/// do, so the UI and the controller can be tested without an audio device.
///
/// It implements the interface exactly, which is also a check that the seam is
/// narrow enough for the Lira engine to sit behind later.
class FakeAudioEngine implements AudioEngine {
  /// Not final, because a real engine's is not: the Lira engine is told its
  /// rate by the device on open, which is after everything holding it has
  /// already been built once.
  @override
  int sampleRate = 44100;

  @override
  bool isInitialized = false;

  final ValueNotifier<TransportState> _transport = ValueNotifier(
    const TransportState(),
  );

  @override
  ValueListenable<TransportState> get transport => _transport;

  final ValueNotifier<EditLatency?> _editLatency = ValueNotifier(null);

  /// Nothing in the app reads this: it is the M4 readout's source and the
  /// readout is only in a build that asked for it. Here so the fake still
  /// implements the interface exactly.
  @override
  ValueListenable<EditLatency?> get editLatency => _editLatency;

  RenderSpec? lastSpec;

  /// What is waiting for a bar line, if anything. See [landQueuedSpec].
  RenderSpec? queuedSpec;
  int cancelledQueues = 0;
  final List<int> auditioned = [];
  final List<int> auditionedSlots = [];

  /// The same auditions with the level each was asked for, null where the tap
  /// was a pad rather than a step. Kept beside [auditionedSlots] rather than
  /// replacing it so a test that only cares which slot sounded stays readable.
  final List<({int slot, KitVelocity? velocity})> auditionedKitTaps = [];
  final List<AudioClip> auditionedClips = [];
  bool auditionLooping = false;
  int auditionStopCount = 0;
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> initialize() async => isInitialized = true;

  @override
  Future<void> shutdown() async {
    isInitialized = false;
    _transport.dispose();
    _editLatency.dispose();
  }

  @override
  Future<void> setSpec(
    RenderSpec spec, {
    SpecChange when = SpecChange.now,
  }) async {
    if (when == SpecChange.nextBar && _transport.value.playing) {
      queuedSpec = spec;
      return;
    }
    lastSpec = spec;
    _transport.value = _transport.value.copyWith(
      stepCount: spec.beat.stepCount,
      beatId: spec.beat.id,
    );
  }

  @override
  Future<void> cancelQueuedSpec() async {
    if (queuedSpec == null) return;
    queuedSpec = null;
    cancelledQueues++;
  }

  /// Runs the queued spec into the bar line, which is what the real engine does
  /// inside its render loop.
  void landQueuedSpec() {
    final spec = queuedSpec;
    if (spec == null) return;
    queuedSpec = null;
    lastSpec = spec;
    _transport.value = _transport.value.copyWith(
      step: 0,
      stepCount: spec.beat.stepCount,
      beatId: spec.beat.id,
    );
  }

  @override
  Future<void> start() async {
    startCount++;
    _transport.value = _transport.value.copyWith(
      playing: true,
      beatId: lastSpec?.beat.id ?? '',
    );
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _transport.value = _transport.value.copyWith(
      playing: false,
      step: 0,
      loopPosition: 0,
    );
  }

  /// Whether the platform has taken the output away.
  bool suspended = false;
  int suspendCount = 0;
  int resumeCount = 0;

  @override
  Future<void> Function()? onSampleRateChanged;

  @override
  Future<void> suspend() async {
    suspended = true;
    suspendCount++;
    await stop();
  }

  @override
  Future<void> resume() async {
    suspended = false;
    resumeCount++;
  }

  /// Comes back at a rate the app did not decode for, the way a phone that
  /// changed route while it was away does. The engine cannot reload the
  /// clips; whoever decoded them has to, and this is how it is told to.
  Future<void> resumeAt(int rate) async {
    sampleRate = rate;
    await resume();
    await onSampleRateChanged?.call();
  }

  @override
  Future<void> auditionSlice(int sliceIndex) async =>
      auditioned.add(sliceIndex);

  @override
  Future<void> auditionKitSlot(int slot, {KitVelocity? velocity}) async {
    auditionedSlots.add(slot);
    auditionedKitTaps.add((slot: slot, velocity: velocity));
  }

  @override
  Future<void> auditionClip(AudioClip clip, {bool looping = false}) async {
    auditionedClips.add(clip);
    auditionLooping = looping;
  }

  @override
  Future<void> stopAuditionClip() async => auditionStopCount++;

  @override
  Future<Float32List> renderOffline(RenderSpec spec, int frameCount) async =>
      renderPatternOffline(spec, frameCount);

  @override
  int loopFramesFor(RenderSpec spec) => PatternRenderer(spec).loopFrames;

  /// Reports an edit-to-audible measurement, the way a real engine does once
  /// the edit is actually sounding.
  void noteEdit({required int engineMicros, int callMicros = 0}) {
    _editLatency.value = EditLatency(
      engineMicros: engineMicros,
      callMicros: callMicros,
    );
  }

  /// Moves the fake playhead, for testing anything that draws it.
  void moveTo(int step, double loopPosition) {
    _transport.value = _transport.value.copyWith(
      step: step,
      loopPosition: loopPosition,
    );
  }
}
