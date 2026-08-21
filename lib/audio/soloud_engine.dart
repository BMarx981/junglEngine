import 'dart:async';
import 'dart:collection';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_clip.dart';
import 'engine.dart';
import 'pattern_renderer.dart';
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
    required this.loopFrames,
    required this.framesPerStep,
    required this.stepCount,
  });

  final int pushedFrame;
  final int loopFrame;
  final int loopFrames;
  final double framesPerStep;
  final int stepCount;
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

  late final Float32List _block = Float32List(_blockFrames * 2);
  late final int _queueFrames = (sampleRate * _queueSeconds).round();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _configureAudioSession();
    await SoLoud.instance.init(
      sampleRate: sampleRate,
      channels: Channels.stereo,
    );
    SoLoud.instance.setGlobalVolume(1);
    _initialized = true;
  }

  /// flutter_soloud deliberately leaves the platform audio session alone, so
  /// the app has to claim it.
  ///
  /// Without this, iOS defaults to the ambient category and the ringer switch
  /// silences the app. Picking up a phone with the switch on and hearing
  /// nothing is not a verdict on the groove.
  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);

      // A phone call or another app taking the output leaves the feeder
      // pushing into a stream nobody is draining. Stop instead.
      session.interruptionEventStream.listen((event) {
        if (event.begin) unawaited(stop());
      });
      session.becomingNoisyEventStream.listen((_) => unawaited(stop()));
    } on Object catch (error) {
      // Not fatal: on desktop there may be no session to configure.
      debugPrint('junglengine: audio session not configured ($error)');
    }
  }

  @override
  Future<void> shutdown() async {
    _shuttingDown = true;
    await stop();
    await _disposeSliceSources();
    if (_initialized) {
      await SoLoud.instance.disposeAllSources();
      SoLoud.instance.deinit();
      _initialized = false;
    }
    // _transport is deliberately not disposed: it lives as long as the app and
    // painters hold it as their repaint source.
  }

  @override
  Future<void> setSpec(RenderSpec spec) async {
    final previous = _spec;
    _spec = spec;

    final wasPlaying = _transport.value.playing;
    if (_renderer == null || _needsFreshRenderer(previous, spec)) {
      // Tempo, length or the break itself changed: step boundaries moved, so
      // the renderer has to be rebuilt and the pattern starts again from the
      // top.
      _renderer = PatternRenderer(spec);
      if (wasPlaying) await _restartStream();
    } else {
      // Same timeline, different notes. Swapped in under the running renderer,
      // so painting a step does not restart the bar or cut a ringing slice.
      _renderer!.updateSpec(spec);
    }

    _transport.value = _transport.value.copyWith(
      stepCount: spec.beat.stepCount,
    );
    unawaited(_ensureSliceSources());
  }

  /// Tempo is not in this list on purpose: the renderer retempos in place, so
  /// dragging BPM slides the loop instead of restarting it.
  static bool _needsFreshRenderer(RenderSpec? a, RenderSpec b) {
    if (a == null) return true;
    return a.beat.bars != b.beat.bars || !identical(a.breakClip, b.breakClip);
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
  void _publishPlayhead(int consumedFrames) {
    while (_markers.length > 1 && _markers.elementAt(1).pushedFrame <= consumedFrames) {
      _markers.removeFirst();
    }
    if (_markers.isEmpty) return;
    final marker = _markers.first;
    if (marker.loopFrames <= 0 || marker.framesPerStep <= 0) return;

    final into = consumedFrames - marker.pushedFrame;
    final pos = (marker.loopFrame + into) % marker.loopFrames;
    final step = (pos / marker.framesPerStep).floor().clamp(
      0,
      marker.stepCount - 1,
    );

    _transport.value = _transport.value.copyWith(
      step: step,
      stepCount: marker.stepCount,
      loopPosition: pos / marker.loopFrames,
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
        loopFrames: renderer.loopFrames,
        framesPerStep: renderer.framesPerStep,
        stepCount: renderer.stepCount,
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
