import 'package:flutter/services.dart';

import '../../audio/audio_clip.dart';
import '../../audio/soloud_engine.dart';
import '../../models/kit_ref.dart';

/// The bundled one shot kits.
///
/// One kit per project, positional: slot *n* plays sample *n*. Eight slots is
/// the ceiling, so a kit here is exactly eight samples.
///
/// Anything added here needs a line in LICENSING.md before a store build.
class KitLibrary {
  const KitLibrary._();

  static const List<KitRef> bundled = [
    KitRef(
      id: 'hawkstreak-01',
      name: 'Hawkstreak 01',
      credit: 'Hawkstreak, synthesised original. See LICENSING.md.',
      samples: [
        KitSampleRef(
          label: 'KICK',
          assetPath: 'assets/kits/hawkstreak/hawkstreak_kick.wav',
        ),
        KitSampleRef(
          label: 'SNR',
          assetPath: 'assets/kits/hawkstreak/hawkstreak_snare.wav',
        ),
        KitSampleRef(
          label: 'RIM',
          assetPath: 'assets/kits/hawkstreak/hawkstreak_rim.wav',
        ),
        KitSampleRef(
          label: 'CLAP',
          assetPath: 'assets/kits/hawkstreak/hawkstreak_clap.wav',
        ),
        KitSampleRef(
          label: 'CH',
          assetPath: 'assets/kits/hawkstreak/hawkstreak_hat_closed.wav',
        ),
        KitSampleRef(
          label: 'OH',
          assetPath: 'assets/kits/hawkstreak/hawkstreak_hat_open.wav',
        ),
        KitSampleRef(
          label: 'SHKR',
          assetPath: 'assets/kits/hawkstreak/hawkstreak_shaker.wav',
        ),
        KitSampleRef(
          label: 'CNGA',
          assetPath: 'assets/kits/hawkstreak/hawkstreak_conga.wav',
        ),
      ],
    ),
  ];

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
  /// a kit.
  static Future<List<AudioClip>> load(KitRef ref, int sampleRate) async {
    final clips = <AudioClip>[];
    for (final sample in ref.samples) {
      final data = await rootBundle.load(sample.assetPath);
      clips.add(loadOneShotClip(data.buffer.asUint8List(), sampleRate));
    }
    return List<AudioClip>.unmodifiable(clips);
  }
}
