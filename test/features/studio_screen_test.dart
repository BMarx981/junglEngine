import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/features/bass/sub_editor.dart';
import 'package:junglengine/features/bass/sub_lane_view.dart';
import 'package:junglengine/features/grid/chop_grid.dart';
import 'package:junglengine/features/grid/step_mod_sheet.dart';
import 'package:junglengine/features/song/song_view.dart';
import 'package:junglengine/models/step_mod.dart';
import 'package:junglengine/features/kit/kit_grid.dart';
import 'package:junglengine/features/song/beat_bar.dart';
import 'package:junglengine/features/song/new_beat_sheet.dart';
import 'package:junglengine/features/transport/bar_strip.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/features/library/break_library.dart';
import 'package:junglengine/features/studio_screen.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/features/transport/action_bar.dart';
import 'package:junglengine/features/transport/transport_bar.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

import 'package:junglengine/features/export/export_sheet.dart';
import 'package:junglengine/features/pro/paywall.dart';
import 'package:junglengine/features/pro/pro_controller.dart';

import '../support/fake_engine.dart';
import '../support/fake_pro_store.dart';

/// Slice numbers also live down the side of the grid, so chip and button
/// finders have to say which bar they mean.
Finder inTransportBar(String text) =>
    find.descendant(of: find.byType(TransportBar), matching: find.text(text));

Finder inActionBar(String text) =>
    find.descendant(of: find.byType(ActionBar), matching: find.text(text));

Finder inBeatBar(String text) =>
    find.descendant(of: find.byType(BeatBar), matching: find.text(text));

Finder inNewBeatSheet(String text) =>
    find.descendant(of: find.byType(NewBeatSheet), matching: find.text(text));

Finder inBarStrip(String text) =>
    find.descendant(of: find.byType(BarStrip), matching: find.text(text));

/// The action bar has a SONG button of its own, so the export sheet's chips
/// have to say which SONG they mean.
Finder inExportSheet(String text) =>
    find.descendant(of: find.byType(ExportSheet), matching: find.text(text));

/// Opens the larger sub note editor from the lane's own header.
Future<void> openSubEditor(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(SubLaneView), matching: find.text('SUB')),
  );
  await tester.pumpAndSettle();
}

/// Creates a one bar Kit Beat through the bank, the way a user would.
Future<void> makeKitBeat(WidgetTester tester) async {
  await tester.tap(inBeatBar(l10n.beatBarNew));
  await tester.pumpAndSettle();
  await tester.tap(inNewBeatSheet('KIT'));
  await tester.tap(inNewBeatSheet(l10n.newBeatCreate));
  await tester.pumpAndSettle();
}

Future<FakeAudioEngine> pumpStudio(WidgetTester tester) async {
  // The studio loads its saved project before it opens, and path_provider has
  // no plugin in a test host.
  // Sync on purpose: a widget test runs in fake async, where a real file I/O
  // future would never complete.
  final tempDir = Directory.systemTemp.createTempSync('junglengine-widget');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tempDir.path,
      );
  addTearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final engine = FakeAudioEngine();
  tester.view.physicalSize = const Size(1170, 2532); // iPhone sized
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        // A test host has no App Store and no Play Billing, so the real one
        // would hang on its first call and leave a timeout pending.
        proStoreProvider.overrideWithValue(FakeProStore()),
      ],
      child: MaterialApp(
        // Pinned so the assertions below can read English out of the lookup
        // rather than depending on whatever locale the host happens to be in.
        locale: const Locale('en'),
        localizationsDelegates: junglengineLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: JungleTheme.build(const Locale('en')),
        home: const StudioScreen(),
      ),
    ),
  );
  // The break loads off the asset bundle before the studio appears.
  for (var i = 0; i < 40 && find.byType(ChopGrid).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  return engine;
}

/// English, read out of the generated lookup rather than retyped here.
///
/// Assertions on translated copy go through this, so that rewording a string
/// is a one line change in the ARB rather than a hunt through the tests. The
/// literals that survive below are the ones that are deliberately English in
/// every locale: BPM, KIT, SUB, VOL, PITCH, the kit slot names and the numbers.
late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('boots into the studio with grid, sub lane and transport', (
    tester,
  ) async {
    await pumpStudio(tester);

    expect(find.byType(ChopGrid), findsOneWidget);
    expect(find.byType(SubLaneView), findsOneWidget);
    expect(inTransportBar('170'), findsOneWidget);
    expect(inTransportBar('16'), findsOneWidget);
    expect(inActionBar(l10n.actionScramble), findsOneWidget);
    expect(inActionBar(l10n.actionExport), findsOneWidget);
    // M0 ships one screen. No nav, no settings.
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('play toggles the transport through the engine', (tester) async {
    final engine = await pumpStudio(tester);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(engine.startCount, 1);
    expect(find.byIcon(Icons.stop), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
    expect(engine.stopCount, 1);
  });

  testWidgets('scramble rewrites the bar and lights up undo', (tester) async {
    final engine = await pumpStudio(tester);
    final before = List.of(engine.lastSpec!.beat.chop.steps);

    await tester.tap(inActionBar(l10n.actionScramble));
    await tester.pump();
    expect(engine.lastSpec!.beat.chop.steps, isNot(equals(before)));

    await tester.tap(inActionBar(l10n.actionUndo));
    await tester.pump();
    expect(engine.lastSpec!.beat.chop.steps, equals(before));
  });

  testWidgets('tapping a grid cell paints that slice on that step', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);

    final sliceCount = engine.lastSpec!.beat.sliceCount;
    final grid = tester.getRect(find.byType(ChopGrid));
    final cellsLeft = grid.left + ChopGrid.gutterWidth;
    final cellWidth = (grid.width - ChopGrid.gutterWidth) / 16;
    final rowHeight = (grid.height / sliceCount).clamp(
      ChopGrid.minRowHeight,
      ChopGrid.maxRowHeight,
    );

    // Row 2, step 5. The identity pattern has slice 5 there, so this is a real
    // change.
    await tester.tapAt(
      Offset(cellsLeft + cellWidth * 5.5, grid.top + rowHeight * 2.5),
    );
    await tester.pump();

    expect(engine.lastSpec!.beat.chop.sliceAt(5), 2);
    expect(engine.auditioned, contains(2));
  });

  testWidgets('changing the slice division re-slices the grid', (tester) async {
    final engine = await pumpStudio(tester);
    // Divisions are per bar, so the total scales with the break's length.
    final bars = BreakLibrary.defaultBreak.bars;

    await tester.tap(inTransportBar('32'));
    await tester.pump();
    expect(engine.lastSpec!.beat.sliceCount, 32 * bars);

    await tester.tap(inTransportBar('8'));
    await tester.pump();
    expect(engine.lastSpec!.beat.sliceCount, 8 * bars);

    // The identity pattern reached slice 15, which no longer exists on a one
    // bar break at 8 divisions.
    if (8 * bars <= 15) {
      expect(engine.lastSpec!.beat.chop.sliceAt(12), isNull);
    }
  });

  testWidgets('dragging a sub lane column writes a pitch', (tester) async {
    final engine = await pumpStudio(tester);

    final lane = tester.getRect(find.byType(SubLaneView));
    final pitchTop = lane.top + SubLaneView.headerHeight;
    final columnWidth = lane.width / 16;

    // Column 3, dragged to near the bottom of the pitch area: a low note.
    await tester.dragFrom(
      Offset(lane.left + columnWidth * 3.5, pitchTop + 10),
      const Offset(0, 80),
    );
    await tester.pump();

    final cell = engine.lastSpec!.beat.sub.stepAt(3);
    expect(cell.semitone, isNotNull);
    expect(cell.semitone, lessThan(0));
  });

  testWidgets('the tie strip toggles glide on a sub cell', (tester) async {
    final engine = await pumpStudio(tester);

    final lane = tester.getRect(find.byType(SubLaneView));
    final columnWidth = lane.width / 16;
    final tieY = lane.bottom - SubLaneView.tieHeight / 2;

    await tester.tapAt(Offset(lane.left + columnWidth * 6.5, tieY));
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(6).tie, isTrue);

    await tester.tapAt(Offset(lane.left + columnWidth * 6.5, tieY));
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(6).tie, isFalse);
  });

  testWidgets('the sub editor writes the pitch of the row you tap', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);
    await openSubEditor(tester);

    final roll = tester.getRect(find.byKey(SubEditor.rollKey));
    final columnWidth = roll.width / 16;

    // An empty lane opens with the root row in the middle of the roll, so the
    // vertical centre is the root and one row above it is a semitone up.
    await tester.tapAt(Offset(roll.left + columnWidth * 3.5, roll.center.dy));
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(3).semitone, 0);

    await tester.tapAt(
      Offset(
        roll.left + columnWidth * 5.5,
        roll.center.dy - SubEditor.rowHeight,
      ),
    );
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(5).semitone, 1);

    // A second tap on the note that is already selected clears it.
    await tester.tapAt(
      Offset(
        roll.left + columnWidth * 5.5,
        roll.center.dy - SubEditor.rowHeight,
      ),
    );
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(5).isRest, isTrue);
  });

  testWidgets('the sub editor buttons glide, accent and clear the selection', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);
    await openSubEditor(tester);

    final roll = tester.getRect(find.byKey(SubEditor.rollKey));
    final columnWidth = roll.width / 16;
    await tester.tapAt(Offset(roll.left + columnWidth * 4.5, roll.center.dy));
    await tester.pump();

    // GLIDE is the tie strip's job done with a button you can actually hit.
    await tester.tap(find.text('GLIDE'));
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(4).tie, isTrue);

    await tester.tap(find.text(l10n.subAccent));
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(4).accent, isTrue);

    // Repitching keeps both: they belong to the step, not to the note on it.
    await tester.tapAt(
      Offset(
        roll.left + columnWidth * 4.5,
        roll.center.dy + SubEditor.rowHeight * 2,
      ),
    );
    await tester.pump();
    final repitched = engine.lastSpec!.beat.sub.stepAt(4);
    expect(repitched.semitone, -2);
    expect(repitched.tie, isTrue);
    expect(repitched.accent, isTrue);

    await tester.tap(find.text(l10n.subClearNote));
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(4).isRest, isTrue);
  });

  testWidgets('the sub editor moves a note a step at a time', (tester) async {
    final engine = await pumpStudio(tester);
    await openSubEditor(tester);

    final roll = tester.getRect(find.byKey(SubEditor.rollKey));
    final columnWidth = roll.width / 16;
    await tester.tapAt(
      Offset(
        roll.left + columnWidth * 6.5,
        roll.center.dy - SubEditor.rowHeight * 3,
      ),
    );
    await tester.pump();
    await tester.tap(find.text(l10n.subAccent));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(6).isRest, isTrue);
    final moved = engine.lastSpec!.beat.sub.stepAt(7);
    expect(moved.semitone, 3);
    expect(moved.accent, isTrue, reason: 'the accent travels with the note');

    // The selection follows it, so the next nudge moves the same note again.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(engine.lastSpec!.beat.sub.stepAt(6).semitone, 3);
    expect(engine.lastSpec!.beat.sub.stepAt(7).isRest, isTrue);
  });

  testWidgets('the sub panel exposes exactly five parameters', (tester) async {
    await pumpStudio(tester);

    await tester.tap(inActionBar('SUB'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.subTitle), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(5));
    for (final name in ['TONE', 'CUTOFF', 'DRIVE', 'DECAY', 'GLIDE']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('the export sheet offers one to eight bars', (tester) async {
    await pumpStudio(tester);

    await tester.tap(inActionBar(l10n.actionExport));
    await tester.pumpAndSettle();

    expect(find.text(l10n.exportTitleWav), findsOneWidget);
    expect(find.text(l10n.exportRender), findsOneWidget);
    expect(find.textContaining('2 bars at 170 BPM'), findsOneWidget);
  });

  testWidgets('a Beat chosen while playing blinks until the bar ends', (
    tester,
  ) async {
    /// The chip's own container: the nearest one around its name.
    BoxDecoration chipBox(String name) =>
        tester
                .widget<Container>(
                  find
                      .ancestor(
                        of: inBeatBar(name),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;

    final engine = await pumpStudio(tester);
    await tester.tap(inBeatBar(l10n.beatBarDup));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    await tester.tap(inBeatBar('A'));
    await tester.pump();
    // Part way into the blink, which only runs while a Beat is waiting.
    await tester.pump(const Duration(milliseconds: 190));

    // B is still the Beat being played and drawn; A is only waiting for it.
    expect(chipBox('B').color, JungleTheme.accent);
    expect(chipBox('A').color, JungleTheme.surfaceHigh);
    expect(chipBox('A').border!.top.color, isNot(JungleTheme.line));
    expect(engine.lastSpec!.beat.name, 'B');
    expect(engine.queuedSpec!.beat.name, 'A');

    // The bar ends and the grid goes with it.
    engine.landQueuedSpec();
    await tester.pump();

    expect(chipBox('A').color, JungleTheme.accent);
    expect(chipBox('B').color, JungleTheme.surfaceHigh);
  });

  testWidgets('the beat bank opens with one Beat and a way to make more', (
    tester,
  ) async {
    await pumpStudio(tester);

    expect(find.byType(BeatBar), findsOneWidget);
    expect(inBeatBar('A'), findsOneWidget);
    expect(inBeatBar(l10n.beatBarDup), findsOneWidget);
    expect(inBeatBar(l10n.beatBarNew), findsOneWidget);
    // One bar Beat: nothing to page through.
    expect(find.byType(BarStrip), findsOneWidget);
    expect(inBarStrip(l10n.barStripLabel), findsNothing);
  });

  testWidgets('duplicate puts a second Beat in the bank and opens it', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);

    await tester.tap(inBeatBar(l10n.beatBarDup));
    await tester.pump();

    expect(inBeatBar('B'), findsOneWidget);
    expect(engine.lastSpec!.beat.name, 'B');
  });

  testWidgets('a Kit Beat is created from the bank and swaps in the kit grid', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);

    await tester.tap(inBeatBar(l10n.beatBarNew));
    await tester.pumpAndSettle();
    expect(find.text(l10n.newBeatTitle), findsOneWidget);

    await tester.tap(inNewBeatSheet('KIT'));
    await tester.tap(inNewBeatSheet('4'));
    await tester.tap(inNewBeatSheet(l10n.newBeatCreate));
    await tester.pumpAndSettle();

    expect(find.byType(KitGrid), findsOneWidget);
    expect(find.byType(ChopGrid), findsNothing);
    // The sub lane is on both machines.
    expect(find.byType(SubLaneView), findsOneWidget);
    expect(engine.lastSpec!.beat.isKit, isTrue);
    expect(engine.lastSpec!.beat.bars, 4);
    // Four bars is four pages.
    expect(inBarStrip(l10n.barStripLabel), findsOneWidget);
    expect(inBarStrip('4'), findsOneWidget);
  });

  testWidgets('tapping a kit cell places a hit on that slot and step', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);
    await makeKitBeat(tester);

    final grid = tester.getRect(find.byType(KitGrid));
    final rowHeight = ((grid.height - KitGrid.headerHeight) / 8).clamp(
      KitGrid.minRowHeight,
      KitGrid.maxRowHeight,
    );
    final cellsLeft = grid.left + KitGrid.gutterWidth;
    final cellWidth = (grid.width - KitGrid.gutterWidth) / 16;
    final rowsTop = grid.top + KitGrid.headerHeight;

    // Slot 2, step 5.
    await tester.tapAt(
      Offset(cellsLeft + cellWidth * 5.5, rowsTop + rowHeight * 2.5),
    );
    await tester.pump();

    expect(engine.lastSpec!.beat.kit.velocityAt(2, 5), KitVelocity.hard);
    expect(engine.auditionedSlots, contains(2));
  });

  testWidgets('holding a pad opens its volume and pitch, and nothing else', (
    tester,
  ) async {
    await pumpStudio(tester);
    await makeKitBeat(tester);

    await tester.longPress(find.text('KICK'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.kitSlot(1)), findsOneWidget);
    expect(find.text('VOL'), findsOneWidget);
    expect(find.text('PITCH'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2));
  });

  testWidgets('scramble is off on a Kit Beat, which has no slices to shuffle', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);
    await makeKitBeat(tester);
    final before = engine.lastSpec!.beat.kit.toJson();

    await tester.tap(inActionBar(l10n.actionScramble));
    await tester.pump();

    expect(engine.lastSpec!.beat.kit.toJson(), before);
    // Slice divisions are a Chop idea too, so the Kit Beat says what it plays.
    expect(inTransportBar('KIT'), findsOneWidget);
    expect(inTransportBar('16'), findsNothing);
  });

  testWidgets('paging to another bar writes to that bar of the pattern', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);

    await tester.tap(inBeatBar(l10n.beatBarNew));
    await tester.pumpAndSettle();
    await tester.tap(inNewBeatSheet('4'));
    await tester.tap(inNewBeatSheet(l10n.newBeatCreate));
    await tester.pumpAndSettle();

    await tester.tap(inBarStrip('3'));
    await tester.pump();

    final grid = tester.getRect(find.byType(ChopGrid));
    final sliceCount = engine.lastSpec!.beat.sliceCount;
    final rowHeight = (grid.height / sliceCount).clamp(
      ChopGrid.minRowHeight,
      ChopGrid.maxRowHeight,
    );
    final cellsLeft = grid.left + ChopGrid.gutterWidth;
    final cellWidth = (grid.width - ChopGrid.gutterWidth) / 16;

    // Row 1, first column of the third bar: step 32 of the pattern.
    await tester.tapAt(
      Offset(cellsLeft + cellWidth * 0.5, grid.top + rowHeight * 1.5),
    );
    await tester.pump();

    expect(engine.lastSpec!.beat.chop.sliceAt(32), 1);
  });

  testWidgets('holding a painted cell opens the step modifier picker', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);

    final grid = tester.getRect(find.byType(ChopGrid));
    final sliceCount = engine.lastSpec!.beat.sliceCount;
    final rowHeight = (grid.height / sliceCount).clamp(
      ChopGrid.minRowHeight,
      ChopGrid.maxRowHeight,
    );
    final cellsLeft = grid.left + ChopGrid.gutterWidth;
    final cellWidth = (grid.width - ChopGrid.gutterWidth) / 16;

    // The identity pattern has slice 2 on step 2, so this cell has a hit on it.
    await tester.longPressAt(
      Offset(cellsLeft + cellWidth * 2.5, grid.top + rowHeight * 2.5),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StepModSheet), findsOneWidget);
    expect(find.text('SLICE 3'), findsOneWidget);
    for (final label in ['PLAIN', 'REVERSE', 'RETRIG', 'PITCH DOWN']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('HALF SPEED'));
    await tester.pumpAndSettle();

    expect(engine.lastSpec!.beat.chop.modAt(2), StepMod.halfSpeed);
  });

  testWidgets('the song view arranges cards and plays them', (tester) async {
    final engine = await pumpStudio(tester);

    await tester.tap(inBeatBar('SONG'));
    await tester.pumpAndSettle();

    // The grid and the sub lane give way to the arrangement. The bank stays:
    // in the Song view it is the palette the ADD button adds from.
    expect(find.byType(SongView), findsOneWidget);
    expect(find.byType(ChopGrid), findsNothing);
    expect(find.byType(SubLaneView), findsNothing);
    expect(find.byType(BeatBar), findsOneWidget);
    expect(inBeatBar('GRID'), findsOneWidget);
    expect(find.textContaining('NOTHING ARRANGED'), findsOneWidget);

    await tester.tap(inActionBar(l10n.actionAddBeat(iso('A'))));
    await tester.pump();

    expect(find.text('1x'), findsOneWidget);
    expect(find.text('1 CARD   1 BAR'), findsOneWidget);
    expect(engine.lastSpec!.isSong, isTrue);
    expect(engine.lastSpec!.sections, hasLength(1));

    // The stepper is the whole of arranging: one card, played four times.
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();

    expect(find.text('3x'), findsOneWidget);
    expect(find.text('1 CARD   3 BARS'), findsOneWidget);
    expect(engine.lastSpec!.sections, hasLength(3));
  });

  testWidgets('tapping a card opens that Beat back on the grid', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);

    await tester.tap(inBeatBar(l10n.beatBarDup));
    await tester.pump();
    await tester.tap(inBeatBar('SONG'));
    await tester.pumpAndSettle();
    await tester.tap(inActionBar(l10n.actionAddBeat(iso('B'))));
    await tester.pump();

    // The card, not the bank chip of the same name.
    await tester.tap(
      find.descendant(of: find.byType(SongView), matching: find.text('B')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChopGrid), findsOneWidget);
    expect(engine.lastSpec!.isSong, isFalse);
    expect(engine.lastSpec!.beat.name, 'B');
  });

  testWidgets('the bank picks what the song view adds', (tester) async {
    final engine = await pumpStudio(tester);

    await tester.tap(inBeatBar(l10n.beatBarDup));
    await tester.pump();
    await tester.tap(inBeatBar('SONG'));
    await tester.pumpAndSettle();

    // Opened on B after the duplicate. Tapping A in the bank makes A what the
    // ADD button adds, without leaving the arrangement.
    expect(inActionBar(l10n.actionAddBeat(iso('B'))), findsOneWidget);
    await tester.tap(inBeatBar('A'));
    await tester.pump();
    expect(inActionBar(l10n.actionAddBeat(iso('A'))), findsOneWidget);
    expect(find.byType(SongView), findsOneWidget);

    await tester.tap(inActionBar(l10n.actionAddBeat(iso('A'))));
    await tester.pump();

    expect(engine.lastSpec!.sections.single.beat.name, 'A');
  });

  testWidgets('a bank chip drags into the arrangement', (tester) async {
    final engine = await pumpStudio(tester);

    await tester.tap(inBeatBar(l10n.beatBarDup));
    await tester.pump();
    await tester.tap(inBeatBar('SONG'));
    await tester.pumpAndSettle();
    await tester.tap(inActionBar(l10n.actionAddBeat(iso('B'))));
    await tester.pump();

    final card = find.descendant(
      of: find.byType(SongView),
      matching: find.text('B'),
    );

    // Straight down out of the bank, because sideways is the bank scrolling.
    final gesture = await tester.startGesture(tester.getCenter(inBeatBar('A')));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    // Above the middle of the only card, which means in front of it.
    await gesture.moveTo(tester.getCenter(card) - const Offset(0, 18));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(engine.lastSpec!.sections.map((s) => s.beat.name).toList(), [
      'A',
      'B',
    ]);
    expect(find.text('2 CARDS   2 BARS'), findsOneWidget);
  });

  testWidgets('the library sheet switches the project break', (tester) async {
    final engine = await pumpStudio(tester);

    await tester.tap(find.text(BreakLibrary.defaultBreak.name.toUpperCase()));
    await tester.pumpAndSettle();

    expect(find.text('BREAK'), findsOneWidget);
    expect(find.text('KIT'), findsOneWidget);
    expect(find.text('ROLLER'), findsOneWidget);

    await tester.tap(find.text('STEPPA'));
    await tester.pumpAndSettle();

    expect(engine.lastSpec!.beat.sliceCount, 16);
    expect(inTransportBar('STEPPA'), findsOneWidget);
  });

  group('pro', () {
    testWidgets('the export sheet offers the parts export, marked Pro', (
      tester,
    ) async {
      await pumpStudio(tester);

      await tester.tap(inActionBar(l10n.actionExport));
      await tester.pumpAndSettle();

      expect(inExportSheet('LOOP'), findsOneWidget);
      expect(inExportSheet('SONG'), findsOneWidget);
      expect(inExportSheet('PARTS'), findsOneWidget);
      // A free user is told which one costs money before tapping it.
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('choosing parts without Pro puts the paywall up', (
      tester,
    ) async {
      await pumpStudio(tester);

      await tester.tap(inActionBar(l10n.actionExport));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PARTS'));
      await tester.pumpAndSettle();

      expect(find.byType(Paywall), findsOneWidget);
      expect(find.text('JUNGLENGINE PRO'), findsOneWidget);
      expect(find.text('GET PRO  £8.99'), findsOneWidget);
      // The free tier is on the paywall too, because most of the app is in it.
      expect(find.text('ALREADY FREE, AND STAYING FREE'), findsOneWidget);
      // And the mode did not change behind it.
      expect(find.text(l10n.exportTitleWav), findsOneWidget);
    });

    testWidgets('unlocking Pro closes the paywall and opens the mode', (
      tester,
    ) async {
      await pumpStudio(tester);

      await tester.tap(inActionBar(l10n.actionExport));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PARTS'));
      await tester.pumpAndSettle();

      // The debug unlock, which is what stands in for a purchase until the
      // product exists in the stores.
      await tester.tap(find.text('DEBUG: UNLOCK WITHOUT BUYING'));
      await tester.pumpAndSettle();

      expect(find.byType(Paywall), findsNothing);
      expect(find.text('EXPORT PARTS'), findsOneWidget);
      expect(find.text('BUILD AND SHARE'), findsOneWidget);
      expect(find.textContaining('Kong and NN-XT'), findsOneWidget);
    });

    testWidgets('the library sheet offers importing your own break', (
      tester,
    ) async {
      await pumpStudio(tester);

      await tester.tap(find.text(BreakLibrary.defaultBreak.name.toUpperCase()));
      await tester.pumpAndSettle();

      expect(find.text('IMPORT YOUR OWN'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('a kit slot offers importing a one shot', (tester) async {
      await pumpStudio(tester);
      await makeKitBeat(tester);

      await tester.longPress(find.text('KICK'));
      await tester.pumpAndSettle();

      expect(find.text('IMPORT ONE SHOT  (PRO)'), findsOneWidget);
      expect(find.text('USE KIT SAMPLE'), findsNothing);
    });
  });
}
