# LICENSING.md

Every piece of audio that ships inside junglEngine gets a line here, with its
origin and its clearance status. Nothing goes to a store build while anything
below is still `UNCLEARED`.

## Bundled breaks

| ID | File | Origin | Status |
| --- | --- | --- | --- |
| `hawkstreak-amenish-170` | `assets/breaks/hawkstreak_amenish_170.wav` | Synthesised from scratch by `tool/make_break.dart`. No sampled material of any kind. | CLEARED (original content, Hawkstreak) |

`hawkstreak-amenish-170` is a placeholder with a job: it makes the core loop
demoable without waiting on clearance. It is a synthesised amen shaped bar at
170 BPM, not a real break, and it is not what M0's gate should be judged on.

To swap in a real break: drop the WAV into `assets/breaks/`, add a `BreakRef`
to `BreakLibrary.bundled`, and add its row above. A break must be exactly the
number of bars its `BreakRef` declares, or the identity pattern will not
reconstruct it.

## One shot kits

None yet. The Hawkstreak kit lands in M1 and is original content made in Reason.

## Checklist before any store submission

- [ ] Every row above reads CLEARED.
- [ ] Any third party break has written permission or a licence on file.
- [ ] Attribution text, where required, is reachable from inside the app.
