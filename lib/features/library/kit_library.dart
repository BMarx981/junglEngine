import 'dart:io';

import 'package:flutter/services.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/soloud_engine.dart';
import 'package:junglengine/models/kit_ref.dart';

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
    KitRef(
      id: 'hawkstreak-02',
      name: 'Hawkstreak 02',
      credit: 'Hawkstreak, synthesised original. See LICENSING.md.',
      samples: [
        KitSampleRef(
          label: 'KICK',
          assetPath: 'assets/kits/hawkstreak02/hawkstreak02_kick.wav',
        ),
        KitSampleRef(
          label: 'SNR',
          assetPath: 'assets/kits/hawkstreak02/hawkstreak02_snare.wav',
        ),
        KitSampleRef(
          label: 'WOOD',
          assetPath: 'assets/kits/hawkstreak02/hawkstreak02_rim.wav',
        ),
        KitSampleRef(
          label: 'CLAP',
          assetPath: 'assets/kits/hawkstreak02/hawkstreak02_clap.wav',
        ),
        KitSampleRef(
          label: 'CH',
          assetPath: 'assets/kits/hawkstreak02/hawkstreak02_hat_closed.wav',
        ),
        KitSampleRef(
          label: 'OH',
          assetPath: 'assets/kits/hawkstreak02/hawkstreak02_hat_open.wav',
        ),
        KitSampleRef(
          label: 'TAMB',
          assetPath: 'assets/kits/hawkstreak02/hawkstreak02_shaker.wav',
        ),
        KitSampleRef(
          label: 'TOM',
          assetPath: 'assets/kits/hawkstreak02/hawkstreak02_conga.wav',
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
