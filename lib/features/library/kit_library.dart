import 'dart:io';

import 'package:flutter/services.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/soloud_engine.dart';
import 'package:junglengine/features/library/pack.dart';
import 'package:junglengine/models/kit_ref.dart';

/// The bundled one shot kits.
///
/// One kit per project, positional: slot *n* plays sample *n*. Eight slots is
/// the ceiling, so a kit here is exactly eight samples.
///
/// Flattened out of [PackLibrary.all] for the same reason [BreakLibrary] is:
/// content is registered in a pack, and everything below this line goes on
/// treating a kit as eight samples in order.
///
/// Anything added to a pack needs a line in LICENSING.md before a store build.
class KitLibrary {
  const KitLibrary._();

  static final List<KitRef> bundled = List<KitRef>.unmodifiable([
    for (final pack in PackLibrary.all) ...pack.kits,
  ]);

  /// What a new project's Kit Beats play. First kit of the first pack, so a
  /// free pack has to stay first in [PackLibrary.all].
  static KitRef get defaultKit => bundled.first;

  static KitRef byId(String id) {
    for (final k in bundled) {
      if (k.id == id) return k;
    }
    return defaultKit;
  }

  /// Decodes a kit into one clip per slot, in slot order.
  ///
  /// Deliberately not normalised: the kit's balance is baked into the files, so
  /// slot volume starts at the same place for every slot and still sounds like
  /// a kit. An imported one shot is the exception the rule survives, because it
  /// arrives peak normalised from the import screen and so lands in the same
  /// place a bundled sample would.
  ///
  /// A slot whose imported file has gone missing falls back to silence rather
  /// than failing the whole kit: seven slots and a hole is a recoverable
  /// project, an exception on boot is not.
  static Future<List<AudioClip>> load(KitRef ref, int sampleRate) async {
    final clips = <AudioClip>[];
    for (final sample in ref.samples) {
      final path = sample.filePath;
      if (path == null) {
        final data = await rootBundle.load(sample.assetPath);
        clips.add(loadOneShotClip(data.buffer.asUint8List(), sampleRate));
        continue;
      }
      try {
        clips.add(loadOneShotClip(await File(path).readAsBytes(), sampleRate));
      } on Object {
        clips.add(AudioClip.silent(frames: 1, sampleRate: sampleRate));
      }
    }
    return List<AudioClip>.unmodifiable(clips);
  }
}
