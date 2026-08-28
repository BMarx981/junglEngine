import 'dart:io';

import 'package:flutter/services.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/soloud_engine.dart';
import 'package:junglengine/features/library/pack.dart';
import 'package:junglengine/models/break_ref.dart';

/// The bundled breaks.
///
/// One break per project: whichever entry a project points at, every Chop Beat
/// in it resequences that one source. Per Beat break selection is parked.
///
/// Flattened out of [PackLibrary.all] rather than written here, so that a pack
/// is the only place content is registered and nothing downstream of this class
/// has to know packs exist. Which pack a break came from, and whether that pack
/// is Pro, is the library sheet's business and no one else's.
///
/// Anything added to a pack needs a line in LICENSING.md before a store build.
class BreakLibrary {
  const BreakLibrary._();

  static final List<BreakRef> bundled = List<BreakRef>.unmodifiable([
    for (final pack in PackLibrary.all) ...pack.breaks,
  ]);

  /// What a new project opens on. The first break of the first pack, which is
  /// why a free pack has to stay first in [PackLibrary.all]: the app's default
  /// content can never be behind the paywall.
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
