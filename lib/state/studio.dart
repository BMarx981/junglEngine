import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_clip.dart';
import '../audio/engine.dart';
import '../audio/pattern_renderer.dart';
import '../audio/soloud_engine.dart';
import '../features/export/wav_export.dart';
import '../features/grid/scramble.dart';
import '../features/grid/slice_analysis.dart';
import '../features/library/break_library.dart';
import '../models/beat.dart';
import '../models/break_ref.dart';
import '../models/chop_pattern.dart';
import '../models/machine_type.dart';
import '../models/project.dart';
import '../models/sub_lane.dart';

/// The one engine instance for the app.
final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = SoLoudAudioEngine();
  ref.onDispose(() => unawaited(engine.shutdown()));
  return engine;
});

/// The playhead, straight from the audio layer.
final transportProvider = Provider<ValueListenable<TransportState>>(
  (ref) => ref.watch(audioEngineProvider).transport,
);

enum StudioStatus { loading, ready, failed }

@immutable
class StudioState {
  const StudioState({
    required this.project,
    required this.breakRef,
    this.clip,
    this.analysis,
    this.status = StudioStatus.loading,
    this.errorMessage,
    this.canUndo = false,
    this.exportRepeats = 2,
    this.exporting = false,
  });

  final Project project;
  final BreakRef breakRef;
  final AudioClip? clip;
  final SliceAnalysis? analysis;
  final StudioStatus status;
  final String? errorMessage;
  final bool canUndo;

  /// How many passes of the pattern an export writes.
  final int exportRepeats;
  final bool exporting;

  /// M0 has exactly one Beat. The list is real so M1 can grow it.
  Beat get beat => project.firstBeat;

  bool get isReady => status == StudioStatus.ready && clip != null;

  StudioState copyWith({
    Project? project,
    AudioClip? clip,
    SliceAnalysis? analysis,
    StudioStatus? status,
    String? errorMessage,
    bool? canUndo,
    int? exportRepeats,
    bool? exporting,
  }) => StudioState(
    project: project ?? this.project,
    breakRef: breakRef,
    clip: clip ?? this.clip,
    analysis: analysis ?? this.analysis,
    status: status ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
    canUndo: canUndo ?? this.canUndo,
    exportRepeats: exportRepeats ?? this.exportRepeats,
    exporting: exporting ?? this.exporting,
  );
}

/// Everything the one screen can do.
///
/// Mutations go project first, then get pushed at the engine as a [RenderSpec].
/// Nothing here schedules audio; it hands the audio layer a new description of
/// what should be playing and the audio layer decides when that lands.
class StudioController extends Notifier<StudioState> {
  final List<Beat> _undoStack = [];
  static const int _maxUndo = 24;

  final Random _seeds = Random();

  AudioEngine get _engine => ref.read(audioEngineProvider);

  @override
  StudioState build() {
    final breakRef = BreakLibrary.defaultBreak;
    unawaited(_boot(breakRef));
    return StudioState(project: _newProject(breakRef), breakRef: breakRef);
  }

  static Project _newProject(BreakRef breakRef) {
    const sliceCount = 16;
    return Project(
      id: 'project-1',
      name: 'junglEngine',
      breakId: breakRef.id,
      bpm: breakRef.bpm,
      beats: [
        Beat(
          id: 'beat-1',
          name: 'A',
          machineType: MachineType.chop,
          bars: 1,
          sliceCount: sliceCount,
          // The diagonal, so the very first press of play is the break itself.
          // Scramble is then heard against something, not against silence.
          chop: ChopPattern.identity(sliceCount: sliceCount),
        ),
      ],
    );
  }

  Future<void> _boot(BreakRef breakRef) async {
    try {
      await _engine.initialize();
      final clip = await BreakLibrary.load(breakRef, _engine.sampleRate);
      state = state.copyWith(
        clip: clip,
        analysis: SliceAnalysis.of(clip, state.beat.sliceCount),
        status: StudioStatus.ready,
      );
      await _engine.setSpec(_specFor(state)!);
    } on Object catch (error) {
      state = state.copyWith(
        status: StudioStatus.failed,
        errorMessage: '$error',
      );
    }
  }

  RenderSpec? _specFor(StudioState s) {
    final clip = s.clip;
    if (clip == null) return null;
    return RenderSpec(
      breakClip: clip,
      beat: s.beat,
      bpm: s.project.bpm,
      sampleRate: _engine.sampleRate,
    );
  }

  /// Applies a Beat edit and tells the engine about it.
  void _commit(Beat beat, {bool undoable = false}) {
    if (undoable) {
      _undoStack.add(state.beat);
      if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    }
    state = state.copyWith(
      project: state.project.withBeat(beat),
      canUndo: _undoStack.isNotEmpty,
    );
    _syncEngine();
  }

  void _syncEngine() {
    final spec = _specFor(state);
    if (spec == null) return;
    unawaited(_engine.setSpec(spec));
  }

  // --- Chop grid -----------------------------------------------------------

  /// Tap: place the slice, or clear the step if that slice is already on it.
  void toggleCell(int slice, int step) {
    final beat = state.beat;
    final placing = beat.chop.sliceAt(step) != slice;
    _commit(beat.copyWith(chop: beat.chop.toggled(step, slice)));
    if (placing) unawaited(_engine.auditionSlice(slice));
  }

  /// Drag: always place, never clear, so a swipe paints a run of slices.
  void paintCell(int slice, int step) {
    final beat = state.beat;
    if (beat.chop.sliceAt(step) == slice) return;
    _commit(beat.copyWith(chop: beat.chop.withStep(step, slice)));
    unawaited(_engine.auditionSlice(slice));
  }

  void clearStep(int step) {
    final beat = state.beat;
    if (beat.chop.sliceAt(step) == null) return;
    _commit(beat.copyWith(chop: beat.chop.withStep(step, null)));
  }

  void clearPattern() {
    final beat = state.beat;
    if (beat.chop.isEmpty) return;
    _commit(beat.copyWith(chop: beat.chop.cleared()), undoable: true);
  }

  void setSliceCount(int count) {
    final beat = state.beat;
    if (beat.sliceCount == count) return;
    final clip = state.clip;
    state = state.copyWith(
      analysis: clip == null ? null : SliceAnalysis.of(clip, count),
    );
    _commit(beat.resliced(count), undoable: true);
  }

  /// Rearranges the bar. Seeded, so the same tap is reproducible and the
  /// previous bar is one undo away.
  void scramble() {
    final beat = state.beat;
    final analysis =
        state.analysis ?? SliceAnalysis.flat(beat.sliceCount);
    final next = scrambleWithSeed(beat, analysis, _seeds.nextInt(1 << 31));
    _commit(next, undoable: true);
  }

  /// Split out so tests can pin the seed.
  @visibleForTesting
  static Beat scrambleWithSeed(Beat beat, SliceAnalysis analysis, int seed) {
    return beat.copyWith(
      chop: scramblePattern(
        current: beat.chop,
        analysis: analysis,
        seed: seed,
      ),
    );
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    state = state.copyWith(
      project: state.project.withBeat(previous),
      canUndo: _undoStack.isNotEmpty,
    );
    _syncEngine();
  }

  // --- Sub lane ------------------------------------------------------------

  void setSubStep(int step, int? semitone) {
    final beat = state.beat;
    final current = beat.sub.stepAt(step);
    final next = semitone == null
        ? const SubStep.rest()
        : SubStep(semitone: semitone, tie: current.tie);
    _commit(beat.copyWith(sub: beat.sub.withStep(step, next)));
  }

  void toggleTie(int step) {
    final beat = state.beat;
    _commit(beat.copyWith(sub: beat.sub.toggledTie(step)));
  }

  void clearSub() {
    final beat = state.beat;
    if (beat.sub.isEmpty) return;
    _commit(beat.copyWith(sub: beat.sub.cleared()), undoable: true);
  }

  void setSubParameter(int index, double value) {
    final beat = state.beat;
    _commit(beat.copyWith(subPatch: beat.subPatch.withParameter(index, value)));
  }

  // --- Transport -----------------------------------------------------------

  static const double minBpm = 60;
  static const double maxBpm = 200;

  void setBpm(double bpm) {
    final clamped = bpm.clamp(minBpm, maxBpm);
    if ((clamped - state.project.bpm).abs() < 0.01) return;
    state = state.copyWith(project: state.project.copyWith(bpm: clamped));
    _syncEngine();
  }

  Future<void> togglePlay() async {
    if (!state.isReady) return;
    if (_engine.transport.value.playing) {
      await _engine.stop();
    } else {
      await _engine.start();
    }
  }

  Future<void> auditionSlice(int slice) => _engine.auditionSlice(slice);

  // --- Export --------------------------------------------------------------

  void setExportRepeats(int repeats) =>
      state = state.copyWith(exportRepeats: repeats);

  Future<ExportResult?> exportWav() async {
    final spec = _specFor(state);
    if (spec == null || state.exporting) return null;
    state = state.copyWith(exporting: true);
    try {
      return await WavExporter.exportLoop(
        engine: _engine,
        spec: spec,
        repeats: state.exportRepeats,
        beatName: state.beat.name,
      );
    } finally {
      state = state.copyWith(exporting: false);
    }
  }
}

final studioProvider = NotifierProvider<StudioController, StudioState>(
  StudioController.new,
);
