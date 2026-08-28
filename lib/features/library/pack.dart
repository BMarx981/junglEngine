import 'package:junglengine/models/break_ref.dart';
import 'package:junglengine/models/kit_ref.dart';

/// A set of breaks and kits that ship together.
///
/// A pack is presentation and entitlement, never project data. A project stores
/// a `breakId` and a `kitId` and nothing else, so grouping content into packs
/// changed no JSON and needed no schema bump: break and kit ids stay globally
/// unique and an old project file opens exactly as it did.
///
/// Packs are bundled inside the app rather than downloaded. There is no server
/// in this app and there is not going to be one; a pack is asset bytes in the
/// binary and a flag saying who may pick it. See `docs/PACKS.md`.
///
/// Not in `lib/models/` for the reason above: `lib/models/` is what gets
/// serialised, and this is not.
class Pack {
  const Pack({
    required this.id,
    required this.name,
    required this.isPro,
    this.breaks = const [],
    this.kits = const [],
  });

  final String id;

  /// Shown as the group heading in the library sheet. A proper noun, so it
  /// stays English in every locale like the app's own name does, which is why
  /// it is here rather than in the ARB files.
  final String name;

  /// Whether picking something out of this pack asks for money.
  ///
  /// The gate is on picking, not on playing: see [isLocked].
  final bool isPro;

  final List<BreakRef> breaks;
  final List<KitRef> kits;
}

/// Everything that ships, in the order it is offered.
///
/// This is the catalogue. `BreakLibrary.bundled` and `KitLibrary.bundled` are
/// flattened out of it, so adding a pack here is the whole of adding content:
/// nothing downstream knows packs exist.
///
/// Anything added here needs a row in LICENSING.md before a store build.
class PackLibrary {
  const PackLibrary._();

  static const List<Pack> all = [
    /// What the app opens with, and what stays free. The paywall promises
    /// "everything in the Starter pack" by name, so this pack's contents are
    /// the free tier and moving anything out of it breaks that promise.
    ///
    /// Order is load-bearing: `BreakLibrary.defaultBreak` is the first break of
    /// the first pack, so a free pack has to come first.
    Pack(
      id: 'hawkstreak-starter',
      name: 'Starter',
      isPro: false,
      breaks: [
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
      ],
      kits: [
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
      ],
    ),

    /// The first Pro pack. Two breaks that are not shapes the starter pack
    /// already has -- a two bar break with the backbeat displaced, and a one
    /// bar that stumbles -- and a third kit to put under them.
    Pack(
      id: 'hawkstreak-nightshift',
      name: 'Nightshift',
      isPro: true,
      breaks: [
        BreakRef(
          id: 'hawkstreak-duppy-170',
          name: 'Duppy',
          assetPath: 'assets/breaks/hawkstreak_duppy_170.wav',
          bpm: 170,
          bars: 2,
          credit: 'Hawkstreak, synthesised original. See LICENSING.md.',
        ),
        BreakRef(
          id: 'hawkstreak-lurch-170',
          name: 'Lurch',
          assetPath: 'assets/breaks/hawkstreak_lurch_170.wav',
          bpm: 170,
          bars: 1,
          credit: 'Hawkstreak, synthesised original. See LICENSING.md.',
        ),
      ],
      kits: [
        KitRef(
          id: 'hawkstreak-03',
          name: 'Hawkstreak 03',
          credit: 'Hawkstreak, synthesised original. See LICENSING.md.',
          samples: [
            KitSampleRef(
              label: 'KICK',
              assetPath: 'assets/kits/hawkstreak03/hawkstreak03_kick.wav',
            ),
            KitSampleRef(
              label: 'SNR',
              assetPath: 'assets/kits/hawkstreak03/hawkstreak03_snare.wav',
            ),
            KitSampleRef(
              label: 'RIM',
              assetPath: 'assets/kits/hawkstreak03/hawkstreak03_rim.wav',
            ),
            KitSampleRef(
              label: 'CLAP',
              assetPath: 'assets/kits/hawkstreak03/hawkstreak03_clap.wav',
            ),
            KitSampleRef(
              label: 'CH',
              assetPath: 'assets/kits/hawkstreak03/hawkstreak03_hat_closed.wav',
            ),
            KitSampleRef(
              label: 'OH',
              assetPath: 'assets/kits/hawkstreak03/hawkstreak03_hat_open.wav',
            ),
            KitSampleRef(
              label: 'SHKR',
              assetPath: 'assets/kits/hawkstreak03/hawkstreak03_shaker.wav',
            ),
            KitSampleRef(
              label: 'TOM',
              assetPath: 'assets/kits/hawkstreak03/hawkstreak03_conga.wav',
            ),
          ],
        ),
      ],
    ),
  ];

  /// The pack a break belongs to, or null for an id that is not bundled --
  /// which in practice means an imported break, and imports are not in packs.
  static Pack? packOfBreak(String breakId) {
    for (final pack in all) {
      for (final ref in pack.breaks) {
        if (ref.id == breakId) return pack;
      }
    }
    return null;
  }

  static Pack? packOfKit(String kitId) {
    for (final pack in all) {
      for (final ref in pack.kits) {
        if (ref.id == kitId) return pack;
      }
    }
    return null;
  }
}

/// Whether a pack's contents may be picked right now.
///
/// The gate is on picking, not on playing. A project that already points at a
/// pack break keeps playing it whatever the store currently says, for two
/// reasons: `ProPhase.checking` is the state every cold start begins in, so
/// gating at load time would reset a paid-for project every time the app opened
/// before the store answered; and dropping back to the default break reslices
/// every Chop Beat, which destroys patterns. Nothing here can cost someone
/// their work.
bool isLocked(Pack pack, {required bool isPro}) => pack.isPro && !isPro;
