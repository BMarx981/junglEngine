# LICENSING.md

Every piece of audio that ships inside junglEngine gets a line here, with its
origin and its clearance status. Nothing goes to a store build while anything
below is still `UNCLEARED`.

## Bundled breaks

| ID | File | Origin | Status |
| --- | --- | --- | --- |
| `dnb-full02-170` | `assets/breaks/DnB_full02_loop_170.wav` | **Not yet recorded.** Added to the assets folder on 2026-08-21; where it came from is unknown to the code. | **UNCLEARED** |
| `hawkstreak-amenish-170` | `assets/breaks/hawkstreak_amenish_170.wav` | Synthesised from scratch by `tool/make_break.dart`. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |

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

None yet. The Hawkstreak kit lands in M1 and is original content made in Reason.

## Checklist before any store submission

- [ ] Every row above reads CLEARED.
- [ ] Any third party break has written permission or a licence on file.
- [ ] Attribution text, where required, is reachable from inside the app.
