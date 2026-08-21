# junglEngine

A tracker style resequencer for breakbeats, plus a tiny monophonic sub synth.
Two element jungle sketchpad: drums and bass. Phone first, Flutter.

Load break > slice > paint slices onto a step grid > loop plays > export.

This is not a performance pad instrument, not a sampler workstation, not a DAW.
The constraint is the product. See [CLAUDE.md](CLAUDE.md) for what is in scope
and [MILESTONES.md](MILESTONES.md) for what ships when.

## Running it

```sh
flutter pub get
flutter run                 # phone
flutter run -d macos        # quickest way to hear a change
```

## Tests

```sh
flutter test                       # models, mixer, scramble, state, widgets
flutter test integration_test -d macos   # the real audio device
```

The unit tests prove the mixer produces the right samples. The integration
tests prove those samples reach an output device, by checking that the device
consumed them. Both matter; neither substitutes for the other.

Integration tests cannot run on a wirelessly tethered iOS device. Plug the
phone in, or use macOS.

## How the audio works

The app renders its own audio. `PatternRenderer` turns a `Beat` into interleaved
stereo float samples; playback pushes those blocks into a flutter_soloud buffer
stream and export writes the same blocks to a file. SoLoud is an output device
here, not a sequencer.

That is the point: there is one code path, so what you hear is what you export,
and step timing is sample accurate instead of being at the mercy of Dart timer
jitter. It also keeps `AudioEngine` narrow enough that the Lira Rust engine can
replace it at M2 or M3 without the grid, the sequencer or the exporter noticing.

- `lib/audio/engine.dart` — the interface everything else talks to
- `lib/audio/pattern_renderer.dart` — the mixer, the only thing that makes sound
- `lib/audio/soloud_engine.dart` — flutter_soloud implementation
- `lib/audio/sub_voice.dart` — the sub synth, all five parameters of it

## Machines and Beats

A project holds a bank of Beats. Each Beat picks its machine and its length when
it is created, and neither changes afterwards, because both decide the shape of
the pattern data underneath it.

- **Chop** resequences the project break: rows are slices, columns are steps,
  monophonic.
- **Kit** plays the project kit: eight one shot slots, three velocity levels per
  step, volume and pitch per slot, polyphonic across slots and no choke groups.

Both carry the sub lane, both render through the same `PatternRenderer`, and the
Song treats them identically. Duplicate is the workflow the bank is built for:
make one, copy it, change two things.

A Beat is 1, 2, 4 or 8 bars. The grid always shows one bar of sixteen steps and
the bar strip pages between them, following the playhead while the transport
runs. Squeezing 128 steps across a phone would make cells nobody can hit.

The open project is saved to the app documents directory as JSON, shortly after
every edit and immediately when the app is backgrounded, and it reopens on
launch. Local only: no cloud, no accounts, no project browser.

## Kits

`KitLibrary.bundled` lists what ships, and a kit is exactly eight samples.
Slots are positional: slot *n* plays sample *n*, and a Beat's per slot volume
and pitch hang off that position. One kit per project, like the break.

The bundled kit is synthesised, not sampled, so it is guaranteed clear:

```sh
dart run tool/make_kit.dart
```

## Breaks

`BreakLibrary.bundled` lists what ships. The first entry is what a project
opens with; there is no break picker, one break per project.

Slice divisions are **per bar**: picking 16 means sixteenth notes whether the
break is one bar or four. So a four bar break at 16 divisions is 64 rows on the
grid, and the grid scrolls with a landmark on each bar. The alternative,
dividing the whole break into 16, would give quarter note slices on a four bar
break, which cannot chop.

That makes `BreakRef.bars` load bearing rather than cosmetic. Get it wrong and
every slice is the wrong note value.

To add a break: drop the WAV into `assets/breaks/`, add a `BreakRef` to
`BreakLibrary.bundled`, and add a row to [LICENSING.md](LICENSING.md). 8, 16,
24 and 32 bit PCM and float WAVs all decode, mono or stereo, any sample rate.

The synthesised fallback break is generated, not sampled, so it is guaranteed
clear:

```sh
dart run tool/make_break.dart
```

## Working rules

Brian is the only one who commits. Every milestone has a gate in MILESTONES.md
and the next one does not start until the gate is called.
