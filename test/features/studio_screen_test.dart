import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/features/bass/sub_lane_view.dart';
import 'package:junglengine/features/grid/chop_grid.dart';
import 'package:junglengine/features/studio_screen.dart';
import 'package:junglengine/features/transport/action_bar.dart';
import 'package:junglengine/features/transport/transport_bar.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

import '../support/fake_engine.dart';

/// Slice numbers also live down the side of the grid, so chip and button
/// finders have to say which bar they mean.
Finder inTransportBar(String text) => find.descendant(
  of: find.byType(TransportBar),
  matching: find.text(text),
);

Finder inActionBar(String text) =>
    find.descendant(of: find.byType(ActionBar), matching: find.text(text));

Future<FakeAudioEngine> pumpStudio(WidgetTester tester) async {
  final engine = FakeAudioEngine();
  tester.view.physicalSize = const Size(1170, 2532); // iPhone sized
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioEngineProvider.overrideWithValue(engine)],
      child: MaterialApp(
        theme: JungleTheme.build(),
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

void main() {
  testWidgets('boots into the studio with grid, sub lane and transport', (
    tester,
  ) async {
    await pumpStudio(tester);

    expect(find.byType(ChopGrid), findsOneWidget);
    expect(find.byType(SubLaneView), findsOneWidget);
    expect(inTransportBar('170'), findsOneWidget);
    expect(inTransportBar('16'), findsOneWidget);
    expect(inActionBar('SCRAMBLE'), findsOneWidget);
    expect(inActionBar('EXPORT'), findsOneWidget);
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

    await tester.tap(inActionBar('SCRAMBLE'));
    await tester.pump();
    expect(engine.lastSpec!.beat.chop.steps, isNot(equals(before)));

    await tester.tap(inActionBar('UNDO'));
    await tester.pump();
    expect(engine.lastSpec!.beat.chop.steps, equals(before));
  });

  testWidgets('tapping a grid cell paints that slice on that step', (
    tester,
  ) async {
    final engine = await pumpStudio(tester);

    final grid = tester.getRect(find.byType(ChopGrid));
    final cellsLeft = grid.left + ChopGrid.gutterWidth;
    final cellWidth = (grid.width - ChopGrid.gutterWidth) / 16;
    final rowHeight =
        (grid.height / 16).clamp(ChopGrid.minRowHeight, ChopGrid.maxRowHeight);

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

    await tester.tap(inTransportBar('32'));
    await tester.pump();
    expect(engine.lastSpec!.beat.sliceCount, 32);

    await tester.tap(inTransportBar('8'));
    await tester.pump();
    expect(engine.lastSpec!.beat.sliceCount, 8);
    // Slices 8..15 from the identity pattern no longer exist.
    expect(engine.lastSpec!.beat.chop.sliceAt(12), isNull);
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

  testWidgets('the sub panel exposes exactly five parameters', (tester) async {
    await pumpStudio(tester);

    await tester.tap(inActionBar('SUB'));
    await tester.pumpAndSettle();

    expect(find.text('SUB SYNTH'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(5));
    for (final name in ['TONE', 'CUTOFF', 'DRIVE', 'DECAY', 'GLIDE']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('the export sheet offers one to eight bars', (tester) async {
    await pumpStudio(tester);

    await tester.tap(inActionBar('EXPORT'));
    await tester.pumpAndSettle();

    expect(find.text('EXPORT WAV'), findsOneWidget);
    expect(find.text('RENDER AND SHARE'), findsOneWidget);
    expect(find.textContaining('2 bars at 170 BPM'), findsOneWidget);
  });
}
