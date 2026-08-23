# Store listing

Copy for App Store Connect and the Play Console. Kept in the repo so it changes
in the same commit as the thing it describes.

## Name and identity

- **App name:** junglEngine
- **Bundle / application id:** `app.hawkstreak.junglengine`
- **Developer:** Hawkstreak
- **Primary category:** Music
- **Secondary category:** Entertainment
- **Age rating:** 4+ / Everyone. No user generated content sharing, no ads, no
  gambling, no unrestricted web access.
- **Privacy policy URL:** publish `docs/PRIVACY.md` and put its URL here before
  submitting. Both stores require a reachable URL, not a file.

## Subtitle (App Store, 30 characters)

    Breakbeat chopper and sub

## Short description (Play, 80 characters)

    Chop breaks into a step grid, add a sub bass, and export. Jungle, on a phone.

## Promotional text (App Store, 170 characters)

    Load a break. Slice it. Paint the slices onto a grid until it grooves.
    Two machines, one sub synth, no menus to get lost in.

## Description

    junglEngine is a tracker style resequencer for breakbeats, plus a tiny
    monophonic sub synth. Two elements, drums and bass, and nothing else in the
    way.

    Load a break, slice it into equal divisions, and paint those slices onto a
    sixteen step grid. Hit play. The break comes back rearranged. That is the
    whole app, and everything else serves it.

    TWO MACHINES

    Chop resequences the break: rows are slices, columns are steps. Hold a cell
    to reverse it, retrigger it, drop it a fourth, or halve its speed.

    Kit is a step drum machine: eight one shot slots, three velocity levels per
    hit, volume and pitch per slot.

    Both carry the sub lane, both go in the same song, and both are one tap
    apart.

    SCRAMBLE

    One button that rearranges the bar and keeps it musical. Downbeats mostly
    stay put, the ghost notes and the snares move. Seeded, so undo puts it back.

    THE SUB

    A monophonic sine and triangle voice with one filter, drive, an amp envelope
    and glide. Five controls. Drag a cell up and down for pitch, tie two cells
    for a glide, hold one to accent it.

    SONGS

    A bank of Beats and a list of cards with repeat counts. Drag to reorder, tap
    to open. Playback runs the whole arrangement across both machines.

    EXPORT

    Render the loop or the whole arrangement to a 44.1 kHz WAV and send it
    wherever you finish tracks.

    PRO

    A single purchase, no subscription, and no ads anywhere in the app ever.

    - Import your own audio: any break or one shot from Files, iCloud, Drive or
      a message. Trim it, tap the tempo, chop it.
    - MIDI plus slices export: the beat as a MIDI file and the samples it plays,
      mapped to drop straight into Kong or NN-XT.
    - Slice packs as they land.

    Everything else stays free: every bundled break and kit, both machines, the
    grid, the sub lane, songs and WAV export.

    NOT A DAW

    No mixer, no timeline, no effects rack, no wavetables. It is a sketchpad for
    two elements, and the constraint is the point.

## Keywords (App Store, 100 characters, comma separated)

    jungle,breakbeat,dnb,break,chopper,sampler,sequencer,drum,808,sub,bass,amen,tracker,groovebox

## What's new (first release)

    First release.

## Screenshots

Six, in this order. Portrait, on the largest phone each store asks for.

1. The chop grid mid pattern, with the playhead in the bar and a couple of
   modifier badges visible.
2. The step modifier picker open over a painted cell.
3. The Kit grid with a groove on it and three velocity levels visible.
4. The sub lane with a bassline, a tie and an accent.
5. The Song view with five or six cards and repeat counts.
6. The import screen with a waveform trimmed and a tempo tapped in.

## App preview video

The fifteen second vertical demo clip, per the working rules in CLAUDE.md.

## Data safety and privacy nutrition labels

Answer both stores' questionnaires from `docs/PRIVACY.md`. In summary:

- **Collected, not linked to you:** crash data, and app interaction counts
  (four events).
- **Not collected:** name, email, address, phone, contacts, photos, audio,
  files, location, search history, purchase history, advertising id.
- **Tracking:** none. Do not request App Tracking Transparency; nothing here
  tracks across apps or sites.
- **Data is not sold or shared with third parties** beyond Google acting as the
  processor for Crashlytics and Analytics.

## In app purchase

One non consumable.

- **Product id:** `app.hawkstreak.junglengine.pro` (must match `proProductId`
  in `lib/features/pro/pro_state.dart`)
- **Reference name:** junglEngine Pro
- **Display name:** junglEngine Pro
- **Description:** Import your own breaks and one shots, and export MIDI plus
  sliced samples. One purchase, no subscription.
- **Review notes:** Pro features are reachable from the break library sheet
  (IMPORT YOUR OWN), a Kit slot sheet (IMPORT ONE SHOT), and the export sheet
  (PARTS). Restore is on the paywall.
