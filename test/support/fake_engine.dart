
import 'package:flutter/foundation.dart';
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
  final List<int> auditioned = [];
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
  Future<void> setSpec(RenderSpec spec) async {
    lastSpec = spec;
    _transport.value = _transport.value.copyWith(
      stepCount: spec.beat.stepCount,
    );
  }

  @override
  Future<void> start() async {
    startCount++;
    _transport.value = _transport.value.copyWith(playing: true);
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
