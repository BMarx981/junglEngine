import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/features/library/break_library.dart';
import 'package:junglengine/features/library/kit_library.dart';
import 'package:junglengine/features/library/pack.dart';
import 'package:junglengine/models/kit_pattern.dart';

/// The catalogue's invariants.
///
/// `BreakLibrary.bundled` and `KitLibrary.bundled` are flattened out of
/// `PackLibrary.all`, which is what lets every call site go on knowing nothing
/// about packs. These are the things that flattening quietly assumes.
void main() {
  group('PackLibrary', () {
    test('the breaks are the packs breaks, in order', () {
      expect(BreakLibrary.bundled, [
        for (final pack in PackLibrary.all) ...pack.breaks,
      ]);
    });

    test('the kits are the packs kits, in order', () {
      expect(KitLibrary.bundled, [
        for (final pack in PackLibrary.all) ...pack.kits,
      ]);
    });

    test('pack ids are unique', () {
      final ids = PackLibrary.all.map((p) => p.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('break ids are unique across every pack', () {
      final ids = BreakLibrary.bundled.map((b) => b.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('kit ids are unique across every pack', () {
      final ids = KitLibrary.bundled.map((k) => k.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    // A project stores a break id, and byId falls back to the default for one
    // it does not recognise. Two packs sharing an id would make which break a
    // project opened on depend on pack order, silently.
    test('every bundled break and kit resolves to itself', () {
      for (final ref in BreakLibrary.bundled) {
        expect(BreakLibrary.byId(ref.id).id, ref.id);
      }
      for (final ref in KitLibrary.bundled) {
        expect(KitLibrary.byId(ref.id).id, ref.id);
      }
    });

    test('every bundled break and kit belongs to exactly one pack', () {
      for (final ref in BreakLibrary.bundled) {
        expect(PackLibrary.packOfBreak(ref.id), isNotNull);
        expect(
          PackLibrary.all.where((p) => p.breaks.any((b) => b.id == ref.id)),
          hasLength(1),
        );
      }
      for (final ref in KitLibrary.bundled) {
        expect(PackLibrary.packOfKit(ref.id), isNotNull);
        expect(
          PackLibrary.all.where((p) => p.kits.any((k) => k.id == ref.id)),
          hasLength(1),
        );
      }
    });

    test('an id that is not bundled is in no pack', () {
      // What an imported break looks like from here.
      expect(PackLibrary.packOfBreak('imported-1234'), isNull);
      expect(PackLibrary.packOfKit('imported-1234'), isNull);
    });

    // The one that matters most. A new project opens on the first break of the
    // first pack; if that pack were ever Pro, the app would open behind its own
    // paywall.
    test('the default break and kit are free', () {
      final breakPack = PackLibrary.packOfBreak(BreakLibrary.defaultBreak.id);
      final kitPack = PackLibrary.packOfKit(KitLibrary.defaultKit.id);
      expect(breakPack!.isPro, isFalse);
      expect(kitPack!.isPro, isFalse);
    });

    test('the free packs come first, so the defaults stay free', () {
      final firstPro = PackLibrary.all.indexWhere((p) => p.isPro);
      if (firstPro < 0) return;
      for (var i = 0; i < firstPro; i++) {
        expect(PackLibrary.all[i].isPro, isFalse);
      }
    });

    test('a kit is exactly eight samples, in every pack', () {
      for (final kit in KitLibrary.bundled) {
        expect(kit.samples, hasLength(kitSlotCount), reason: kit.id);
      }
    });

    test('nothing bundled is marked imported', () {
      for (final ref in BreakLibrary.bundled) {
        expect(ref.isImported, isFalse, reason: ref.id);
      }
      for (final kit in KitLibrary.bundled) {
        for (final sample in kit.samples) {
          expect(sample.isImported, isFalse, reason: kit.id);
        }
      }
    });

    // rootBundle is not available in a plain unit test, so this checks the file
    // on disk instead. A missing WAV is a black screen on a device and a green
    // test suite without it.
    test('every asset a pack names is on disk', () {
      for (final ref in BreakLibrary.bundled) {
        expect(File(ref.assetPath).existsSync(), isTrue, reason: ref.assetPath);
      }
      for (final kit in KitLibrary.bundled) {
        for (final sample in kit.samples) {
          expect(
            File(sample.assetPath).existsSync(),
            isTrue,
            reason: sample.assetPath,
          );
        }
      }
    });

    // An asset that exists but is not declared ships in the repo and not in the
    // app, which looks identical until the phone asks for it.
    test('every asset a pack names is declared in pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declared = [
        for (final line in pubspec.split('\n'))
          if (line.trimLeft().startsWith('- assets/'))
            line.trim().substring(2),
      ];
      bool isDeclared(String path) =>
          declared.any((d) => d.endsWith('/') ? path.startsWith(d) : path == d);

      for (final ref in BreakLibrary.bundled) {
        expect(isDeclared(ref.assetPath), isTrue, reason: ref.assetPath);
      }
      for (final kit in KitLibrary.bundled) {
        for (final sample in kit.samples) {
          expect(isDeclared(sample.assetPath), isTrue, reason: sample.assetPath);
        }
      }
    });

    // LICENSING.md is the store gate, and a row nobody wrote is how a pack
    // ships uncleared.
    test('every pack has a licensing row per break and per kit', () {
      final licensing = File('LICENSING.md').readAsStringSync();
      for (final ref in BreakLibrary.bundled) {
        expect(licensing.contains('`${ref.id}`'), isTrue, reason: ref.id);
      }
      for (final kit in KitLibrary.bundled) {
        expect(licensing.contains('`${kit.id}`'), isTrue, reason: kit.id);
      }
    });
  });

  group('isLocked', () {
    final free = PackLibrary.all.firstWhere((p) => !p.isPro);
    final pro = PackLibrary.all.firstWhere((p) => p.isPro);

    test('a free pack is never locked', () {
      expect(isLocked(free, isPro: false), isFalse);
      expect(isLocked(free, isPro: true), isFalse);
    });

    test('a Pro pack is locked until it is bought', () {
      expect(isLocked(pro, isPro: false), isTrue);
      expect(isLocked(pro, isPro: true), isFalse);
    });
  });
}
