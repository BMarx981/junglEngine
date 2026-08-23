import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/features/import/audio_import.dart';
import 'package:junglengine/features/library/break_library.dart';
import 'package:junglengine/features/library/import_store.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/project.dart';
import 'package:junglengine/state/project_store.dart';
import 'package:junglengine/state/studio.dart';

import '../support/fake_engine.dart';

/// Four bars of a tone at 44.1 kHz, which is enough to be a plausible break and
/// short enough to write in a test.
ImportCandidate candidate({
  String name = 'Amen Break.wav',
  int frames = 44100 * 2,
}) {
  final samples = Float32List(frames * 2);
  for (var f = 0; f < frames; f++) {
    final v = ((f ~/ 200) % 2 == 0) ? 0.6 : -0.6;
    samples[f * 2] = v;
    samples[f * 2 + 1] = v;
  }
  return ImportCandidate(
    name: name,
    clip: AudioClip(samples: samples, channels: 2, sampleRate: 44100),
    truncated: false,
  );
}

Future<ProviderContainer> booted(FakeAudioEngine engine) async {
  final container = ProviderContainer.test(
    overrides: [audioEngineProvider.overrideWithValue(engine)],
  );
  container.listen(studioProvider, (_, _) {});
  for (var i = 0; i < 200; i++) {
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
    tempDir = await Directory.systemTemp.createTemp('junglengine-import');
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

  Directory imports() => Directory('${tempDir.path}/imports');

  group('importing a break', () {
    test('the imported break becomes the project break', () async {
      await controller().useImportedBreak(
        candidate(),
        const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 1),
        170,
      );

      final imported = state().project.importedBreak;
      expect(imported, isNotNull);
      expect(imported!.name, 'Amen Break');
      expect(imported.bars, 1);
      expect(state().project.breakId, imported.id);
      expect(state().project.breakIsImported, isTrue);
      expect(state().breakRef.isImported, isTrue);
      expect(state().clip, isNotNull);
    });

    test('the project moves to the tempo the user entered', () async {
      await controller().useImportedBreak(
        candidate(),
        const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 1),
        163,
      );
      expect(state().project.bpm, 163);
    });

    test(
      'the trimmed loop is what lands on disk, not the whole file',
      () async {
        await controller().useImportedBreak(
          candidate(frames: 44100 * 4),
          const TrimSelection(
            startFrame: 44100,
            lengthFrames: 44100 * 2,
            bars: 2,
          ),
          160,
        );

        final files = imports().listSync().whereType<File>().toList();
        expect(files, hasLength(1));
        // Two seconds of 16 bit stereo, plus the 44 byte header.
        expect(files.first.lengthSync(), 44 + 44100 * 2 * 2 * 2);
      },
    );

    test(
      'a longer break re-slices every Chop Beat at the same division per bar',
      () async {
        // Boot is on a four bar break at 16 divisions per bar: 64 slices.
        expect(state().beat.sliceCount, 16 * state().breakRef.bars);

        await controller().useImportedBreak(
          candidate(),
          const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 2),
          170,
        );

        expect(state().breakRef.bars, 2);
        expect(state().beat.sliceCount, 32);
        expect(state().sliceDivision, 16);
      },
    );

    test(
      'Kit Beats are left alone, because they do not slice the break',
      () async {
        controller().addBeat(MachineType.kit, 1);
        final before = state().beat.sliceCount;
        await controller().useImportedBreak(
          candidate(),
          const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 1),
          170,
        );
        expect(state().beat.sliceCount, before);
      },
    );

    test(
      'importing a second break replaces the first, files and all',
      () async {
        await controller().useImportedBreak(
          candidate(name: 'first.wav'),
          const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 1),
          170,
        );
        final first = state().project.importedBreak!.fileName;

        await controller().useImportedBreak(
          candidate(name: 'second.wav'),
          const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 1),
          150,
        );

        expect(state().project.importedBreak!.name, 'second');
        // One break per project, so the first one is unreachable and is swept.
        expect(File('${imports().path}/$first').existsSync(), isFalse);
        expect(imports().listSync().whereType<File>(), hasLength(1));
      },
    );

    test(
      'switching back to a bundled break keeps the import available',
      () async {
        await controller().useImportedBreak(
          candidate(),
          const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 1),
          170,
        );
        final importedId = state().project.importedBreak!.id;

        await controller().setBreak(BreakLibrary.bundled[1].id);
        expect(state().breakRef.isImported, isFalse);
        expect(state().project.importedBreak, isNotNull);

        await controller().setBreak(importedId);
        expect(state().breakRef.isImported, isTrue);
      },
    );
  });

  group('importing a one shot', () {
    test('the slot plays the imported sample and says so', () async {
      final before = state().kitRef.labelAt(2);
      await controller().importSlotSample(2, candidate(name: 'my 808.wav'));

      expect(state().project.importedSlot(2), isNotNull);
      expect(state().kitRef.labelAt(2), 'MY80');
      expect(state().kitRef.labelAt(2), isNot(before));
      expect(state().kitRef.importedAt(2), isTrue);
      expect(state().kitRef.importedAt(3), isFalse);
      expect(state().kitClips, hasLength(8));
    });

    test('the other seven slots are untouched', () async {
      final labels = [for (var i = 0; i < 8; i++) state().kitRef.labelAt(i)];
      await controller().importSlotSample(0, candidate(name: 'kick.wav'));
      for (var i = 1; i < 8; i++) {
        expect(state().kitRef.labelAt(i), labels[i]);
      }
    });

    test(
      'slot volume and pitch belong to the Beat and survive the import',
      () async {
        controller().addBeat(MachineType.kit, 1);
        controller().setSlotVolume(4, 0.35);
        controller().setSlotPitch(4, -5);

        await controller().importSlotSample(4, candidate(name: 'rim.wav'));

        expect(state().beat.slot(4).volume, closeTo(0.35, 1e-9));
        expect(state().beat.slot(4).pitch, -5);
      },
    );

    test('going back to the kit sample drops the file', () async {
      await controller().importSlotSample(1, candidate(name: 'snare.wav'));
      expect(imports().listSync().whereType<File>(), hasLength(1));

      await controller().clearImportedSlot(1);
      expect(state().project.importedSlot(1), isNull);
      expect(state().kitRef.importedAt(1), isFalse);
      expect(imports().listSync().whereType<File>(), isEmpty);
    });

    test('an imported one shot survives a kit change', () async {
      await controller().importSlotSample(5, candidate(name: 'shaker.wav'));
      await controller().setKit('hawkstreak-02');
      expect(state().kitRef.importedAt(5), isTrue);
      expect(state().kitRef.labelAt(5), 'SHAK');
    });

    test('a slot outside the kit is refused rather than clamped', () async {
      await controller().importSlotSample(99, candidate());
      expect(state().project.importedSlots, isEmpty);
    });
  });

  group('across a restart', () {
    test('the imported break comes back', () async {
      await controller().useImportedBreak(
        candidate(name: 'keeper.wav'),
        const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 2),
        168,
      );
      await controller().importSlotSample(3, candidate(name: 'clap.wav'));
      await controller().flushSave();
      container.dispose();

      container = await booted(FakeAudioEngine());

      expect(state().breakRef.isImported, isTrue);
      expect(state().breakRef.name, 'keeper');
      expect(state().breakRef.bars, 2);
      expect(state().project.bpm, 168);
      expect(state().kitRef.importedAt(3), isTrue);
      expect(state().kitRef.labelAt(3), 'CLAP');
    });

    test('a project whose audio has gone opens on a bundled break', () async {
      await controller().useImportedBreak(
        candidate(name: 'gone.wav'),
        const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 1),
        170,
      );
      await controller().flushSave();
      container.dispose();

      // The file goes, the project JSON stays. A restore, or the OS clearing
      // out storage, leaves exactly this.
      for (final file in imports().listSync().whereType<File>()) {
        file.deleteSync();
      }

      container = await booted(FakeAudioEngine());

      expect(state().status, StudioStatus.ready);
      expect(state().breakRef.isImported, isFalse);
      expect(state().breakRef.id, BreakLibrary.defaultBreak.id);
      expect(state().project.importedBreak, isNull);
    });

    test('imports the project no longer points at are swept on boot', () async {
      final store = const ImportStore();
      await store.write('orphan', Uint8List(64), stamp: 1);
      expect(imports().listSync().whereType<File>(), hasLength(1));

      container.dispose();
      container = await booted(FakeAudioEngine());
      // The sweep is fired and forgotten on boot, so give it a turn.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(imports().listSync().whereType<File>(), isEmpty);
    });
  });

  group('the JSON', () {
    test('round trips the imports', () async {
      await controller().useImportedBreak(
        candidate(name: 'round trip.wav'),
        const TrimSelection(startFrame: 0, lengthFrames: 44100, bars: 4),
        174,
      );
      await controller().importSlotSample(6, candidate(name: 'conga.wav'));

      final json = state().project.toJson();
      final back = Project.fromJson(json);

      expect(back.importedBreak!.name, 'round trip');
      expect(back.importedBreak!.bars, 4);
      expect(back.importedBreak!.bpm, 174);
      expect(back.importedSlots, hasLength(1));
      expect(back.importedSlots.single.slot, 6);
      expect(back.importedFileNames, hasLength(2));
    });

    test('a project written before M3 still opens', () async {
      // Version 2, which had no imports at all.
      const legacy = {
        'version': 2,
        'id': 'project-1',
        'name': 'junglEngine',
        'breakId': 'hawkstreak-steppa-170',
        'kitId': 'hawkstreak-01',
        'bpm': 170.0,
        'beats': <Object?>[],
        'song': <String, Object?>{},
      };
      await const ProjectStore().save(Project.fromJson(legacy));

      container.dispose();
      container = await booted(FakeAudioEngine());

      expect(state().project.importedBreak, isNull);
      expect(state().project.importedSlots, isEmpty);
      expect(state().breakRef.id, 'hawkstreak-steppa-170');
    });
  });
}
