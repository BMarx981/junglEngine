// The M4 readout. It is behind a define and it goes when the gate is
// answered, but while it is here it is the thing the gate's first number is
// read off, so its arithmetic is worth holding still.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:junglengine/features/debug/latency_hud.dart';
import 'package:junglengine/state/studio.dart';

import '../support/fake_engine.dart';

void main() {
  late FakeAudioEngine engine;

  Future<void> pumpHud(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioEngineProvider.overrideWithValue(engine)],
        child: const MaterialApp(home: LatencyHud(child: SizedBox.expand())),
      ),
    );
  }

  setUp(() => engine = FakeAudioEngine());

  testWidgets('says nothing until something has been edited', (tester) async {
    await pumpHud(tester);
    expect(find.text('EDIT --'), findsOneWidget);
    expect(find.text('N 0'), findsOneWidget);
  });

  testWidgets('reports the median and the worst of what it was given', (
    tester,
  ) async {
    await pumpHud(tester);

    for (final micros in [2000, 10000, 4000]) {
      engine.noteEdit(engineMicros: micros);
      await tester.pump();
    }

    // Median of 2, 4 and 10, and the worst of them, which matters as much as
    // the median: on the flutter_soloud engine the worst case is the whole
    // queue, and on the Lira engine it should be one block. Two decimals under
    // ten milliseconds and one over, because the numbers being compared are
    // fractions of a millisecond at one end and hundreds at the other.
    expect(find.text('EDIT 4.00ms / 10.0ms'), findsOneWidget);
    expect(find.text('N 3'), findsOneWidget);
  });

  testWidgets('counts what the call itself cost as part of the wait', (
    tester,
  ) async {
    await pumpHud(tester);
    engine.noteEdit(engineMicros: 8000, callMicros: 500);
    await tester.pump();

    // 8.5 ms of wait, of which half a millisecond was Dart's.
    expect(find.text('EDIT 8.50ms / 8.50ms'), findsOneWidget);
    expect(find.text('CALL 0.50ms / 0.50ms'), findsOneWidget);
  });

  testWidgets('picks the rate up once the engine has opened a device', (
    tester,
  ) async {
    await pumpHud(tester);
    expect(find.text('SOLOUD 44100'), findsOneWidget);

    // What a device does to the Lira engine: it asked for one rate and was
    // given another, after this widget had already built. Starting playback is
    // the moment the answer is certainly known.
    engine.sampleRate = 48000;
    await engine.start();
    await tester.pump();

    expect(find.text('SOLOUD 48000'), findsOneWidget);
  });

  testWidgets('starts again when it is tapped', (tester) async {
    await pumpHud(tester);
    engine.noteEdit(engineMicros: 2000);
    await tester.pump();
    expect(find.text('N 1'), findsOneWidget);

    await tester.tap(find.text('N 1'));
    await tester.pump();
    expect(find.text('N 0'), findsOneWidget);
    expect(find.text('EDIT --'), findsOneWidget);
  });
}
