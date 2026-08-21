# CLAUDE.md

App name: junglEngine (display casing: junglEngine, lowercase everywhere technical: junglengine). Package id pattern: app.hawkstreak.junglengine.

## What this is

A tracker style resequencer for breakbeats, plus a tiny monophonic sub synth. Two element jungle sketchpad: drums and bass. Phone first, Flutter.

This is NOT a performance pad instrument, NOT a sampler workstation, NOT a DAW. If a feature request smells like Koala, Dr. Octo Rex, or Serum, it is out of scope. The constraint is the product.

## Core loop

Load break > slice (equal divisions) > paint slices onto a step grid > loop plays > export.

The magic moment: drop a slice on a step, hit play, the break is rearranged and grooving. Everything serves that moment.

## Architecture

- Flutter app, Riverpod for state.
- Audio behind an abstract `AudioEngine` interface in `lib/audio/engine.dart`. M0 implementation wraps flutter_soloud. The interface must be clean enough to swap in the Lira Rust engine over FFI at M2 or M3 without touching UI or sequencer code.
- Sequencer clock lives in the audio layer, not the UI layer. UI subscribes to transport state. Never schedule audio from widget code.
- Pattern data is pure Dart models, serializable to JSON from day one. Patterns are data, not recorded performances. Export features depend on this.
- Data model hierarchy: Project > Beats > Song. A Beat has a machine type chosen at creation: Chop (break resequencer) or Kit (step drum machine, 8 one shot slots, 16 steps, three level velocity per trigger). Both types carry the sub lane. A Song is an ordered list of Beat references with repeat counts and is agnostic to machine type. Model machine type from M0 even though M0 only ships Chop, so M1 is additive, not a migration.
- One break per project. All Chop Beats resequence the same source break. Per Beat break selection is parked, do not build it.
- Kit machine spec (do not grow this): 8 slots, one shots only, per step velocity at three levels, per slot volume and pitch. No choke groups, no per slot effects, no more than 8 slots. Grid is 16 steps. Triplet resolutions are parked, swing covers the feel.
- Slicing is equal division only in M0 (8, 16, 32). Transient detection is a future feature with its own branch, do not start it early.

## Project structure

- `lib/models/` pattern, slice, project models
- `lib/audio/` engine interface, soloud implementation, sequencer clock, sub synth voice
- `lib/features/grid/` break step grid (Chop machine)
- `lib/features/kit/` step drum machine (Kit machine, M1)
- `lib/features/bass/` sub lane
- `lib/features/song/` beat bank and song view (M1)
- `lib/features/export/` wav render, later midi plus slices zip
- `lib/features/library/` break loading, bundled packs

## Sub synth spec (do not grow this)

Monophonic. Sine or triangle core, one lowpass, drive, amp envelope, glide. Five parameters max exposed to the user. Accent modifier opens the filter slightly. No wavetables, no mod matrix, no additional oscillators. Refuse politely and point here.

## Working rules

- Direct file edits only. Never write Python scripts to modify files.
- Brian is the only one who commits. Never run git commit, git merge, or git push. Creating branches and making file edits is fine, but stop at the commit boundary and hand off. This is a hard rule with no exceptions.
- Branch per unit of work. A unit is done when it is demoable and ready for Brian to review and commit.
- Every milestone has a go/no-go gate defined in MILESTONES.md. Do not start the next milestone before the gate is called.
- No placeholder screens for future features. Ship surface area only.
- Bundled breaks must be cleared for licensing before any store submission. Track this in a LICENSING.md when the first pack is added.
- Keep the app demoable in a 15 second vertical video at all times after M0. If a change breaks the demo, that change is not done.

## Monetization shape (for context, not for building yet)

Free: bundled breaks, grid, sub lane, wav export. Pro: import your own audio, midi plus slices zip export, slice packs. No ads ever.
