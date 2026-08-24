import 'package:flutter/foundation.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/engine.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/audio/soloud_engine.dart';

/// An [AudioEngine] that makes no sound but records everything it was asked to
/// do, so the UI and the controller can be tested without an audio device.
///
/// It implements the interface exactly, which is also a check that the seam is
/// narrow enough for the Lira engine to sit behind later.
class FakeAudioEngine implements AudioEngine {
  @override
  final int sampleRate = 44100;

  @override
  bool isInitialized = false;

  final ValueNotifier<TransportState> _transport = ValueNotifier(
    const TransportState(),
  );

  @override
  ValueListenable<TransportState> get transport => _transport;

  RenderSpec? lastSpec;

  /// What is waiting for a bar line, if anything. See [landQueuedSpec].
  RenderSpec? queuedSpec;
  int cancelledQueues = 0;
  final List<int> auditioned = [];
  final List<int> auditionedSlots = [];
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

  @override
  Future<void> auditionSlice(int sliceIndex) async =>
      auditioned.add(sliceIndex);

  @override
  Future<void> auditionKitSlot(int slot) async => auditionedSlots.add(slot);

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

  /// Moves the fake playhead, for testing anything that draws it.
  void moveTo(int step, double loopPosition) {
    _transport.value = _transport.value.copyWith(
      step: step,
      loopPosition: loopPosition,
    );
  }
}
