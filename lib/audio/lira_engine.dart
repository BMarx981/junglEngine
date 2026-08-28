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
import 'package:junglengine/models/kit_pattern.dart';

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

  /// Whether the compiled engine is in this process at all.
  ///
  /// It is not, on Android below API 26: the crate links `libaaudio.so`, which
  /// arrives in Android 8.0, so on 7 the loader refuses the whole shared
  /// object. That is a device this app still runs on, and the answer there is
  /// flutter_soloud rather than silence -- so the flag is a request like the
  /// sample rate is, and this is what answers it. See docs/M4.md.
  ///
  /// Cheap enough to call on the way to building the engine: the library is
  /// opened once and held by the process afterwards.
  static bool get isAvailable {
    try {
      engineBindings;
      return true;
    } on Object catch (error) {
      debugPrint(
        'junglengine: the Lira engine will not load here, staying on '
        'flutter_soloud ($error)',
      );
      return false;
    }
  }

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

  final ValueNotifier<EditLatency?> _editLatency = ValueNotifier(null);

  @override
  ValueListenable<EditLatency?> get editLatency => _editLatency;

  /// The last measurement the callback published, so a republished count is
  /// not read as a new edit.
  int _editSeq = 0;

  /// What the last [setSpec] cost on the UI thread, carried across to the
  /// measurement the engine reports for it. The two halves are taken on
  /// different threads and there is no ticket between them, so a burst of
  /// edits inside one block pairs the newest call with the newest landing.
  /// Over a run of taps that is the same distribution.
  int _lastCallMicros = 0;

  late final JeBindings _engine = engineBindings;

  Pointer<Void> _handle = nullptr;
  Pointer<JeTransport> _shared = nullptr;

  /// Reads the shared playhead once per rendered frame. A frame is exactly
  /// when the answer is wanted, and reading it is a handful of loads through a
  /// mapped pointer rather than a call into the engine.
  Ticker? _ticker;

  RenderSpec? _spec;

  /// Whether [_spec] has been painted since the output went away, and so is
  /// waiting for it to come back. See [setSpec].
  bool _specPending = false;

  /// Whether a reopen is already in flight, so a frame callback that notices a
  /// lost device does not ask for it back sixty times a second.
  bool _reopening = false;

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

  /// Set by the studio, called when the device comes back at a rate the app's
  /// clips were not decoded for. See [AudioEngine.onSampleRateChanged].
  @override
  Future<void> Function()? onSampleRateChanged;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;
    await configureAudioSession(
      onStop: stop,
      onSuspend: suspend,
      onResume: resume,
    );

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
    // load by `AudioClip.resampledTo`, which is band limited and costs a few
    // tens of milliseconds a break. See docs/M4.md.
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
    // A new engine counts its measurements from zero, so this has to as well.
    _editSeq = 0;
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
    if (!_deviceOpen) {
      // Painting carries on during a phone call: the app is still on screen,
      // it is only the output that has gone. Nothing is published into a
      // closed device, because the plan ring is sized for a thumb against a
      // running callback and thirty two edits into one nobody is draining
      // would start pushing the newest out. The spec that is on screen when
      // the output comes back is the one it gets.
      _specPending = true;
      return;
    }
    final started = Stopwatch()..start();
    _uploadSources(spec);

    final json = utf8.encode(jsonEncode(spec.toEngineJson()));
    final buffer = malloc<Uint8>(json.length);
    try {
      buffer.asTypedList(json.length).setAll(0, json);
      _check(_engine.setSpec(_handle, buffer, json.length, when.index));
    } finally {
      malloc.free(buffer);
    }
    // Encoding the spec and copying it across is the app's half of the wait,
    // and it is measured on the thread that is doing the waiting.
    _lastCallMicros = started.elapsedMicroseconds;

    _specPending = false;
    _specsByPlan[_engine.lastPlanId(_handle)] = spec;
    if (!_transport.value.playing) {
      _transport.value = _transport.value.copyWith(
        stepCount: spec.beat.stepCount,
      );
    }
  }

  /// What the engine says its output is doing, read off the same mapped
  /// pointer as the playhead. No call, and no engine state mirrored here that
  /// could disagree with it.
  int get _deviceState =>
      _shared == nullptr ? jeDeviceSuspended : _shared.ref.deviceState;

  bool get _deviceOpen => _deviceState == jeDeviceOpen;

  @override
  Future<void> suspend() async {
    if (!isInitialized) return;
    // Stopped here as well as in the engine: the engine stops the transport it
    // is rendering, and this is the one the grid draws.
    _ticker?.stop();
    _check(_engine.suspend(_handle));
    _transport.value = _transport.value.copyWith(
      playing: false,
      step: 0,
      loopPosition: 0,
      entryIndex: -1,
    );
  }

  @override
  Future<void> resume() async {
    if (!isInitialized || _deviceOpen) return;
    if (_reopening) return;
    _reopening = true;
    try {
      final opened = _engine.resume(_handle);
      if (opened < 0) {
        // Not shown to anyone. Whatever still holds the output will let go of
        // it, and the next interruption ending or the next foreground says so.
        debugPrint(
          'junglengine: the output did not come back ($opened) '
          '${_engine.lastError}',
        );
        return;
      }

      if (opened != _sampleRate) {
        debugPrint(
          'junglengine: the device came back at $opened Hz, was $_sampleRate '
          'Hz, so every clip is resampled again',
        );
        _sampleRate = opened;
        // Whatever is cached over there is at the old rate, and so is whatever
        // the app is holding. Both get replaced by the reload.
        _uploadedBreak = null;
        _uploadedKit = null;
        _specPending = true;
        await onSampleRateChanged?.call();
      }

      // Everything painted while the output was gone, in one publication.
      final spec = _spec;
      if (_specPending && spec != null) await setSpec(spec);
    } finally {
      _reopening = false;
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
    // A thumb on the transport is a person saying they expect sound now, so it
    // is the one place worth reopening a closed output without being told to.
    // If it still will not open there is nothing to start: the button goes
    // back to where it was rather than drawing a playhead over silence.
    if (!_deviceOpen) await resume();
    if (!_deviceOpen) {
      debugPrint('junglengine: nothing to play out of, the output is closed');
      return;
    }
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
    // Taps go nowhere while the output is closed rather than queueing up: a
    // tap is feedback for a finger that has already moved on, and hearing a
    // handful of them at once when the call ends is worse than hearing none.
    if (!isInitialized || !_deviceOpen) return;
    _check(_engine.auditionSlice(_handle, sliceIndex));
  }

  @override
  Future<void> auditionKitSlot(int slot, {KitVelocity? velocity}) async {
    if (!isInitialized || !_deviceOpen) return;
    // 0 is not a level, which is how the engine reads "pad tap, sound it full".
    _check(_engine.auditionKitSlot(_handle, slot, velocity?.toJson() ?? 0));
  }

  @override
  Future<void> auditionClip(AudioClip clip, {bool looping = false}) async {
    if (!isInitialized || !_deviceOpen || clip.frames == 0) return;
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
    // A stream that failed under the playhead: the engine has already closed
    // what was left of it, so there is nothing sounding and nothing to draw.
    // One attempt to take it back from here, because an output that broke
    // without an interruption -- media services restarting, a device
    // disappearing -- has nothing else coming that would say to try.
    if (_deviceState == jeDeviceLost) {
      debugPrint('junglengine: the output went away, asking for it back');
      _ticker?.stop();
      _transport.value = _transport.value.copyWith(
        playing: false,
        step: 0,
        loopPosition: 0,
        entryIndex: -1,
      );
      unawaited(resume());
      return;
    }
    final at = _readShared();
    if (at != null) _transport.value = at;
    _readEditLatency();
  }

  /// Picks up an edit-to-audible measurement the callback left behind.
  ///
  /// Read on the frame callback with the playhead, because that is where the
  /// pointer is already being touched and a measurement that is one frame old
  /// is still the same measurement. The count is written after the latency, so
  /// reading the count, then the latency, then the count again is enough: a
  /// count that did not move means the latency underneath it did not either.
  void _readEditLatency() {
    if (_shared == nullptr) return;
    final shared = _shared.ref;
    final seq = shared.editSeq;
    if (seq == _editSeq) return;
    final micros = shared.editLatencyMicros;
    if (shared.editSeq != seq) return;

    _editSeq = seq;
    _editLatency.value = EditLatency(
      engineMicros: micros,
      callMicros: _lastCallMicros,
    );
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
