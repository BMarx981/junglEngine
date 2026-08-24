import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../models/kit_slot.dart';
import 'audio_clip.dart';
import 'engine.dart';
import 'pattern_renderer.dart';
import 'platform_session.dart';
import 'wav.dart';

/// flutter_soloud backed engine.
///
/// SoLoud is used purely as an output device: the app renders its own blocks
/// with [PatternRenderer] and pushes them into a PCM buffer stream. That keeps
/// timing sample accurate instead of at the mercy of Dart timer jitter, and it
/// means export and playback are literally the same code.
class _BlockMarker {
  const _BlockMarker({
    required this.pushedFrame,
    required this.loopFrame,
    required this.timeline,
  });

  /// How many frames had been pushed to the device when this block was
  /// rendered.
  final int pushedFrame;

  /// Where the timeline was at the top of the block.
  final int loopFrame;

  /// The timeline this block was rendered against, held rather than looked up
  /// later: a queued Beat swap can replace the renderer's timeline while this
  /// block is still waiting its turn at the device, and the playhead has to
  /// keep reporting the Beat that is audible until then.
  final RenderTimeline timeline;
}

class SoLoudAudioEngine implements AudioEngine {
  SoLoudAudioEngine({this.sampleRate = 44100});

  @override
  final int sampleRate;

  /// One render block. Small enough that an edit lands quickly, large enough
  /// that the render loop is cheap.
  static const int _blockFrames = 1024;

  /// How much audio to keep queued ahead of the playhead. This is also the
  /// worst case delay before a pattern edit becomes audible.
  static const double _queueSeconds = 0.24;

  /// SoLoud pauses a stream that runs closer to the end of its buffer than
  /// this. Kept below [_queueSeconds] so it never trips in normal running.
  static const double _bufferingTimeNeeds = 0.08;

  static const Duration _tick = Duration(milliseconds: 12);

  final ValueNotifier<TransportState> _transport = ValueNotifier(
    const TransportState(),
  );

  @override
  ValueListenable<TransportState> get transport => _transport;

  @override
  bool get isInitialized => _initialized;

  bool _initialized = false;
  bool _shuttingDown = false;

  RenderSpec? _spec;
  PatternRenderer? _renderer;

  AudioSource? _stream;
  SoundHandle? _handle;
  Timer? _feeder;
  int _framesPushed = 0;

  /// Where the pattern was at the start of each block still in flight. The
  /// playhead is read back from these against the frames the device has
  /// actually consumed, so it shows what is audible now, not what has been
  /// rendered ahead.
  final Queue<_BlockMarker> _markers = Queue();

  /// One AudioSource per slice, so tapping a cell is instant instead of waiting
  /// on the render queue.
  final List<AudioSource> _sliceSources = [];
  int _slicedForCount = -1;
  Object? _slicedForClip;
  Future<void>? _slicing;
  int _sliceGeneration = 0;

  /// One AudioSource per Kit slot, for the same reason as the slice sources:
  /// a pad has to sound the instant it is touched, not when the render queue
  /// next comes round.
  final List<AudioSource> _kitSources = [];
  Object? _kitSourcesFor;
  Future<void>? _kitLoading;
  int _kitGeneration = 0;

  /// Whatever the import screen is previewing. One at a time, disposed when the
  /// next one starts, because these are whole files rather than slices and
  /// keeping them around would be keeping the user's whole import in memory
  /// twice.
  AudioSource? _auditionSource;
  int _auditionGeneration = 0;

  late final Float32List _block = Float32List(_blockFrames * 2);
  late final int _queueFrames = (sampleRate * _queueSeconds).round();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await configureAudioSession(stop);
    await SoLoud.instance.init(
      sampleRate: sampleRate,
      channels: Channels.stereo,
    );
    SoLoud.instance.setGlobalVolume(1);
    _initialized = true;
    // SoLoud reports the rate it was asked for and not the device's, so unlike
    // the Lira engine this cannot say whether it is resampling its output. It
    // is the rate half of the A/B all the same: run both engines at whatever
    // the Lira one reports the hardware to be and the resampling stops being a
    // difference between them. See docs/M4.md.
    debugPrint('junglengine: SoLoud engine initialised at $sampleRate Hz');
  }

  @override
  Future<void> shutdown() async {
    _shuttingDown = true;
    await stop();
    await _disposeSliceSources();
    await _disposeKitSources();
    await stopAuditionClip();
    if (_initialized) {
      await SoLoud.instance.disposeAllSources();
      SoLoud.instance.deinit();
      _initialized = false;
    }
    // _transport is deliberately not disposed: it lives as long as the app and
    // painters hold it as their repaint source.
  }

  @override
  Future<void> setSpec(
    RenderSpec spec, {
    SpecChange when = SpecChange.now,
  }) async {
    final playing = _transport.value.playing;
    if (when == SpecChange.nextBar &&
        playing &&
        _renderer != null &&
        _renderer!.canQueue(spec)) {
      // Nothing is torn down and nothing restarts: the swap happens inside the
      // render loop, on the bar line, so the bar that is playing finishes.
      // [_spec] moves now all the same, because auditions and the pad sources
      // belong to the Beat that is being switched to.
      _spec = spec;
      _renderer!.queueSpec(spec);
      unawaited(_ensureSliceSources());
      unawaited(_ensureKitSources());
      return;
    }

    _spec = spec;

    final wasPlaying = playing;
    final renderer = _renderer;
    if (renderer == null || !renderer.canAdopt(spec)) {
      // A different Beat, a different machine or a different break: what is
      // sounding cannot survive the change, so the renderer is rebuilt and
      // playback starts again from the top.
      _renderer = PatternRenderer(spec);
      if (wasPlaying) await _restartStream();
    } else {
      // Swapped in under the running renderer, so painting a step, nudging a
      // repeat count or dragging the tempo never restarts the bar or cuts a
      // ringing slice.
      renderer.updateSpec(spec);
    }

    _transport.value = _transport.value.copyWith(
      stepCount: spec.beat.stepCount,
    );
    unawaited(_ensureSliceSources());
    unawaited(_ensureKitSources());
  }

  @override
  Future<void> cancelQueuedSpec() async {
    final renderer = _renderer;
    if (renderer == null || !renderer.hasQueuedSpec) return;
    renderer.clearQueuedSpec();
    // The queued spec had already been made current for auditions. What is
    // actually playing takes that back.
    _spec = renderer.spec;
    unawaited(_ensureSliceSources());
    unawaited(_ensureKitSources());
  }

  @override
  Future<void> start() async {
    if (!_initialized || _spec == null) return;
    if (_transport.value.playing) return;
    await _restartStream();
  }

  Future<void> _restartStream() async {
    await _teardownStream();
    final renderer = _renderer;
    if (renderer == null) return;

    renderer.rewind();
    _framesPushed = 0;
    _markers.clear();

    final stream = SoLoud.instance.setBufferStream(
      maxBufferSizeBytes: 1024 * 1024 * 1024,
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: _bufferingTimeNeeds,
      sampleRate: sampleRate,
      channels: Channels.stereo,
      format: BufferType.f32le,
    );
    _stream = stream;

    // Prime the queue before the first sample is asked for.
    while (_framesPushed < _queueFrames) {
      _pushBlock();
    }

    _handle = SoLoud.instance.play(stream);
    _transport.value = _transport.value.copyWith(playing: true);
    _feeder = Timer.periodic(_tick, (_) => _onTick());
  }

  @override
  Future<void> stop() async {
    await _teardownStream();
    _renderer?.rewind();
    _transport.value = _transport.value.copyWith(
      playing: false,
      step: 0,
      loopPosition: 0,
      entryIndex: -1,
    );
  }

  Future<void> _teardownStream() async {
    _feeder?.cancel();
    _feeder = null;
    final handle = _handle;
    _handle = null;
    if (handle != null) {
      await SoLoud.instance.stop(handle);
    }
    final stream = _stream;
    _stream = null;
    if (stream != null) {
      try {
        await SoLoud.instance.disposeSource(stream);
      } on SoLoudException {
        // A released buffer stream disposes itself once drained.
      }
    }
    _framesPushed = 0;
    _markers.clear();
  }

  void _onTick() {
    final stream = _stream;
    final renderer = _renderer;
    if (stream == null || renderer == null || _shuttingDown) return;

    try {
      final consumedFrames = _consumedFrames(stream);

      // Top the queue back up. Capped so a stalled UI thread cannot make this
      // spiral into a long synchronous render.
      var pushes = 0;
      while (_framesPushed - consumedFrames < _queueFrames && pushes < 8) {
        _pushBlock();
        pushes++;
      }

      _publishPlayhead(consumedFrames);
    } on SoLoudException {
      // The stream went away underneath us (device change, backgrounding).
      unawaited(stop());
    }
  }

  /// Resolves the audible position from the marker covering [consumedFrames].
  ///
  /// The renderer owns the step boundaries, swing and all, so the frame is
  /// handed back to it rather than divided by an assumed step length here.
  void _publishPlayhead(int consumedFrames) {
    while (_markers.length > 1 &&
        _markers.elementAt(1).pushedFrame <= consumedFrames) {
      _markers.removeFirst();
    }
    if (_markers.isEmpty) return;
    final marker = _markers.first;
    if (marker.timeline.loopFrames <= 0) return;

    final into = consumedFrames - marker.pushedFrame;
    final at = marker.timeline.positionAt(marker.loopFrame + into);

    _transport.value = _transport.value.copyWith(
      step: at.step,
      stepCount: at.stepCount,
      loopPosition: at.position,
      beatId: at.beatId,
      entryIndex: at.entryIndex,
    );
  }

  int _consumedFrames(AudioSource stream) {
    final consumed = SoLoud.instance.getStreamTimeConsumed(stream);
    return (consumed.inMicroseconds * sampleRate / 1000000).round();
  }

  void _pushBlock() {
    final renderer = _renderer;
    final stream = _stream;
    if (renderer == null || stream == null) return;
    _markers.add(
      _BlockMarker(
        pushedFrame: _framesPushed,
        loopFrame: renderer.loopFrame,
        timeline: renderer.timeline,
      ),
    );
    renderer.render(_block, _blockFrames);
    SoLoud.instance.addAudioDataStream(stream, _block.buffer.asUint8List());
    _framesPushed += _blockFrames;
  }

  @override
  Future<void> auditionSlice(int sliceIndex) async {
    if (!_initialized) return;
    await _ensureSliceSources();
    if (sliceIndex < 0 || sliceIndex >= _sliceSources.length) return;
    SoLoud.instance.play(_sliceSources[sliceIndex], volume: 0.92);
  }

  /// Cuts the break into one in-memory source per slice. Re-runs when the
  /// division changes or the project break changes.
  Future<void> _ensureSliceSources() {
    final spec = _spec;
    if (spec == null || !_initialized) return Future.value();
    if (_slicedForCount == spec.beat.sliceCount &&
        identical(_slicedForClip, spec.breakClip)) {
      return _slicing ?? Future.value();
    }
    _slicedForCount = spec.beat.sliceCount;
    _slicedForClip = spec.breakClip;
    return _slicing = _rebuildSliceSources(spec, ++_sliceGeneration);
  }

  /// [generation] guards against a fast run of division changes leaving a
  /// half-built set behind, which would make auditions play the wrong slice.
  Future<void> _rebuildSliceSources(RenderSpec spec, int generation) async {
    await _disposeSliceSources();
    final clip = spec.breakClip;
    final count = spec.beat.sliceCount;
    final total = clip.frames;
    for (var i = 0; i < count; i++) {
      if (generation != _sliceGeneration) return;
      final start = (i * total / count).round();
      final end = ((i + 1) * total / count).round().clamp(0, total);
      if (end <= start) continue;
      final slice = Float32List.sublistView(
        clip.samples,
        start * clip.channels,
        end * clip.channels,
      );
      final bytes = encodeWav(
        Float32List.fromList(slice),
        sampleRate: clip.sampleRate,
        channels: clip.channels,
      );
      if (_shuttingDown) return;
      final source = await SoLoud.instance.loadMem(
        'junglengine-slice-$i.wav',
        bytes,
      );
      if (generation != _sliceGeneration) {
        await SoLoud.instance.disposeSource(source);
        return;
      }
      _sliceSources.add(source);
    }
  }

  Future<void> _disposeSliceSources() async {
    final sources = List<AudioSource>.of(_sliceSources);
    _sliceSources.clear();
    for (final s in sources) {
      try {
        await SoLoud.instance.disposeSource(s);
      } on SoLoudException {
        // Already gone.
      }
    }
  }

  @override
  Future<void> auditionKitSlot(int slot) async {
    if (!_initialized) return;
    await _ensureKitSources();
    if (slot < 0 || slot >= _kitSources.length) return;
    final settings = _spec?.beat.slot(slot) ?? const KitSlot();
    // Started paused so the slot's tuning applies from the first sample instead
    // of sliding into place after it.
    final handle = SoLoud.instance.play(
      _kitSources[slot],
      volume: settings.volume,
      paused: true,
    );
    SoLoud.instance.setRelativePlaySpeed(handle, settings.rate);
    SoLoud.instance.setPause(handle, false);
  }

  @override
  Future<void> auditionClip(AudioClip clip, {bool looping = false}) async {
    if (!_initialized || clip.frames == 0) return;
    final generation = ++_auditionGeneration;
    await stopAuditionClip();
    final bytes = encodeWav(
      clip.samples,
      sampleRate: clip.sampleRate,
      channels: clip.channels,
    );
    final source = await SoLoud.instance.loadMem(
      'junglengine-audition-$generation.wav',
      bytes,
    );
    // A drag across the trim handles can start several of these before the
    // first one finishes loading. Only the newest may be heard.
    if (generation != _auditionGeneration || _shuttingDown) {
      await SoLoud.instance.disposeSource(source);
      return;
    }
    _auditionSource = source;
    SoLoud.instance.play(source, volume: 0.92, looping: looping);
  }

  @override
  Future<void> stopAuditionClip() async {
    final source = _auditionSource;
    _auditionSource = null;
    if (source == null) return;
    try {
      await SoLoud.instance.disposeSource(source);
    } on SoLoudException {
      // Already gone.
    }
  }

  /// Loads one source per Kit slot. One kit per project, so this runs once.
  Future<void> _ensureKitSources() {
    final spec = _spec;
    if (spec == null || !_initialized || spec.kitClips.isEmpty) {
      return Future.value();
    }
    if (identical(_kitSourcesFor, spec.kitClips)) {
      return _kitLoading ?? Future.value();
    }
    _kitSourcesFor = spec.kitClips;
    return _kitLoading = _rebuildKitSources(spec.kitClips, ++_kitGeneration);
  }

  Future<void> _rebuildKitSources(List<AudioClip> clips, int generation) async {
    await _disposeKitSources();
    for (var i = 0; i < clips.length; i++) {
      if (generation != _kitGeneration || _shuttingDown) return;
      final clip = clips[i];
      final bytes = encodeWav(
        clip.samples,
        sampleRate: clip.sampleRate,
        channels: clip.channels,
      );
      final source = await SoLoud.instance.loadMem(
        'junglengine-kit-$i.wav',
        bytes,
      );
      if (generation != _kitGeneration) {
        await SoLoud.instance.disposeSource(source);
        return;
      }
      _kitSources.add(source);
    }
  }

  Future<void> _disposeKitSources() async {
    final sources = List<AudioSource>.of(_kitSources);
    _kitSources.clear();
    for (final s in sources) {
      try {
        await SoLoud.instance.disposeSource(s);
      } on SoLoudException {
        // Already gone.
      }
    }
  }

  @override
  Future<Float32List> renderOffline(RenderSpec spec, int frameCount) async {
    return renderPatternOffline(spec, frameCount);
  }

  @override
  int loopFramesFor(RenderSpec spec) => PatternRenderer(spec).loopFrames;
}

/// Offline render, engine independent so tests and export can call it directly.
///
/// Renders [frameCount] frames plus a tail, then folds the tail back over the
/// start. The ring out of the last hit lands where it would on the next pass,
/// which is what makes the exported file loop seamlessly.
Float32List renderPatternOffline(RenderSpec spec, int frameCount) {
  final renderer = PatternRenderer(spec)..rewind();
  const tailSeconds = 1.2;
  final tailFrames = (spec.sampleRate * tailSeconds).round();

  final out = Float32List(frameCount * 2);
  _renderRun(renderer, out, 0, frameCount);

  // Keep rendering with the sequencer stopped so nothing new triggers, then
  // lay that ring out over the head of the file. It lands where it would on
  // the next pass, which is what makes the export loop seamlessly.
  final tail = Float32List(tailFrames * 2);
  renderer.beginTail();
  _renderRun(renderer, tail, 0, tailFrames);

  final fold = tailFrames < frameCount ? tailFrames : frameCount;
  for (var i = 0; i < fold * 2; i++) {
    out[i] += tail[i];
  }
  return out;
}

void _renderRun(
  PatternRenderer renderer,
  Float32List target,
  int atFrame,
  int frameCount,
) {
  const chunk = 4096;
  final scratch = Float32List(chunk * 2);
  var done = 0;
  while (done < frameCount) {
    final n = (frameCount - done) < chunk ? frameCount - done : chunk;
    renderer.render(scratch, n);
    target.setRange((atFrame + done) * 2, (atFrame + done + n) * 2, scratch);
    done += n;
  }
}

/// Loads and prepares a bundled break for the mixer: stereo, at the engine
/// rate, peak normalised.
Future<AudioClip> loadBreakClip(Uint8List bytes, int sampleRate) async {
  return decodeWav(bytes).toStereo().resampledTo(sampleRate).normalized();
}

/// Loads a bundled one shot: stereo, at the engine rate, left at the level it
/// was recorded at so a kit keeps its balance.
AudioClip loadOneShotClip(Uint8List bytes, int sampleRate) {
  return decodeWav(bytes).toStereo().resampledTo(sampleRate);
}
