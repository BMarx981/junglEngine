import 'dart:io';

import 'package:flutter/services.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/soloud_engine.dart';
import 'package:junglengine/models/break_ref.dart';

/// The bundled breaks.
///
/// One break per project: whichever entry a project points at, every Chop Beat
/// in it resequences that one source. Per Beat break selection is parked.
///
/// Anything added here needs a line in LICENSING.md before a store build.
class BreakLibrary {
  const BreakLibrary._();

  static const List<BreakRef> bundled = [
    BreakRef(
      id: 'dnb-full02-170',
      name: 'DnB Full 02',
      assetPath: 'assets/breaks/DnB_full02_loop_170.wav',
      bpm: 170,
      bars: 4,
      credit: 'Provenance not yet recorded. See LICENSING.md.',
    ),
    BreakRef(
      id: 'hawkstreak-amenish-170',
      name: 'Amenish',
      assetPath: 'assets/breaks/hawkstreak_amenish_170.wav',
      bpm: 170,
      bars: 1,
      credit: 'Hawkstreak, synthesised original. See LICENSING.md.',
    ),
    BreakRef(
      id: 'hawkstreak-steppa-170',
      name: 'Steppa',
      assetPath: 'assets/breaks/hawkstreak_steppa_170.wav',
      bpm: 170,
      bars: 1,
      credit: 'Hawkstreak, synthesised original. See LICENSING.md.',
    ),
    BreakRef(
      id: 'hawkstreak-roller-170',
      name: 'Roller',
      assetPath: 'assets/breaks/hawkstreak_roller_170.wav',
      bpm: 170,
      bars: 2,
      credit: 'Hawkstreak, synthesised original. See LICENSING.md.',
    ),
  ];

  static BreakRef get defaultBreak => bundled.first;

  static BreakRef byId(String id) {
    for (final b in bundled) {
      if (b.id == id) return b;
    }
    return defaultBreak;
  }

  /// Decodes a break and conforms it to the mixer's expectations: stereo, at
  /// the engine sample rate, peak normalised.
  ///
  /// An imported break comes off disk instead of the bundle and is otherwise
  /// treated identically, normalisation included: whatever the user brought in
  /// should sit at the same level as what ships, or switching between them is
  /// a volume change rather than a break change.
  static Future<AudioClip> load(BreakRef ref, int sampleRate) async {
    final path = ref.filePath;
    if (path != null) {
      return loadBreakClip(await File(path).readAsBytes(), sampleRate);
    }
    final data = await rootBundle.load(ref.assetPath);
    return loadBreakClip(data.buffer.asUint8List(), sampleRate);
  }
}
