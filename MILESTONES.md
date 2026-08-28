# MILESTONES.md

Each milestone ends with a gate. The gate is a question answered honestly, not a feature checklist. If the gate fails, stop and reassess before writing more code.

## M0: The Toy (target: 2 weeks of sessions)

Goal: prove the core loop is fun.

- Load one bundled break (start with a licensed or self recorded Amen style loop).
- Equal division slicing: 8, 16, 32.
- Monophonic step grid, 16 steps, one bar. Tap to place a slice, tap to clear. Rows are slices, columns are steps.
- Sequencer clock with adjustable BPM, tight loop playback via flutter_soloud.
- Scramble button: generates a musically sensible rearrangement. Downbeats mostly anchored, ghost notes and snare placements shuffled. Seeded so undo works.
- Sub lane: monophonic step lane with pitch entry via vertical drag, tie two cells for glide. Synth voice per CLAUDE.md spec.
- Wav export of the looped pattern, 1 to 8 bars.
- Data model includes Beat machine type and Song hierarchy per CLAUDE.md even though only one Chop Beat exists in M0.
- No settings screen, no onboarding, no theming.

GATE: Hand the phone to yourself after a week away from the code. Do you make a groove you actually like within 3 minutes, and does the scramble button make you smile? Record the 15 second demo clip. If the clip is not obviously cool, no-go on M1, rethink the grid interaction instead.

## M1: Machines

Goal: two machines, many beats.

- Beat type selection at creation: Chop or Kit.
- Kit machine: 8 one shot slots, 16 step grid, three level velocity per trigger (soft, medium, hard), per slot volume and pitch. Spec ceiling in CLAUDE.md, do not exceed it.
- Bundled Hawkstreak one shot kit (kick, snare, hats, percussion, made in Reason, original content).
- Beat bank: a project holds multiple Beats at 1, 2, 4, or 8 bars. Duplicate Beat is a first class button, the core workflow is copy and tweak.
- Sub lane present in both machine types.
- Project save and load (JSON, local only).

GATE: Program a kit groove and a chop groove in the same project and A B them. Does the Kit machine remove the need for slice lane layering on the Chop machine? Decide layering's fate here, on evidence, not in advance.

## M2: Arrangement

Goal: from beats to songs.

- Song view: vertical list of Beat cards, each with a repeat count stepper. Drag to reorder, tap a card to open that Beat's grid. Playback in Song view runs the sequence seamlessly across machine types. This is a list, not a timeline.
- Wav export gains a Song mode: render the full arrangement, not just one loop.
- Per step modifiers on the Chop machine: reverse, retrigger, pitch down, half speed. Long press a cell to open the modifier picker.
- Accent modifier on the sub lane (opens filter).
- Swing knob, global per Beat. This is the answer to triplet feel before triplet grids exist.
- Second and third bundled breaks, second one shot kit.
- Slice lane layering enters here only if the M1 gate demanded it.

GATE: Build a full 32 to 64 bar arrangement in Song view using only the phone, intro, drop, variation, out, mixing Chop and Kit Beats. If it stalls because of a missing modifier rather than missing content, note it and decide deliberately whether it enters M3. Post the best clip to the Hawkstreak Instagram and watch the response.

## M3: The Money

Goal: Pro tier and store readiness.

- Import your own audio via native file picker (covers iCloud, Drive, Dropbox for free), with trim and manual BPM entry plus tap tempo. No BPM autodetection, no mic recording.
- Share sheet registration for wav and mp3 (Open in app from Files, browsers, messengers).
- One shot import into Kit slots via the same picker.
- MIDI plus sliced samples zip export, mapped so it drops into Kong or NN-XT cleanly. Verify in Reason 13 personally before calling it done.
- Pro tier via IAP, free tier limits per CLAUDE.md.
- App icon, store listing, privacy policy, LICENSING.md complete.
- Crash reporting and minimal anonymous analytics (beat created, export completed, scramble tapped, machine type usage).

GATE: Would you pay for Pro if someone else shipped this? If hesitation, find the one missing thing, add only that, then ship. Store submission is the exit of M3, not a separate milestone.

## M4: The Engine (optional, only if the app has users)

Goal: converge on Lira.

- Swap flutter_soloud implementation for the Lira Rust engine over FFI behind the existing AudioEngine interface.
- A and B test latency and battery before and after. If soloud is not the bottleneck, defer indefinitely and spend the time on content packs instead.

GATE: Measurable improvement users would notice. If the honest answer is "it is just cleaner architecture," do not merge, keep shipping features.

## M5: Content

Goal: give Pro a third leg to stand on.

The M4 gate names this by name: if the Rust engine is not a measurable win,
"defer indefinitely and spend the time on content packs instead". The paywall
has been selling slice packs since M3 and there were none, which is the one
promise in the app that was not kept.

- Content grouped into packs: a free Starter pack, and Pro packs unlocked by the
  one existing product. Bundled in the binary, no downloads, no new IAP.
- First Pro pack: two breaks and a kit, synthesised originals from `tool/`.
- The library sheet shows packs and locks the Pro ones behind the existing
  paywall. The gate is on picking, never on playing.
- `docs/PACKS.md` is the recipe for pack N+1, and LICENSING.md gets a row per
  file as always.

GATE: A B a groove built only out of the Pro pack against one built out of the
Starter pack, on a phone, a week apart from writing it. Is the pack the reason
the first one is better, or is it only different? If it is only different, it is
not worth money and the answer is a better pack rather than a third one. Then
ask the harder question: does one pack make Pro worth buying, or does the pitch
need three, and is that content work or a pack that is genuinely a different
sound?

## Explicitly parked (do not open branches for these)

- Transient detection slicing
- Triplet step resolutions (12 or 24 steps per bar). Swing ships first. Graduates only if the M2 gate says the feel is missing.
- Per Beat break selection (one break per project holds)
- Horizontal timeline arrangement UI (Song view stays a list)
- Mic recording and resampling
- BPM autodetection
- Kit choke groups and per slot effects
- Tilt and accelerometer gestures
- Polyphonic sub or any second synth. The Reese oscillator added after M5 sits inside the one monophonic voice, so it is a second oscillator and not a second synth. This line still means what it always meant: one voice, one instrument. See the sub synth spec in CLAUDE.md for the ceiling and the test a new parameter has to pass.
- Effects sends, reverb, delay
- Cloud sync and accounts
- Tablet and desktop layouts
