import 'package:flutter/services.dart';

import '../../audio/audio_clip.dart';
import '../../audio/soloud_engine.dart';
import '../../models/break_ref.dart';

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
      id: 'hawkstreak-amenish-170',
      name: 'Amenish',
      assetPath: 'assets/breaks/hawkstreak_amenish_170.wav',
      bpm: 170,
      bars: 1,
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
  static Future<AudioClip> load(BreakRef ref, int sampleRate) async {
    final data = await rootBundle.load(ref.assetPath);
    return loadBreakClip(data.buffer.asUint8List(), sampleRate);
  }
}
