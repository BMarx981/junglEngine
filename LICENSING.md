# LICENSING.md

Every piece of audio that ships inside junglEngine gets a line here, with its
origin and its clearance status. Nothing goes to a store build while anything
below is still `UNCLEARED`.

## Bundled breaks

| ID | File | Origin | Status |
| --- | --- | --- | --- |
| `dnb-full02-170` | `assets/breaks/DnB_full02_loop_170.wav` | **Not yet recorded.** Added to the assets folder on 2026-08-21; where it came from is unknown to the code. | **UNCLEARED** |
| `hawkstreak-amenish-170` | `assets/breaks/hawkstreak_amenish_170.wav` | Synthesised from scratch by `tool/make_break.dart`. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |
| `hawkstreak-steppa-170` | `assets/breaks/hawkstreak_steppa_170.wav` | Synthesised from scratch by `tool/make_break.dart`. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |
| `hawkstreak-roller-170` | `assets/breaks/hawkstreak_roller_170.wav` | Synthesised from scratch by `tool/make_break.dart`. Two bars. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |

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
`BreakRef` from `BreakLibrary.bundled`, delete the WAV, and the synthesised
placeholder becomes the default again.

`hawkstreak-amenish-170` is a synthesised placeholder, kept as a fallback that
is guaranteed clear. It is not the default any more.

To add a break: drop the WAV into `assets/breaks/`, add a `BreakRef` to
`BreakLibrary.bundled`, and add its row above. A break must be exactly the
number of bars its `BreakRef` declares. `bars` is not cosmetic: slice divisions
are per bar, so a wrong bar count makes every slice the wrong note value.

## One shot kits

| ID | Files | Origin | Status |
| --- | --- | --- | --- |
| `hawkstreak-01` | `assets/kits/hawkstreak/hawkstreak_*.wav` (8 files) | Synthesised from scratch by `tool/make_kit.dart`. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |
| `hawkstreak-02` | `assets/kits/hawkstreak02/hawkstreak02_*.wav` (8 files) | Synthesised from scratch by `tool/make_kit.dart`. The dark kit. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |

### The M1 kit is synthesised, not the Reason kit

MILESTONES.md calls for a Hawkstreak one shot kit made in Reason. What ships
today is synthesised in Dart instead, for the same reason the placeholder break
is: it is guaranteed clear and it exists now. It is a real kit, not a stub, and
the Kit machine is finished either way.

To swap in the Reason kit, drop eight WAVs into `assets/kits/hawkstreak/` under
the same file names and delete nothing else. `KitLibrary` is positional, so slot
order is file order: kick, snare, rim, clap, closed hat, open hat, shaker,
conga. Update the Origin cell above when you do.

To add a second kit: put its WAVs in `assets/kits/<name>/`, add a `KitRef` to
`KitLibrary.bundled` with exactly eight samples, add the folder to `pubspec.yaml`
under `assets:`, and add a row here.

## Checklist before any store submission

- [ ] Every row above reads CLEARED.
- [ ] Any third party break has written permission or a licence on file.
- [ ] Attribution text, where required, is reachable from inside the app.
