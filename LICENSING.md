# LICENSING.md

Every piece of audio that ships inside junglEngine gets a line here, with its
origin and its clearance status. Nothing goes to a store build while anything
below is still `UNCLEARED`.

Content is grouped into packs. A pack is a grouping and an entitlement, not a
different kind of file: everything in one is bundled inside the app and gets a
row below whether the pack is free or Pro. See `docs/PACKS.md`.

## Bundled breaks

### Starter pack (free)

| ID | File | Origin | Status |
| --- | --- | --- | --- |
| `dnb-full02-170` | `assets/breaks/DnB_full02_loop_170.wav` | **Not yet recorded.** Added to the assets folder on 2026-08-21; where it came from is unknown to the code. | **UNCLEARED** |
| `hawkstreak-amenish-170` | `assets/breaks/hawkstreak_amenish_170.wav` | Synthesised from scratch by `tool/make_break.dart`. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |
| `hawkstreak-steppa-170` | `assets/breaks/hawkstreak_steppa_170.wav` | Synthesised from scratch by `tool/make_break.dart`. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |
| `hawkstreak-roller-170` | `assets/breaks/hawkstreak_roller_170.wav` | Synthesised from scratch by `tool/make_break.dart`. Two bars. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |

### Nightshift pack (Pro)

| ID | File | Origin | Status |
| --- | --- | --- | --- |
| `hawkstreak-duppy-170` | `assets/breaks/hawkstreak_duppy_170.wav` | Synthesised from scratch by `tool/make_break.dart`. Two bars, displaced backbeat. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |
| `hawkstreak-lurch-170` | `assets/breaks/hawkstreak_lurch_170.wav` | Synthesised from scratch by `tool/make_break.dart`. One bar, broken beat. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |

Being Pro content changes nothing here. A pack somebody paid for is held to the
same clearance as one they did not, and arguably to a higher one: a free break
that turns out to be unclearable is embarrassing, a paid one is a refund.

### `dnb-full02-170` needs a provenance line

This is the default break, so it is what the app plays and what every M0 export
contains. Before any store build, replace the Origin cell above with one of:

- Original content: recorded or programmed by Hawkstreak, and by whom.
- Licensed sample pack: which pack, which vendor, and whether the licence
  permits redistribution **inside an application**. Most pack licences cover use
  in a musical work but not shipping the raw loop as an app asset. This is the
  usual place a bundled break fails clearance.
- Third party break: written permission on file.

If it turns out to be unclearable, nothing in the code needs to change: drop the
`BreakRef` from the Starter pack in `PackLibrary.all`, delete the WAV, and the
synthesised placeholder becomes the default again.

`hawkstreak-amenish-170` is a synthesised placeholder, kept as a fallback that
is guaranteed clear. It is not the default any more.

To add a break: drop the WAV into `assets/breaks/`, add a `BreakRef` to a pack
in `PackLibrary.all`, and add its row above under that pack's heading. A break
must be exactly the number of bars its `BreakRef` declares. `bars` is not
cosmetic: slice divisions are per bar, so a wrong bar count makes every slice
the wrong note value. `docs/PACKS.md` has the whole recipe.

## One shot kits

| ID | Files | Origin | Status |
| --- | --- | --- | --- |
| `hawkstreak-01` | `assets/kits/hawkstreak/hawkstreak_*.wav` (8 files) | Synthesised from scratch by `tool/make_kit.dart`. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |
| `hawkstreak-02` | `assets/kits/hawkstreak02/hawkstreak02_*.wav` (8 files) | Synthesised from scratch by `tool/make_kit.dart`. The dark kit. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |
| `hawkstreak-03` | `assets/kits/hawkstreak03/hawkstreak03_*.wav` (8 files) | Synthesised from scratch by `tool/make_kit.dart`. The metal kit, in the Nightshift pack. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |

`hawkstreak-01` and `hawkstreak-02` are in the free Starter pack;
`hawkstreak-03` is in the Pro Nightshift pack.

### The M1 kit is synthesised, not the Reason kit

MILESTONES.md calls for a Hawkstreak one shot kit made in Reason. What ships
today is synthesised in Dart instead, for the same reason the placeholder break
is: it is guaranteed clear and it exists now. It is a real kit, not a stub, and
the Kit machine is finished either way.

To swap in the Reason kit, drop eight WAVs into `assets/kits/hawkstreak/` under
the same file names and delete nothing else. `KitLibrary` is positional, so slot
order is file order: kick, snare, rim, clap, closed hat, open hat, shaker,
conga. Update the Origin cell above when you do.

To add a kit: put its WAVs in `assets/kits/<name>/`, add a `KitRef` with exactly
eight samples to a pack in `PackLibrary.all`, add the folder to `pubspec.yaml`
under `assets:`, and add a row here. `docs/PACKS.md` has the whole recipe.

## Audio the user imports

Pro lets people bring their own breaks and one shots in. None of it is listed
here, and none of it ever will be, because none of it is shipped.

An imported file is copied into the app's own storage on that one device, is
described in that one project's JSON, and is deleted when the project stops
pointing at it. It is not uploaded, not shared between users, not bundled into a
build, and not redistributed by Hawkstreak in any form. What a user imports is
their business and their licence.

Two consequences worth stating, because both have been got wrong by other apps:

- **Exports contain imported audio, and that is the user's to clear.** A WAV or
  a parts zip rendered from an imported break is a derivative of whatever they
  brought in. The app does not police that and cannot.
- **Slice packs are a different thing entirely.** Anything Hawkstreak ships as
  a pack is bundled content and gets a row in the tables above like everything
  else. The Nightshift pack is the first, and being Pro bought it no exemption.

## Checklist before any store submission

- [ ] Every row above reads CLEARED.
- [ ] Any third party break has written permission or a licence on file.
- [ ] Attribution text, where required, is reachable from inside the app.
- [ ] No imported or user supplied audio has been added to `assets/`.
