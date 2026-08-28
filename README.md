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
flutter test integration_test -d macos   # the real audio device and decoder
```

The unit tests prove the mixer produces the right samples. The integration
tests prove those samples reach an output device, by checking that the device
consumed them, and that the platform audio decoder behind import agrees with
the Dart one. Both matter; neither substitutes for the other.

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

That swap has happened, behind a flag. `packages/junglengine_engine` holds the
mixer, the sub synth, the device and the C ABI, in Rust, and
`lib/audio/lira_engine.dart` implements the same `AudioEngine` over it.
`--dart-define=JE_LIRA_ENGINE=true` picks it; flutter_soloud is still what
ships. Both stay until the A/B on a phone says which one wins, and the reason
to swap turns out not to be CPU: read `docs/M4.md` before assuming it is.

**Building the app therefore needs a Rust toolchain** (<https://rustup.rs>).
The iOS, macOS and Android builds compile the crate themselves and add the
targets they need; without cargo on `PATH` they stop with an error saying so.

A `RenderSpec` is a list of sections, each one a Beat's turn on the timeline.
A pattern is one section looping; a song is one section per pass. The sequencer
never knows which it is playing, which is what makes an arrangement seamless
across machine types for free.

- `lib/audio/engine.dart` — the interface everything else talks to
- `lib/audio/pattern_renderer.dart` — the mixer, the only thing that makes sound
- `lib/audio/soloud_engine.dart` — flutter_soloud implementation
- `lib/audio/lira_engine.dart` — the Rust engine, behind `JE_LIRA_ENGINE`
- `lib/audio/platform_session.dart` — claiming the platform audio session,
  which is a platform concern rather than an engine one, so both share it
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

Three kits ship: `hawkstreak-01` is the bright one, `hawkstreak-02` the dark
one, and `hawkstreak-03` is the metal one in the Pro Nightshift pack. Because
slots are positional, switching kit keeps every pattern and every slot setting:
the same programming played by different drums, free kit to paid one included.

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

To add a break: drop the WAV into `assets/breaks/`, add a `BreakRef` to a pack
in `PackLibrary.all`, and add a row to [LICENSING.md](LICENSING.md). 8, 16, 24
and 32 bit PCM and float WAVs all decode, mono or stereo, any sample rate.

The Hawkstreak breaks — Amenish, Steppa, the two bar Roller, and Duppy and Lurch
in the Nightshift pack — are generated, not sampled, so they are guaranteed
clear:

```sh
dart run tool/make_break.dart
```

## Packs

Breaks and kits are grouped into packs, and a pack is where content is
registered: `PackLibrary.all` is the catalogue, and `BreakLibrary.bundled` and
`KitLibrary.bundled` are flattened out of it, so nothing below the library knows
packs exist. A project stores a break id and a kit id as it always did, so packs
changed no JSON and needed no schema bump.

**Starter** is free and is what the app opens with. **Nightshift** is Pro: two
breaks and a kit, unlocked by the same one purchase as import and MIDI export,
along with every pack after it. Everything ships inside the binary; there are no
downloads and there is no server.

The gate is on picking, not on playing. Selecting a locked row shows the
paywall; a project that already points at a pack break goes on playing it
whatever the store says, because the store has not answered yet on a cold start
and because changing the break reslices every Chop Beat.

[docs/PACKS.md](docs/PACKS.md) is the recipe for adding one.

## Bring your own audio

Pro imports any file the phone can decode. WAV and AIFF are read in Dart; MP3,
M4A, AAC, ALAC, FLAC and Ogg go through the platform's own decoders behind
`packages/junglengine_decode`, which is a local plugin wrapping `AVAudioFile` on
Apple platforms and `MediaCodec` on Android. Nothing is resampled or folded to
mono on the way in that the mixer would not do anyway.

The import screen asks the three things the app must not guess: where the loop
starts, how many bars it is, and what tempo that makes it. Tempo is derived from
the trim and the bar count, so typing a tempo or tapping one in moves the end of
the trim to match. The trim is baked into the file that lands in the imports
directory, so what the grid chops is exactly what you heard on that screen.

The app is also registered for audio document types on both platforms, so it is
in the Open In list in Files, Safari, Mail and the messengers. A file arriving
that way goes straight to the same import screen.

One break per project still holds: importing a second one replaces the first,
and the file it stopped pointing at is swept. Kit slots are per slot, so an
imported one shot replaces what slot *n* plays and leaves the other seven alone.

## Parts export

The export sheet's third mode writes a zip: a MIDI file, the samples it plays,
and a README naming every note.

Samples are numbered in mapping order, because both of Reason's samplers map a
multiple selection up the keyboard in file order. A Chop Beat exports every
slice, plus one extra file for each reverse, pitch down or half speed step the
pattern actually uses; a retrigger is four notes rather than a fifth sample. A
Kit Beat exports eight slots with volume and pitch baked in. Swing is in the
tick positions, so the MIDI and the WAV of one Beat land on the same grid. The
sub lane rides on its own channel as real pitches.

One Beat, one pass. A song is what WAV export is for.

## Pro

One purchase, no subscription, no ads. Import, the parts export, and slice packs
when they land; everything else is free and stays free.

`lib/features/pro/` holds it. The store sits behind a `ProStore` interface,
which is what makes a paywall testable without a real purchase, and the
entitlement is cached in a file so a Pro user who opens the app on a plane is
still Pro. The store is the authority and overwrites that cache either way.

## Crash reporting and analytics

Four events, named in `TelemetryEvent`, and no others. The app runs with no
Firebase project behind it and falls back to doing nothing, which is what a
fresh clone does. See [docs/PRIVACY.md](docs/PRIVACY.md) for what is collected
and [docs/RELEASE.md](docs/RELEASE.md) for how to switch it on.

## Working rules

Brian is the only one who commits. Every milestone has a gate in MILESTONES.md
and the next one does not start until the gate is called.

What M3 still needs from a human -- audio clearance, a Firebase project, the
Pro product in both consoles, signing keys, and the Reason 13 check -- is listed
in [docs/RELEASE.md](docs/RELEASE.md).
