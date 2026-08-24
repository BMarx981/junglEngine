import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:junglengine_engine/junglengine_engine.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/engine.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/audio/platform_session.dart';

/// The Rust engine, behind the same interface flutter_soloud sits behind.
///
/// The difference that matters is not speed. The Dart mixer keeps a quarter of
/// a second of audio queued ahead of the playhead because it runs on the event
/// loop, and the event loop is not allowed anywhere near an audio callback. So
/// a quarter of a second is the worst case delay before a painted step is
/// audible, and it is also the accuracy floor of the playhead, which has to be
/// read back from block markers.
///
/// This mixer runs *inside* the callback. An edit lands at the next block, and
/// the playhead is the callback's own frame counter rather than an estimate.
/// See `docs/M4.md`.
///
/// Nothing about the interface changes, which was the point of having one from
/// M0: the grid, the sequencer, the exporter and their tests do not know which
/// of the two is underneath them.
class LiraAudioEngine implements AudioEngine {
  /// [requestedRate] is a request and not a promise. The device decides what
  /// it will actually run at and says so on open, which is why the field
  /// behind [sampleRate] is not final.
  LiraAudioEngine({int requestedRate = 44100}) : _sampleRate = requestedRate;

  int _sampleRate;

  /// The rate the device actually opened at, which a phone decides rather than
  /// the app. Everything the app decodes is resampled to this, so it is read
  /// after [initialize] and before any clip is loaded.
  @override
  int get sampleRate => _sampleRate;

  @override
  bool get isInitialized => _handle != nullptr;

  final ValueNotifier<TransportState> _transport = ValueNotifier(
    const TransportState(),
  );

  @override
  ValueListenable<TransportState> get transport => _transport;

  late final JeBindings _engine = engineBindings;

  Pointer<Void> _handle = nullptr;
  Pointer<JeTransport> _shared = nullptr;

  /// Reads the shared playhead once per rendered frame. A frame is exactly
  /// when the answer is wanted, and reading it is a handful of loads through a
  /// mapped pointer rather than a call into the engine.
  Ticker? _ticker;

  RenderSpec? _spec;

  /// The spec behind each published plan, until the playhead has moved past
  /// it. The engine reports which plan the position it is showing came from,
  /// because during a queued Beat swap that is not the newest spec sent, and a
  /// Beat id is a string the audio callback may not touch.
  final Map<int, RenderSpec> _specsByPlan = {};

  /// What was last uploaded, by identity. A break is seconds of samples and an
  /// edit publishes a spec at pointer rate, so the audio crosses the boundary
  /// when it changes and not when the pattern does.
  Object? _uploadedBreak;
  Object? _uploadedKit;

  /// Scratch for turning the shared struct's `f64::to_bits` back into a double.
  final ByteData _bits = ByteData(8);

  @override
  Future<void> initialize() async {
    if (isInitialized) return;
    await configureAudioSession(stop);

    final handle = _engine.newEngine(_sampleRate);
    if (handle == nullptr) {
      throw StateError(
        _engine.lastError ?? 'junglengine: the audio engine would not open',
      );
    }
    _handle = handle;
    final opened = _engine.sampleRate(handle);
    _shared = _engine.transport(handle);

    // The one number the A/B cannot be read without.
    //
    // cpal reads the platform session's rate rather than asking for one, so
    // this is the hardware's rate and not a preference. When it is not what
    // was asked for, every bundled break and one shot is resampled to it at
    // load by `AudioClip.resampledTo`, which is linear interpolation and was
    // only ever meant to run on the odd asset. See docs/M4.md.
    if (opened != _sampleRate) {
      debugPrint(
        'junglengine: Lira engine asked for $_sampleRate Hz and the device '
        'gave $opened Hz, so every clip is resampled at load',
      );
    } else {
      debugPrint('junglengine: Lira engine open at $opened Hz');
    }
    _sampleRate = opened;
  }

  @override
  Future<void> shutdown() async {
    // Stopped before disposed: a Ticker that is still running asserts on the
    // way out, and shutting down mid playback is the normal case, not a rare
    // one.
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    final handle = _handle;
    _handle = nullptr;
    _shared = nullptr;
    _specsByPlan.clear();
    if (handle != nullptr) _engine.freeEngine(handle);
    // _transport is deliberately not disposed: it lives as long as the app and
    // painters hold it as their repaint source.
  }

  @override
  Future<void> setSpec(
    RenderSpec spec, {
    SpecChange when = SpecChange.now,
  }) async {
    if (!isInitialized) return;
    _spec = spec;
    _uploadSources(spec);

    final json = utf8.encode(jsonEncode(spec.toEngineJson()));
    final buffer = malloc<Uint8>(json.length);
    try {
      buffer.asTypedList(json.length).setAll(0, json);
      _check(_engine.setSpec(_handle, buffer, json.length, when.index));
    } finally {
      malloc.free(buffer);
    }

    _specsByPlan[_engine.lastPlanId(_handle)] = spec;
    if (!_transport.value.playing) {
      _transport.value = _transport.value.copyWith(
        stepCount: spec.beat.stepCount,
      );
    }
  }

  @override
  Future<void> cancelQueuedSpec() async {
    if (!isInitialized) return;
    _check(_engine.cancelQueuedSpec(_handle));
  }

  @override
  Future<void> start() async {
    if (!isInitialized || _spec == null) return;
    if (_transport.value.playing) return;
    _check(_engine.start(_handle));
    _transport.value = _transport.value.copyWith(playing: true);
    (_ticker ??= Ticker(_onFrame)).start();
  }

  @override
  Future<void> stop() async {
    if (!isInitialized) return;
    _check(_engine.stop(_handle));
    _ticker?.stop();
    _transport.value = _transport.value.copyWith(
      playing: false,
      step: 0,
      loopPosition: 0,
      entryIndex: -1,
    );
  }

  @override
  Future<void> auditionSlice(int sliceIndex) async {
    if (!isInitialized) return;
    _check(_engine.auditionSlice(_handle, sliceIndex));
  }

  @override
  Future<void> auditionKitSlot(int slot) async {
    if (!isInitialized) return;
    _check(_engine.auditionKitSlot(_handle, slot));
  }

  @override
  Future<void> auditionClip(AudioClip clip, {bool looping = false}) async {
    if (!isInitialized || clip.frames == 0) return;
    final stereo = clip.toStereo();
    _withSamples(stereo.samples, (pointer) {
      _check(
        _engine.auditionClip(_handle, pointer, stereo.frames, looping ? 1 : 0),
      );
    });
  }

  @override
  Future<void> stopAuditionClip() async {
    if (!isInitialized) return;
    _check(_engine.stopAuditionClip(_handle));
  }

  @override
  Future<Float32List> renderOffline(RenderSpec spec, int frameCount) async {
    if (!isInitialized) {
      throw StateError('junglengine: the engine is not open');
    }
    _uploadSources(spec);
    final json = utf8.encode(jsonEncode(spec.toEngineJson()));
    final specBuffer = malloc<Uint8>(json.length);
    final out = malloc<Float>(frameCount * 2);
    try {
      specBuffer.asTypedList(json.length).setAll(0, json);
      _check(
        _engine.renderOffline(_handle, specBuffer, json.length, frameCount, out),
      );
      // Copied out of native memory rather than viewed into it: the caller
      // keeps this and the buffer goes away in the `finally`.
      return Float32List.fromList(out.asTypedList(frameCount * 2));
    } finally {
      malloc.free(specBuffer);
      malloc.free(out);
    }
  }

  @override
  int loopFramesFor(RenderSpec spec) {
    final json = utf8.encode(jsonEncode(spec.toEngineJson()));
    final buffer = malloc<Uint8>(json.length);
    try {
      buffer.asTypedList(json.length).setAll(0, json);
      final frames = _engine.loopFrames(buffer, json.length);
      if (frames < 0) {
        throw StateError(_engine.lastError ?? 'junglengine: bad spec');
      }
      return frames;
    } finally {
      malloc.free(buffer);
    }
  }

  /// Copies the break and the kit across when they change, and not otherwise.
  ///
  /// Identity is the test, the same one the flutter_soloud engine uses to
  /// decide when to re-cut its audition sources. It is also what makes an edit
  /// adoptable on the other side: the engine's test for "this can be swapped
  /// in under the playhead" is that the new plan reads the same buffer.
  void _uploadSources(RenderSpec spec) {
    if (!identical(_uploadedBreak, spec.breakClip)) {
      _uploadedBreak = spec.breakClip;
      final clip = spec.breakClip.toStereo();
      _withSamples(clip.samples, (pointer) {
        _check(_engine.setBreak(_handle, pointer, clip.frames));
      });
    }

    if (!identical(_uploadedKit, spec.kitClips)) {
      _uploadedKit = spec.kitClips;
      _uploadKit(spec.kitClips);
    }
  }

  void _uploadKit(List<AudioClip> clips) {
    if (clips.isEmpty) {
      _check(_engine.setKit(_handle, nullptr, nullptr, 0));
      return;
    }
    final pointers = malloc<Pointer<Float>>(clips.length);
    final lengths = malloc<Int64>(clips.length);
    final allocated = <Pointer<Float>>[];
    try {
      for (var i = 0; i < clips.length; i++) {
        final clip = clips[i].toStereo();
        final samples = clip.samples;
        final buffer = malloc<Float>(samples.length);
        buffer.asTypedList(samples.length).setAll(0, samples);
        allocated.add(buffer);
        pointers[i] = buffer;
        lengths[i] = clip.frames;
      }
      _check(_engine.setKit(_handle, pointers, lengths, clips.length));
    } finally {
      for (final buffer in allocated) {
        malloc.free(buffer);
      }
      malloc.free(pointers);
      malloc.free(lengths);
    }
  }

  /// Hands `samples` to `body` as native memory, and takes it back afterwards.
  /// The engine copies whatever it is given, so nothing here outlives the call.
  void _withSamples(Float32List samples, void Function(Pointer<Float>) body) {
    final buffer = malloc<Float>(samples.length);
    try {
      buffer.asTypedList(samples.length).setAll(0, samples);
      body(buffer);
    } finally {
      malloc.free(buffer);
    }
  }

  void _onFrame(Duration _) {
    final at = _readShared();
    if (at != null) _transport.value = at;
  }

  /// Reads the shared struct without a lock.
  ///
  /// The audio thread bumps `version` to odd before writing and back to even
  /// after, so a read that sees the same even value either side of it saw a
  /// whole publication rather than half of two. A read that loses the race
  /// simply retries; there is no waiting on either side, and giving up costs
  /// one frame of a playhead that is about to be republished anyway.
  TransportState? _readShared() {
    if (_shared == nullptr) return null;
    final shared = _shared.ref;
    for (var attempt = 0; attempt < 4; attempt++) {
      final before = shared.version;
      if (before.isOdd) continue;

      final planId = shared.planId;
      final step = shared.step;
      final stepCount = shared.stepCount;
      final entryIndex = shared.entryIndex;
      final section = shared.section;
      final playing = shared.playing != 0;
      _bits.setUint64(0, shared.positionBits, Endian.host);

      if (shared.version != before) continue;

      return TransportState(
        playing: playing,
        step: step,
        stepCount: stepCount,
        loopPosition: _bits.getFloat64(0, Endian.host),
        beatId: _beatIdOf(planId, section),
        entryIndex: entryIndex,
      );
    }
    return null;
  }

  /// Which Beat the engine is sounding, resolved against the plan it says the
  /// position came from rather than against the newest spec: during a queued
  /// swap those are different Beats, and the playhead has to report the one
  /// that is audible.
  String _beatIdOf(int planId, int section) {
    _specsByPlan.removeWhere((id, _) => id < planId);
    final spec = _specsByPlan[planId];
    if (spec == null || section < 0 || section >= spec.sections.length) {
      return '';
    }
    return spec.sections[section].beat.id;
  }

  void _check(int code) {
    if (code == jeOk) return;
    // Raw exception text is never shown to the user, and this is not shown to
    // one: an engine that will not take a spec is a bug in this build, not
    // something a translated line helps with.
    debugPrint('junglengine: engine call failed ($code) ${_engine.lastError}');
  }
}
