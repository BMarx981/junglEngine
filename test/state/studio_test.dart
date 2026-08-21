import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/models/sub_lane.dart';
import 'package:junglengine/state/studio.dart';

import '../support/fake_engine.dart';

/// Waits for the break to finish loading off the asset bundle.
Future<ProviderContainer> booted(FakeAudioEngine engine) async {
  final container = ProviderContainer.test(
    overrides: [audioEngineProvider.overrideWithValue(engine)],
  );
  container.listen(studioProvider, (_, _) {});
  for (var i = 0; i < 100; i++) {
    if (container.read(studioProvider).isReady) return container;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('studio never became ready: ${container.read(studioProvider).status}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioEngine engine;
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    // Export writes through path_provider, which has no plugin in a test host.
    tempDir = await Directory.systemTemp.createTemp('junglengine-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
    engine = FakeAudioEngine();
    container = await booted(engine);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  StudioController controller() => container.read(studioProvider.notifier);
  StudioState state() => container.read(studioProvider);

  group('boot', () {
    test('opens on the bundled break at the break tempo', () {
      expect(state().breakRef.id, 'hawkstreak-amenish-170');
      expect(state().project.bpm, 170);
      expect(state().clip, isNotNull);
      expect(state().analysis, isNotNull);
    });

    test('starts on the identity pattern, so play is the break itself', () {
      for (var step = 0; step < 16; step++) {
        expect(state().beat.chop.sliceAt(step), step);
      }
    });

    test('has one chop beat and an empty song, per the M0 hierarchy', () {
      expect(state().project.beats, hasLength(1));
      expect(state().project.song.isEmpty, isTrue);
    });

    test('hands the engine a spec on boot', () {
      expect(engine.lastSpec, isNotNull);
      expect(engine.lastSpec!.bpm, 170);
    });
  });

  group('grid editing', () {
    test('placing a slice reaches the engine and auditions', () {
      controller().toggleCell(3, 7);
      expect(state().beat.chop.sliceAt(7), 3);
      expect(engine.lastSpec!.beat.chop.sliceAt(7), 3);
      expect(engine.auditioned, contains(3));
    });

    test('tapping the same cell again clears it and does not audition', () {
      controller().toggleCell(3, 7);
      engine.auditioned.clear();
      controller().toggleCell(3, 7);
      expect(state().beat.chop.sliceAt(7), isNull);
      expect(engine.auditioned, isEmpty);
    });

    test('painting the same cell twice only commits once', () {
      controller().paintCell(2, 5);
      engine.auditioned.clear();
      controller().paintCell(2, 5);
      expect(engine.auditioned, isEmpty);
    });

    test('re-slicing drops slices that no longer exist', () {
      controller().setSliceCount(32);
      controller().toggleCell(30, 2);
      controller().setSliceCount(8);
      expect(state().beat.sliceCount, 8);
      expect(state().beat.chop.sliceAt(2), isNull);
      expect(state().analysis!.sliceCount, 8);
    });
  });

  group('scramble and undo', () {
    test('scramble changes the bar and can be undone', () {
      final before = List.of(state().beat.chop.steps);
      controller().scramble();
      expect(state().beat.chop.steps, isNot(equals(before)));
      expect(state().canUndo, isTrue);

      controller().undo();
      expect(state().beat.chop.steps, equals(before));
      expect(state().canUndo, isFalse);
    });

    test('undo walks back through several scrambles', () {
      final start = List.of(state().beat.chop.steps);
      controller().scramble();
      controller().scramble();
      controller().scramble();
      controller().undo();
      controller().undo();
      controller().undo();
      expect(state().beat.chop.steps, equals(start));
    });

    test('ordinary edits are not undo steps', () {
      controller().toggleCell(1, 1);
      expect(state().canUndo, isFalse);
    });

    test('clearing the grid is undoable', () {
      controller().clearPattern();
      expect(state().beat.chop.isEmpty, isTrue);
      controller().undo();
      expect(state().beat.chop.isEmpty, isFalse);
    });

    test('undo on an empty stack does nothing', () {
      final before = List.of(state().beat.chop.steps);
      controller().undo();
      expect(state().beat.chop.steps, equals(before));
    });
  });

  group('sub lane', () {
    test('setting and clearing a pitch', () {
      controller().setSubStep(4, -5);
      expect(state().beat.sub.stepAt(4).semitone, -5);
      controller().setSubStep(4, null);
      expect(state().beat.sub.stepAt(4), isA<SubStep>().having((s) => s.isRest, 'isRest', true));
    });

    test('a tie survives a pitch change on the same cell', () {
      controller().toggleTie(6);
      controller().setSubStep(6, 3);
      expect(state().beat.sub.stepAt(6).tie, isTrue);
      expect(state().beat.sub.stepAt(6).semitone, 3);
    });

    test('synth parameters reach the engine', () {
      controller().setSubParameter(1, 0.9);
      expect(engine.lastSpec!.beat.subPatch.cutoff, closeTo(0.9, 1e-9));
    });
  });

  group('transport', () {
    test('play and stop go through the engine', () async {
      await controller().togglePlay();
      expect(engine.startCount, 1);
      await controller().togglePlay();
      expect(engine.stopCount, 1);
    });

    test('bpm is clamped and pushed to the engine', () {
      controller().setBpm(174);
      expect(engine.lastSpec!.bpm, 174);
      controller().setBpm(9000);
      expect(state().project.bpm, StudioController.maxBpm);
      controller().setBpm(1);
      expect(state().project.bpm, StudioController.minBpm);
    });
  });

  group('export', () {
    test('writes a wav named after the tempo and length', () async {
      controller().setBpm(174);
      controller().setExportRepeats(4);
      final result = await controller().exportWav();

      expect(result, isNotNull);
      expect(result!.fileName, 'junglengine-a-174bpm-4bar.wav');
      expect(result.bars, 4);
      expect(await result.file.length(), greaterThan(44));
      expect(
        result.duration.inMilliseconds,
        closeTo(4 * 4 * 60 / 174 * 1000, 20),
      );
      await result.file.delete();
    });
  });
}
