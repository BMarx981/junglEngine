import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_clip.dart';
import '../audio/engine.dart';
import '../audio/pattern_renderer.dart';
import '../audio/soloud_engine.dart';
import '../features/export/slices_export.dart';
import '../features/export/wav_export.dart';
import '../features/grid/scramble.dart';
import '../features/grid/slice_analysis.dart';
import '../features/import/audio_import.dart';
import '../features/library/break_library.dart';
import '../features/library/import_store.dart';
import '../features/library/kit_library.dart';
import '../features/telemetry/telemetry.dart';
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

/// Where imported audio is kept. Overridden in tests.
final importStoreProvider = Provider<ImportStore>((ref) => const ImportStore());

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

  /// The open Beat as a MIDI file and the samples it plays, in a zip. One pass,
  /// one Beat: this is the export for finishing somewhere else.
  parts,
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
    this.pendingBeatId,
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

  /// A Beat that has been chosen while the transport is running and is waiting
  /// for the bar to end, or null when nothing is waiting.
  ///
  /// Switching Beats mid bar chops the bar in half, so with the transport
  /// running the choice is queued and the audio layer lands it on the bar line.
  /// [activeBeatId] only moves once the new Beat is actually sounding, so the
  /// grid on screen is always the grid you can hear.
  final String? pendingBeatId;

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
    String? pendingBeatId,
    bool clearPending = false,
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
    pendingBeatId: clearPending ? null : (pendingBeatId ?? this.pendingBeatId),
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

  ImportStore get _imports => ref.read(importStoreProvider);

  Telemetry get _telemetry => ref.read(telemetryProvider);

  @override
  StudioState build() {
    final breakRef = BreakLibrary.defaultBreak;
    final kitRef = KitLibrary.defaultKit;
    final project = _newProject(breakRef, kitRef);
    // A queued Beat switch lands when the audio layer says it has, not when the
    // controller asked for it. See [_onTransport].
    final transport = _engine.transport;
    transport.addListener(_onTransport);
    ref.onDispose(() {
      transport.removeListener(_onTransport);
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
      var project = saved ?? state.project;
      final breakRef = saved == null
          ? state.breakRef
          : await _breakRefFor(project, project.breakId);
      final kitRef = saved == null ? state.kitRef : await _kitRefFor(project);

      // A project can outlive its imported audio: the file gets cleared out of
      // the app's storage by the OS, or a restore brings back the JSON and not
      // the WAV. Falling back to a bundled break is a project that still opens.
      if (breakRef.id != project.breakId) {
        project = project.copyWith(
          breakId: breakRef.id,
          clearImportedBreak: true,
        );
      }

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
      // Imported audio is only reachable through the project, so anything the
      // project stopped pointing at is unreachable rather than spare. A boot is
      // the calm moment to clear it out.
      unawaited(_sweepImports(state.project.importedFileNames));
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
    // A Beat waiting for the bar line was described before this change, so it
    // gets described again: a tempo drag or an edit landing mid queue must not
    // be what the switch takes over with.
    final pending = state.pendingBeatId;
    if (pending != null) {
      final queued = _specFor(state.copyWith(activeBeatId: pending));
      if (queued != null) {
        unawaited(_engine.setSpec(queued, when: SpecChange.nextBar));
      }
    }
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

  /// Opens a Beat from the bank.
  ///
  /// Stopped, that is immediate. Playing, it is a musical move rather than a
  /// navigation one: the Beat is queued and takes over when the bar ends, so
  /// choosing another Beat never chops the bar in half. Tapping the Beat that
  /// is waiting, or the one already playing, calls the switch off.
  void selectBeat(String beatId) {
    if (beatId == state.activeBeatId || beatId == state.pendingBeatId) {
      _cancelPending();
      return;
    }
    if (state.project.beatById(beatId) == null) return;

    if (_queuesSwitch) {
      final queued = _specFor(state.copyWith(activeBeatId: beatId));
      if (queued != null) {
        state = state.copyWith(pendingBeatId: beatId);
        unawaited(_engine.setSpec(queued, when: SpecChange.nextBar));
        return;
      }
    }
    _openBeat(beatId, sync: true);
  }

  /// Whether a Beat switch has to wait for the bar to end.
  ///
  /// Only when what is playing is the open Beat itself. In the Song view the
  /// arrangement decides what sounds, so opening a Beat there changes the grid
  /// and nothing else, and there is nothing to wait for.
  bool get _queuesSwitch => _engine.transport.value.playing && !state.playsSong;

  /// Puts [beatId] on screen, and points the engine at it when [sync] is set.
  void _openBeat(String beatId, {required bool sync}) {
    final beat = state.project.beatById(beatId);
    if (beat == null) {
      state = state.copyWith(clearPending: true);
      return;
    }
    state = state.copyWith(
      activeBeatId: beatId,
      // Bar 1 of whatever you just opened. Beats differ in length, so any
      // carried over page number would land somewhere arbitrary.
      activeBar: 0,
      analysis: _analysisFor(beat),
      clearPending: true,
    );
    if (sync) _syncEngine();
    // Which machine gets lived in, as opposed to which gets made once.
    unawaited(
      _telemetry.log(
        TelemetryEvent.beatOpened,
        parameters: {'machine': beat.machineType.name},
      ),
    );
  }

  /// Calls off a queued switch, on screen and in the audio layer.
  void _cancelPending() {
    if (state.pendingBeatId == null) return;
    state = state.copyWith(clearPending: true);
    unawaited(_engine.cancelQueuedSpec());
  }

  /// Lands a queued Beat switch.
  ///
  /// The audio layer owns when the swap happens, so the screen follows what is
  /// sounding rather than the other way round: the grid changes on the bar
  /// line, at the moment the new Beat becomes audible, not when it was tapped.
  void _onTransport() {
    final pending = state.pendingBeatId;
    if (pending == null) return;
    final transport = _engine.transport.value;
    // Stopping is an answer too: there is no bar left to wait for, so the Beat
    // that was chosen simply opens.
    if (!transport.playing) {
      _openBeat(pending, sync: true);
      return;
    }
    if (transport.beatId == pending) _openBeat(pending, sync: false);
  }

  /// Creates a Beat and opens it. Machine type and length are chosen here and
  /// never change afterwards.
  void addBeat(MachineType machineType, int bars) {
    // Making a Beat is an edit, not a switch: it opens straight away, and any
    // Beat that was waiting for the bar line stops waiting.
    _cancelPending();
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
    unawaited(
      _telemetry.log(
        TelemetryEvent.beatCreated,
        parameters: {'machine': machineType.name, 'bars': beat.bars},
      ),
    );
  }

  /// Copy and tweak, which is the whole point of the bank. The duplicate lands
  /// next to its original and opens straight away.
  void duplicateActiveBeat() {
    _cancelPending();
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
    // Nothing to switch to any more.
    if (beatId == state.pendingBeatId) _cancelPending();
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
    // The timeline is being replaced wholesale, so a Beat waiting for a bar
    // line on the old one has nothing left to wait for.
    _cancelPending();
    state = state.copyWith(view: view);
    _syncEngine();
  }

  /// Opens a Beat from the Song view. The card you tapped is the pattern you
  /// get, which is the only navigation this app has.
  ///
  /// Immediate, unlike tapping a chip on the grid: the view change is already
  /// swapping one timeline for another, so there is no bar to protect.
  void openBeatFromSong(String beatId) {
    _cancelPending();
    // The view change pushes the new spec itself, so opening the Beat only has
    // to do it when the view is not moving.
    final movingView = state.view != StudioView.pattern;
    if (beatId != state.activeBeatId) _openBeat(beatId, sync: !movingView);
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

  /// Drops a Beat from the bank into the arrangement at [index]. Same thing
  /// [addToSong] does, except the arrangement decides where it lands rather
  /// than the end of the list.
  void insertIntoSong(String beatId, int index) {
    if (state.project.beatById(beatId) == null) return;
    state = state.copyWith(
      project: state.project.withSong(
        state.project.song.withEntryAt(SongEntry(beatId: beatId), index),
      ),
    );
    _syncEngine();
  }

  void removeSongEntry(int index) {
    final song = state.project.song;
    if (index < 0 || index >= song.length) return;
    state = state.copyWith(
      project: state.project.withSong(song.withoutAt(index)),
    );
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
    unawaited(_telemetry.log(TelemetryEvent.scrambleTapped));
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
    // An undo that jumps to another Beat is a switch of its own, and it has to
    // show its work now rather than at the bar line.
    if (previous.beatId != state.activeBeatId) _cancelPending();
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

  /// Points the project at a different break, bundled or imported.
  ///
  /// Still one break per project: this changes which one, not how many. Slice
  /// counts are per bar of the break, so every Chop Beat is re-divided at the
  /// division it was already using and any painted slice past the end of the
  /// new break is dropped.
  Future<void> setBreak(String breakId) async {
    if (breakId == state.project.breakId) return;
    final ref = await _breakRefFor(state.project, breakId);
    await _applyBreak(ref, state.project.copyWith(breakId: ref.id));
  }

  /// Loads a break and re-divides every Chop Beat behind it.
  ///
  /// The one place a break change lands, whether it came from the library sheet
  /// or from an import, because the reslicing is the part that must not be
  /// written twice.
  Future<void> _applyBreak(BreakRef ref, Project project) async {
    try {
      final clip = await BreakLibrary.load(ref, _engine.sampleRate);
      final wasBars = state.breakBars;
      final bars = ref.bars < 1 ? 1 : ref.bars;
      final next = project.copyWith(
        beats: [
          for (final beat in project.beats)
            if (beat.isKit)
              beat
            else
              beat.resliced(_divisionOf(beat.sliceCount, wasBars) * bars),
        ],
      );
      final open = next.beatById(state.activeBeatId) ?? next.firstBeat;
      state = state.copyWith(
        project: next,
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
  /// stay where they are: they belong to the Beat, not to the samples. So do
  /// imported one shots, which are per slot and survive a kit change for the
  /// same reason.
  Future<void> setKit(String kitId) async {
    if (kitId == state.project.kitId) return;
    final project = state.project.copyWith(kitId: KitLibrary.byId(kitId).id);
    await _applyKit(project);
  }

  /// Loads the project's kit, imported slot overrides and all.
  Future<void> _applyKit(Project project) async {
    try {
      final ref = await _kitRefFor(project);
      final clips = await KitLibrary.load(ref, _engine.sampleRate);
      state = state.copyWith(project: project, kitRef: ref, kitClips: clips);
      _syncEngine();
    } on Object catch (error) {
      debugPrint('junglengine: kit not loaded ($error)');
    }
  }

  // --- Import --------------------------------------------------------------

  /// The break the project imported, or null when it has none or the file it
  /// pointed at is gone.
  Future<BreakRef?> _importedBreakRef(Project project) async {
    final imported = project.importedBreak;
    if (imported == null) return null;
    if (!await _imports.exists(imported.fileName)) return null;
    return BreakRef.imported(
      id: imported.id,
      name: imported.name,
      filePath: await _imports.pathOf(imported.fileName),
      bpm: imported.bpm,
      bars: imported.bars,
    );
  }

  /// Resolves a break id against the imported break first and the bundle
  /// second. An id that matches neither falls back to the default break, which
  /// is what [BreakLibrary.byId] already does.
  Future<BreakRef> _breakRefFor(Project project, String breakId) async {
    final imported = await _importedBreakRef(project);
    if (imported != null && imported.id == breakId) return imported;
    return BreakLibrary.byId(breakId);
  }

  /// The bundled kit with the project's imported one shots patched over it.
  ///
  /// Resolving to one effective [KitRef] here is what keeps imports out of
  /// everything downstream: loading, the grid gutter and audition all go on
  /// treating a kit as eight samples in order.
  Future<KitRef> _kitRefFor(Project project) async {
    var ref = KitLibrary.byId(project.kitId);
    for (final slot in project.importedSlots) {
      if (slot.slot < 0 || slot.slot >= ref.samples.length) continue;
      if (!await _imports.exists(slot.fileName)) continue;
      ref = ref.withSample(
        slot.slot,
        KitSampleRef.imported(
          label: slot.label,
          filePath: await _imports.pathOf(slot.fileName),
        ),
      );
    }
    return ref;
  }

  /// Writes the trimmed import and makes it the project break.
  ///
  /// The project moves to the break's tempo, the same as a new project does,
  /// because that is what makes the identity pattern reconstruct the loop the
  /// user just trimmed. Importing a break and hearing it out of time would read
  /// as a broken import rather than a tempo mismatch.
  Future<void> useImportedBreak(
    ImportCandidate candidate,
    TrimSelection trim,
    double bpm,
  ) async {
    final imported = await writeImportedBreak(
      store: _imports,
      candidate: candidate,
      trim: trim,
      bpm: bpm.clamp(minBpm, maxBpm),
      stamp: DateTime.now().millisecondsSinceEpoch,
    );
    final project = state.project.withImportedBreak(imported);
    final ref = BreakRef.imported(
      id: imported.id,
      name: imported.name,
      filePath: await _imports.pathOf(imported.fileName),
      bpm: imported.bpm,
      bars: imported.bars,
    );
    await _applyBreak(ref, project);
    await _sweepImports(state.project.importedFileNames);
  }

  /// Puts an imported one shot in a Kit slot.
  ///
  /// Slots stay positional: this changes what slot [slot] plays and nothing
  /// else, so the Beat's volume and pitch for that position carry over exactly
  /// as they do when the whole kit is switched.
  Future<void> importSlotSample(int slot, ImportCandidate candidate) async {
    if (slot < 0 || slot >= state.kitRef.samples.length) return;
    final imported = await writeImportedSlot(
      store: _imports,
      candidate: candidate,
      slot: slot,
      stamp: DateTime.now().millisecondsSinceEpoch,
    );
    await _applyKit(state.project.withImportedSlot(imported));
    await _sweepImports(state.project.importedFileNames);
    unawaited(_engine.auditionKitSlot(slot));
  }

  /// Puts a slot back on the bundled kit's own sample.
  Future<void> clearImportedSlot(int slot) async {
    if (state.project.importedSlot(slot) == null) return;
    await _applyKit(state.project.withoutImportedSlot(slot));
    await _sweepImports(state.project.importedFileNames);
  }

  /// Deletes imported files the project no longer points at.
  ///
  /// Takes the names rather than reading them off [state], because this is
  /// deliberately fired and forgotten: the controller can be disposed while the
  /// directory listing is still in flight, and a sweep that reached back into
  /// state afterwards would throw into nobody's hands.
  Future<void> _sweepImports(Set<String> keep) async {
    try {
      await _imports.sweep(keep);
    } on Object catch (error) {
      debugPrint('junglengine: imports not swept ($error)');
    }
  }

  /// Previews arbitrary audio, for the import screen. Never touches the
  /// transport: what is being auditioned is not in the project yet.
  Future<void> auditionClip(AudioClip clip, {bool looping = false}) =>
      _engine.auditionClip(clip, looping: looping);

  Future<void> stopAuditionClip() => _engine.stopAuditionClip();

  // --- Export --------------------------------------------------------------

  void setExportRepeats(int repeats) =>
      state = state.copyWith(exportRepeats: repeats);

  void setExportMode(ExportMode mode) =>
      state = state.copyWith(exportMode: mode);

  /// Renders whichever of the three things [StudioState.exportMode] is set to.
  ///
  /// A song renders once through: repeating an arrangement is what the repeat
  /// counts are for. The parts export renders no audio timeline at all, so it
  /// goes its own way from here.
  Future<ExportResult?> exportWav() async {
    if (state.exporting) return null;
    if (state.exportMode == ExportMode.parts) return exportParts();

    final song = state.exportMode == ExportMode.song;
    final spec = song ? _songSpec() : _specFor(state);
    if (spec == null) return null;
    final bars = song
        ? state.project.songBars
        : state.exportRepeats * state.beat.bars;
    state = state.copyWith(exporting: true);
    try {
      final result = await WavExporter.export(
        engine: _engine,
        spec: spec,
        repeats: song ? 1 : state.exportRepeats,
        name: song ? state.project.name : state.beat.name,
      );
      unawaited(
        _telemetry.log(
          TelemetryEvent.exportCompleted,
          parameters: {'kind': song ? 'song' : 'loop', 'bars': bars},
        ),
      );
      return result;
    } finally {
      state = state.copyWith(exporting: false);
    }
  }

  /// The open Beat as MIDI plus the samples it plays.
  Future<ExportResult?> exportParts() async {
    final clip = state.clip;
    if (clip == null) return null;
    final machine = state.beat.machineType.name;
    state = state.copyWith(exporting: true);
    try {
      final result = await SlicesExporter.export(
        beat: state.beat,
        breakClip: clip,
        kitClips: state.kitClips,
        bpm: state.project.bpm,
        projectName: state.project.name,
      );
      unawaited(
        _telemetry.log(
          TelemetryEvent.exportCompleted,
          parameters: {'kind': 'parts', 'machine': machine},
        ),
      );
      return result;
    } finally {
      state = state.copyWith(exporting: false);
    }
  }
}

final studioProvider = NotifierProvider<StudioController, StudioState>(
  StudioController.new,
);
