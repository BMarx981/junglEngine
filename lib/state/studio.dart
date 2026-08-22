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
import '../features/library/kit_library.dart';
import '../models/beat.dart';
import '../models/break_ref.dart';
import '../models/chop_pattern.dart';
import '../models/kit_pattern.dart';
import '../models/kit_ref.dart';
import '../models/machine_type.dart';
import '../models/project.dart';
import '../models/song.dart';
import '../models/step_mod.dart';
import '../models/steps.dart';
import '../models/sub_lane.dart';
import 'project_store.dart';

/// The one engine instance for the app.
final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = SoLoudAudioEngine();
  ref.onDispose(() => unawaited(engine.shutdown()));
  return engine;
});

/// Where the project is saved. Overridden in tests.
final projectStoreProvider = Provider<ProjectStore>(
  (ref) => const ProjectStore(),
);

/// The playhead, straight from the audio layer.
final transportProvider = Provider<ValueListenable<TransportState>>(
  (ref) => ref.watch(audioEngineProvider).transport,
);

enum StudioStatus { loading, ready, failed }

/// Which of the two things the screen is doing.
///
/// Not navigation: the same transport, the same sub synth and the same export
/// button are on screen either way. [song] swaps the grid for the arrangement
/// list and points playback at the whole song instead of one looping pattern.
enum StudioView { pattern, song }

/// What the export button renders.
enum ExportMode {
  /// The open Beat, looped.
  loop,

  /// The whole arrangement, once through.
  song,
}

@immutable
class StudioState {
  const StudioState({
    required this.project,
    required this.breakRef,
    required this.kitRef,
    required this.activeBeatId,
    this.clip,
    this.kitClips = const [],
    this.analysis,
    this.status = StudioStatus.loading,
    this.errorMessage,
    this.canUndo = false,
    this.exportRepeats = 2,
    this.exportMode = ExportMode.loop,
    this.exporting = false,
    this.activeBar = 0,
    this.view = StudioView.pattern,
  });

  final Project project;
  final BreakRef breakRef;
  final KitRef kitRef;
  final AudioClip? clip;

  /// One clip per Kit slot, in slot order.
  final List<AudioClip> kitClips;

  final SliceAnalysis? analysis;
  final StudioStatus status;
  final String? errorMessage;
  final bool canUndo;

  /// Which Beat in the bank is open.
  final String activeBeatId;

  /// Which bar of that Beat the grid is showing. A Beat can be eight bars long
  /// and a phone can show one of them at a thumb friendly size, so the grid is
  /// paged rather than squeezed or scrolled sideways.
  final int activeBar;

  /// How many passes of the pattern an export writes. Loop mode only: a song
  /// export is the arrangement, once.
  final int exportRepeats;
  final ExportMode exportMode;
  final bool exporting;

  /// Grid or arrangement.
  final StudioView view;

  Beat get beat => project.beatById(activeBeatId) ?? project.firstBeat;

  Song get song => project.song;

  bool get inSong => view == StudioView.song;

  /// Whether playback would follow the arrangement rather than loop the open
  /// Beat. An empty song has nothing to play, so the Song view still loops
  /// what is open until a card is added.
  bool get playsSong => inSong && project.songIsPlayable;

  /// Bars in the project break, floored at one so a bad [BreakRef] cannot
  /// divide by zero.
  int get breakBars => breakRef.bars < 1 ? 1 : breakRef.bars;

  /// The division the user picked, in slices per bar. [Beat.sliceCount] holds
  /// the total across the break, which is what the mixer and the grid want.
  int get sliceDivision => beat.sliceCount ~/ breakBars;

  bool get isReady => status == StudioStatus.ready && clip != null;

  /// First step of the bar the grid is showing.
  int get windowStart => activeBar.clamp(0, beat.bars - 1) * stepsPerBar;

  StudioState copyWith({
    Project? project,
    AudioClip? clip,
    List<AudioClip>? kitClips,
    SliceAnalysis? analysis,
    StudioStatus? status,
    String? errorMessage,
    bool? canUndo,
    String? activeBeatId,
    int? activeBar,
    int? exportRepeats,
    ExportMode? exportMode,
    bool? exporting,
    StudioView? view,
    BreakRef? breakRef,
    KitRef? kitRef,
  }) => StudioState(
    project: project ?? this.project,
    breakRef: breakRef ?? this.breakRef,
    kitRef: kitRef ?? this.kitRef,
    clip: clip ?? this.clip,
    kitClips: kitClips ?? this.kitClips,
    analysis: analysis ?? this.analysis,
    status: status ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
    canUndo: canUndo ?? this.canUndo,
    activeBeatId: activeBeatId ?? this.activeBeatId,
    activeBar: activeBar ?? this.activeBar,
    exportRepeats: exportRepeats ?? this.exportRepeats,
    exportMode: exportMode ?? this.exportMode,
    exporting: exporting ?? this.exporting,
    view: view ?? this.view,
  );
}

/// One entry of the undo stack.
///
/// The Beat is remembered with its id, so undoing after switching Beats puts
/// the change back where it came from rather than onto whatever is open now.
class _UndoEntry {
  const _UndoEntry(this.beatId, this.beat);

  final String beatId;
  final Beat beat;
}

/// Everything the one screen can do.
///
/// Mutations go project first, then get pushed at the engine as a [RenderSpec].
/// Nothing here schedules audio; it hands the audio layer a new description of
/// what should be playing and the audio layer decides when that lands.
class StudioController extends Notifier<StudioState> {
  final List<_UndoEntry> _undoStack = [];
  static const int _maxUndo = 24;

  /// How long after the last edit the project is written. Long enough that a
  /// drag across the grid is one save, short enough that nothing is lost when
  /// the app is killed from the switcher.
  static const Duration _saveDelay = Duration(milliseconds: 700);

  /// How long boot waits for storage before opening without it.
  static const Duration _loadTimeout = Duration(seconds: 5);

  final Random _seeds = Random();

  Timer? _saveTimer;

  /// Set when the saved project could not be read. See [_loadSaved].
  bool _savingBlocked = false;

  AudioEngine get _engine => ref.read(audioEngineProvider);

  ProjectStore get _store => ref.read(projectStoreProvider);

  @override
  StudioState build() {
    final breakRef = BreakLibrary.defaultBreak;
    final kitRef = KitLibrary.defaultKit;
    final project = _newProject(breakRef, kitRef);
    ref.onDispose(() {
      _saveTimer?.cancel();
      _saveTimer = null;
    });
    unawaited(_boot());
    return StudioState(
      project: project,
      breakRef: breakRef,
      kitRef: kitRef,
      activeBeatId: project.firstBeat.id,
    );
  }

  static Project _newProject(BreakRef breakRef, KitRef kitRef) {
    return Project(
      id: 'project-1',
      name: 'junglEngine',
      breakId: breakRef.id,
      kitId: kitRef.id,
      bpm: breakRef.bpm,
      beats: [
        _newBeat(
          id: 'beat-1',
          name: 'A',
          machineType: MachineType.chop,
          bars: 1,
          breakRef: breakRef,
        ),
      ],
    );
  }

  /// A Beat that makes a sound the moment you press play.
  ///
  /// Chop opens on the diagonal, which is the break itself. Kit opens on a
  /// plain kick, backbeat and hats. Neither machine ever hands you silence and
  /// a blank grid at the same time.
  static Beat _newBeat({
    required String id,
    required String name,
    required MachineType machineType,
    required int bars,
    required BreakRef breakRef,
  }) {
    final breakBars = breakRef.bars < 1 ? 1 : breakRef.bars;
    final sliceCount = 16 * breakBars;
    return Beat(
      id: id,
      name: name,
      machineType: machineType,
      bars: bars,
      sliceCount: sliceCount,
      chop: machineType == MachineType.chop
          ? ChopPattern.identity(bars: bars, sliceCount: sliceCount)
          : ChopPattern.empty(bars: bars),
      kit: machineType == MachineType.kit
          ? KitPattern.starter(bars: bars)
          : KitPattern.empty(bars: bars),
    );
  }

  Future<void> _boot() async {
    try {
      await _engine.initialize();

      // A saved project decides which break and kit to load, so this has to
      // happen before either of them is read off the bundle.
      final saved = await _loadSaved();
      final breakRef = saved == null
          ? state.breakRef
          : BreakLibrary.byId(saved.breakId);
      final kitRef = saved == null
          ? state.kitRef
          : KitLibrary.byId(saved.kitId);
      final project = saved ?? state.project;

      final clip = await BreakLibrary.load(breakRef, _engine.sampleRate);
      final kitClips = await KitLibrary.load(kitRef, _engine.sampleRate);

      state = state.copyWith(
        project: project,
        breakRef: breakRef,
        kitRef: kitRef,
        activeBeatId: project.firstBeat.id,
        activeBar: 0,
        clip: clip,
        kitClips: kitClips,
        analysis: SliceAnalysis.of(clip, project.firstBeat.sliceCount),
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

  /// Reads the saved project, giving up after [_loadTimeout].
  ///
  /// Storage lives behind a platform channel, and a channel that never answers
  /// would otherwise leave the app on the loading screen forever. Opening is
  /// more important than opening the last project, but a load that timed out is
  /// not the same as no saved project: saving is switched off for the session
  /// so a file that could not be read is never written over.
  Future<Project?> _loadSaved() async {
    try {
      return await _store.load().timeout(_loadTimeout);
    } on Object catch (error) {
      _savingBlocked = true;
      debugPrint(
        'junglengine: project storage unavailable ($error). '
        'Opening a new project and leaving whatever is saved alone.',
      );
      return null;
    }
  }

  /// What should be playing: the open Beat on a loop, or the arrangement.
  RenderSpec? _specFor(StudioState s) {
    final sections = s.inSong ? _songSections(s) : const <RenderSection>[];
    return sections.isEmpty
        ? _specOf(s, [RenderSection(beat: s.beat)])
        : _specOf(s, sections);
  }

  /// The song flattened into one section per pass.
  ///
  /// Repeats are expanded here rather than in the sequencer, which is what
  /// makes playback across machine types seamless: by the time the mixer sees
  /// it, an arrangement is just a longer list of patterns to walk.
  static List<RenderSection> _songSections(StudioState s) {
    final sections = <RenderSection>[];
    final entries = s.project.song.entries;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final beat = s.project.beatById(entry.beatId);
      if (beat == null) continue;
      for (var pass = 0; pass < entry.repeats; pass++) {
        sections.add(RenderSection(beat: beat, entryIndex: index));
      }
    }
    return sections;
  }

  /// A spec for the whole arrangement, whatever the screen is showing. Used by
  /// song export, which does not care which view you are in.
  RenderSpec? _songSpec() {
    final sections = _songSections(state);
    return sections.isEmpty ? null : _specOf(state, sections);
  }

  /// The one place a [RenderSpec] is built: same clips, same tempo, same
  /// sample rate, whatever is on the timeline.
  RenderSpec? _specOf(StudioState s, List<RenderSection> sections) {
    final clip = s.clip;
    if (clip == null) return null;
    return RenderSpec.of(
      breakClip: clip,
      kitClips: s.kitClips,
      sections: sections,
      bpm: s.project.bpm,
      sampleRate: _engine.sampleRate,
    );
  }

  /// Applies a Beat edit and tells the engine about it.
  void _commit(Beat beat, {bool undoable = false}) {
    if (undoable) {
      _undoStack.add(_UndoEntry(beat.id, state.project.beatById(beat.id)!));
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
    _scheduleSave();
  }

  // --- Persistence ---------------------------------------------------------

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () => unawaited(_write()));
  }

  /// Writes now rather than on the timer. Called when the app goes to the
  /// background, which on a phone is the most likely last moment there is.
  Future<void> flushSave() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _write();
  }

  Future<void> _write() async {
    if (_savingBlocked || state.status != StudioStatus.ready) return;
    try {
      await _store.save(state.project);
    } on Object catch (error) {
      debugPrint('junglengine: project not saved ($error)');
    }
  }

  // --- Beat bank -----------------------------------------------------------

  void selectBeat(String beatId) {
    if (beatId == state.activeBeatId) return;
    final beat = state.project.beatById(beatId);
    if (beat == null) return;
    state = state.copyWith(
      activeBeatId: beatId,
      // Bar 1 of whatever you just opened. Beats differ in length, so any
      // carried over page number would land somewhere arbitrary.
      activeBar: 0,
      analysis: _analysisFor(beat),
    );
    _syncEngine();
  }

  /// Creates a Beat and opens it. Machine type and length are chosen here and
  /// never change afterwards.
  void addBeat(MachineType machineType, int bars) {
    final project = state.project;
    final beat = _newBeat(
      id: project.nextBeatId(),
      name: project.nextBeatName(),
      machineType: machineType,
      bars: allowedBarLengths.contains(bars) ? bars : 1,
      breakRef: state.breakRef,
    );
    state = state.copyWith(
      project: project.withNewBeat(beat),
      activeBeatId: beat.id,
      activeBar: 0,
      analysis: _analysisFor(beat),
    );
    _syncEngine();
  }

  /// Copy and tweak, which is the whole point of the bank. The duplicate lands
  /// next to its original and opens straight away.
  void duplicateActiveBeat() {
    final project = state.project;
    final source = state.beat;
    final copy = source.duplicate(
      id: project.nextBeatId(),
      name: project.nextBeatName(),
    );
    state = state.copyWith(
      project: project.withBeatAfter(source.id, copy),
      activeBeatId: copy.id,
      activeBar: 0,
    );
    _syncEngine();
  }

  /// Removes a Beat. The last one is never removed: there is always something
  /// open.
  void deleteBeat(String beatId) {
    final project = state.project;
    if (project.beats.length <= 1) return;
    final index = project.indexOfBeat(beatId);
    if (index < 0) return;

    final next = project.withoutBeat(beatId);
    _undoStack.removeWhere((entry) => entry.beatId == beatId);
    final opened = beatId == state.activeBeatId
        ? next.beats[index.clamp(0, next.beats.length - 1)]
        : next.beatById(state.activeBeatId)!;
    state = state.copyWith(
      project: next,
      activeBeatId: opened.id,
      activeBar: 0,
      canUndo: _undoStack.isNotEmpty,
      analysis: _analysisFor(opened),
    );
    _syncEngine();
  }

  /// Pages the grid to a bar of the open Beat.
  void setActiveBar(int bar) {
    final clamped = bar.clamp(0, state.beat.bars - 1);
    if (clamped == state.activeBar) return;
    state = state.copyWith(activeBar: clamped);
  }

  // --- Song ----------------------------------------------------------------

  /// Grid or arrangement. Switching while the transport runs restarts it,
  /// because what is playing is a different timeline, not a different view of
  /// the same one.
  void setView(StudioView view) {
    if (view == state.view) return;
    state = state.copyWith(view: view);
    _syncEngine();
  }

  /// Opens a Beat from the Song view. The card you tapped is the pattern you
  /// get, which is the only navigation this app has.
  void openBeatFromSong(String beatId) {
    selectBeat(beatId);
    setView(StudioView.pattern);
  }

  /// Appends a Beat to the arrangement. Defaults to whatever is open, because
  /// the usual move is write a pattern, then put it in the song.
  void addToSong([String? beatId]) {
    final id = beatId ?? state.activeBeatId;
    if (state.project.beatById(id) == null) return;
    state = state.copyWith(
      project: state.project.withSong(
        state.project.song.withEntry(SongEntry(beatId: id)),
      ),
    );
    _syncEngine();
  }

  void removeSongEntry(int index) {
    final song = state.project.song;
    if (index < 0 || index >= song.length) return;
    state = state.copyWith(project: state.project.withSong(song.withoutAt(index)));
    _syncEngine();
  }

  void setSongRepeats(int index, int repeats) {
    final song = state.project.song;
    final entry = song.entryAt(index);
    if (entry == null) return;
    final next = song.withRepeatsAt(index, repeats);
    if (next.entryAt(index)!.repeats == entry.repeats) return;
    state = state.copyWith(project: state.project.withSong(next));
    _syncEngine();
  }

  void moveSongEntry(int from, int to) {
    if (from == to) return;
    state = state.copyWith(
      project: state.project.withSong(state.project.song.moved(from, to)),
    );
    _syncEngine();
  }

  /// The analysis is per slice count, so it only has to be redone when the Beat
  /// being opened divides the break differently.
  SliceAnalysis? _analysisFor(Beat beat) {
    final clip = state.clip;
    if (clip == null) return state.analysis;
    if (state.analysis?.sliceCount == beat.sliceCount) return state.analysis;
    return SliceAnalysis.of(clip, beat.sliceCount);
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

  /// Long press: puts a modifier on a step that already holds a slice.
  ///
  /// Reverse, retrigger, pitch down, half speed. An empty step has nothing to
  /// modify, so this does nothing there rather than inventing a slice.
  void setStepMod(int step, StepMod mod) {
    final beat = state.beat;
    if (beat.isKit) return;
    final next = beat.chop.withMod(step, mod);
    if (identical(next, beat.chop)) return;
    // Deliberately silent. The audition sources are plain slices, so previewing
    // here would play the one thing the modifier is not.
    _commit(beat.copyWith(chop: next));
  }

  void clearStep(int step) {
    final beat = state.beat;
    if (beat.chop.sliceAt(step) == null) return;
    _commit(beat.copyWith(chop: beat.chop.withStep(step, null)));
  }

  /// Clears whichever drum machine the open Beat runs. The sub lane has its own
  /// clear, because losing a bassline you liked to a mis-tap on the drums would
  /// be infuriating.
  void clearPattern() {
    final beat = state.beat;
    if (beat.drumsAreEmpty) return;
    _commit(
      beat.isKit
          ? beat.copyWith(kit: beat.kit.cleared())
          : beat.copyWith(chop: beat.chop.cleared()),
      undoable: true,
    );
  }

  /// [divisionsPerBar] is one of [allowedSliceDivisions]. The break's bar count
  /// turns that into the total number of slices.
  void setSliceDivision(int divisionsPerBar) {
    final beat = state.beat;
    if (beat.isKit) return;
    final count = divisionsPerBar * state.breakBars;
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
    if (beat.isKit) return;
    final analysis = state.analysis ?? SliceAnalysis.flat(beat.sliceCount);
    final next = scrambleWithSeed(beat, analysis, _seeds.nextInt(1 << 31));
    _commit(next, undoable: true);
  }

  /// Split out so tests can pin the seed.
  @visibleForTesting
  static Beat scrambleWithSeed(Beat beat, SliceAnalysis analysis, int seed) {
    return beat.copyWith(
      chop: scramblePattern(current: beat.chop, analysis: analysis, seed: seed),
    );
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    if (state.project.beatById(previous.beatId) == null) {
      state = state.copyWith(canUndo: _undoStack.isNotEmpty);
      return;
    }
    state = state.copyWith(
      project: state.project.withBeat(previous.beat),
      // Undoing something you did on another Beat has to show you that Beat,
      // or the change looks like it did not happen.
      activeBeatId: previous.beatId,
      activeBar: previous.beatId == state.activeBeatId ? state.activeBar : 0,
      canUndo: _undoStack.isNotEmpty,
    );
    _syncEngine();
  }

  // --- Kit machine ---------------------------------------------------------

  /// Tap: hard, medium, soft, off. Placing auditions the slot so you hear what
  /// you just put down even with the transport stopped.
  void cycleKitCell(int slot, int step) {
    final beat = state.beat;
    final next = beat.kit.cycled(slot, step);
    _commit(beat.copyWith(kit: next));
    if (next.velocityAt(slot, step) != null) {
      unawaited(_engine.auditionKitSlot(slot));
    }
  }

  /// Drag: writes one velocity across everything the finger crosses, including
  /// null, which is how a drag erases a run.
  void paintKitCell(int slot, int step, KitVelocity? velocity) {
    final beat = state.beat;
    if (beat.kit.velocityAt(slot, step) == velocity) return;
    _commit(beat.copyWith(kit: beat.kit.withCell(slot, step, velocity)));
    if (velocity != null) unawaited(_engine.auditionKitSlot(slot));
  }

  void setSlotVolume(int slot, double volume) {
    final beat = state.beat;
    _commit(beat.withSlot(slot, beat.slot(slot).copyWith(volume: volume)));
  }

  void setSlotPitch(int slot, int pitch) {
    final beat = state.beat;
    if (beat.slot(slot).pitch == pitch) return;
    _commit(beat.withSlot(slot, beat.slot(slot).copyWith(pitch: pitch)));
    unawaited(_engine.auditionKitSlot(slot));
  }

  Future<void> auditionKitSlot(int slot) => _engine.auditionKitSlot(slot);

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

  /// Accents a sub note, which opens the filter on that note only.
  void toggleAccent(int step) {
    final beat = state.beat;
    final next = beat.sub.toggledAccent(step);
    if (identical(next, beat.sub)) return;
    _commit(beat.copyWith(sub: next));
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

  /// Swing for the open Beat, 0..1. Global per Beat by design: this is the
  /// answer to triplet feel, not a per step nudge.
  void setSwing(double swing) {
    final beat = state.beat;
    final clamped = swing.clamp(0.0, 1.0);
    if ((clamped - beat.swing).abs() < 0.001) return;
    _commit(beat.copyWith(swing: clamped));
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

  // --- Project library -----------------------------------------------------

  /// Points the project at a different bundled break.
  ///
  /// Still one break per project: this changes which one, not how many. Slice
  /// counts are per bar of the break, so every Chop Beat is re-divided at the
  /// division it was already using and any painted slice past the end of the
  /// new break is dropped.
  Future<void> setBreak(String breakId) async {
    if (breakId == state.project.breakId) return;
    final ref = BreakLibrary.byId(breakId);
    try {
      final clip = await BreakLibrary.load(ref, _engine.sampleRate);
      final wasBars = state.breakBars;
      final bars = ref.bars < 1 ? 1 : ref.bars;
      final beats = [
        for (final beat in state.project.beats)
          if (beat.isKit)
            beat
          else
            beat.resliced(_divisionOf(beat.sliceCount, wasBars) * bars),
      ];
      final project = state.project.copyWith(breakId: ref.id, beats: beats);
      final open = project.beatById(state.activeBeatId) ?? project.firstBeat;
      state = state.copyWith(
        project: project,
        breakRef: ref,
        clip: clip,
        analysis: SliceAnalysis.of(clip, open.sliceCount),
      );
      _syncEngine();
    } on Object catch (error) {
      debugPrint('junglengine: break not loaded ($error)');
    }
  }

  /// Slices per bar behind a total, falling back to the middle division if a
  /// file ever holds a total that is not a whole number of divisions.
  static int _divisionOf(int sliceCount, int bars) {
    final division = bars <= 0 ? sliceCount : sliceCount ~/ bars;
    return allowedSliceDivisions.contains(division) ? division : 16;
  }

  /// Points the project at a different bundled kit. Slot volumes and pitches
  /// stay where they are: they belong to the Beat, not to the samples.
  Future<void> setKit(String kitId) async {
    if (kitId == state.project.kitId) return;
    final ref = KitLibrary.byId(kitId);
    try {
      final clips = await KitLibrary.load(ref, _engine.sampleRate);
      state = state.copyWith(
        project: state.project.copyWith(kitId: ref.id),
        kitRef: ref,
        kitClips: clips,
      );
      _syncEngine();
    } on Object catch (error) {
      debugPrint('junglengine: kit not loaded ($error)');
    }
  }

  // --- Export --------------------------------------------------------------

  void setExportRepeats(int repeats) =>
      state = state.copyWith(exportRepeats: repeats);

  void setExportMode(ExportMode mode) =>
      state = state.copyWith(exportMode: mode);

  /// Renders either the open Beat looped or the whole arrangement, depending on
  /// [StudioState.exportMode]. A song renders once through: repeating an
  /// arrangement is what the repeat counts are for.
  Future<ExportResult?> exportWav() async {
    if (state.exporting) return null;
    final song = state.exportMode == ExportMode.song;
    final spec = song ? _songSpec() : _specFor(state);
    if (spec == null) return null;
    state = state.copyWith(exporting: true);
    try {
      return await WavExporter.export(
        engine: _engine,
        spec: spec,
        repeats: song ? 1 : state.exportRepeats,
        name: song ? state.project.name : state.beat.name,
      );
    } finally {
      state = state.copyWith(exporting: false);
    }
  }
}

final studioProvider = NotifierProvider<StudioController, StudioState>(
  StudioController.new,
);
