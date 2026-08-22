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
replace it at M4 without the grid, the sequencer or the exporter noticing.

A `RenderSpec` is a list of sections, each one a Beat's turn on the timeline.
A pattern is one section looping; a song is one section per pass. The sequencer
never knows which it is playing, which is what makes an arrangement seamless
across machine types for free.

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

Swing is one control per Beat, 50% to 75%, and it pushes every odd sixteenth
late. That is the answer to triplet feel; triplet grids are parked.

The open project is saved to the app documents directory as JSON, shortly after
every edit and immediately when the app is backgrounded, and it reopens on
launch. Local only: no cloud, no accounts, no project browser.

## Step modifiers

Hold a painted cell on the Chop grid to put one of four modifiers on it:

| | | |
| --- | --- | --- |
| `R` | reverse | the slice plays backwards |
| `4` | retrigger | the head of the slice fires four times inside the step |
| `▼` | pitch down | a fourth down, so it is also longer |
| `½` | half speed | an octave down, twice the length |

They are per step because that is where they are heard: one reversed snare in a
bar, not a reversed pattern. Four of them is the ceiling — anything more is an
effect, and effects are parked.

The sub lane has one modifier of its own: hold a note to accent it. An accent
opens the filter and lifts the level a few dB, which together is what makes the
same bassline speak over the drums.

## Songs

The Song view is a vertical list of cards. Each card is a Beat and a repeat
count; drag to reorder, tap to open that Beat's grid, stepper to set repeats.
It is a list, not a timeline: entries follow each other, nothing overlaps and
nothing is positioned in pixels per bar.

Playback in the Song view runs the whole arrangement, and the export sheet gains
a SONG mode that renders it once through. Editing a card while the song plays
does not restart it: the renderer swaps the new timeline in underneath the
playhead as long as whatever is sounding is still there afterwards.

## Kits

`KitLibrary.bundled` lists what ships, and a kit is exactly eight samples.
Slots are positional: slot *n* plays sample *n*, and a Beat's per slot volume
and pitch hang off that position. One kit per project, like the break, chosen
from the library sheet behind the break name in the transport bar.

Two kits ship: `hawkstreak-01` is the bright one, `hawkstreak-02` the dark one.
Because slots are positional, switching kit keeps every pattern and every slot
setting: the same programming played by different drums.

The bundled kits are synthesised, not sampled, so they are guaranteed clear:

```sh
dart run tool/make_kit.dart
```

## Breaks

`BreakLibrary.bundled` lists what ships. The first entry is what a new project
opens with, and the library sheet behind the break name in the transport bar
switches it. Still one break per project: that picks which, not how many.

Switching the break keeps the patterns. Every Chop Beat is re-divided at the
division it was already using, and any painted slice past the end of a shorter
break is dropped.

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

The Hawkstreak breaks — Amenish, Steppa and the two bar Roller — are generated,
not sampled, so they are guaranteed clear:

```sh
dart run tool/make_break.dart
```

## Working rules

Brian is the only one who commits. Every milestone has a gate in MILESTONES.md
and the next one does not start until the gate is called.
