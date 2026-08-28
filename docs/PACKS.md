# Content packs

> Free: bundled breaks, grid, sub lane, wav export. Pro: import your own audio,
> midi plus slices zip export, slice packs.
>
> -- CLAUDE.md, the monetisation shape

A pack is a set of breaks and kits that ship together and unlock together. Two
of them exist: **Starter**, which is free and is what the app opens with, and
**Nightshift**, which is Pro.

Packs were promised before they were built. `ProFeature.packs` has been on the
paywall since M3 -- "SLICE PACKS: breaks and kits made for this, as they land"
-- and `docs/STORE.md` says the same in the listing. This is that, delivered.

## What a pack is, and what it is not

It is a grouping and an entitlement. `PackLibrary.all` in
`lib/features/library/pack.dart` is the catalogue, and `BreakLibrary.bundled`
and `KitLibrary.bundled` are flattened out of it:

```dart
static final List<BreakRef> bundled = List<BreakRef>.unmodifiable([
  for (final pack in PackLibrary.all) ...pack.breaks,
]);
```

That is the whole design. Every call site kept working -- the sequencer, the
exporter, the importer, `studio.dart`, and their tests did not move a line --
because below the library nothing knows packs exist. The same move M4 made to
keep `AudioEngine` still while the engine underneath it changed.

**A pack is never project data.** A project stores a `breakId` and a `kitId`,
and both stay globally unique across packs, so grouping content changed no JSON
and needed no `schemaVersion` bump. A project file written before packs existed
opens exactly as it did.

## Three decisions, and why

### Bundled in the binary, not downloaded

Pack WAVs ship inside the app like every other asset. The alternative -- packs
on a static host, downloaded on demand -- keeps the binary small and lets packs
ship between app releases, and it costs a network layer this app does not have
at all: progress and failure UI, cache eviction, an offline story, and a new way
for a paid feature to be missing on a plane.

Nightshift costs about 800 KB. That is the price of not writing any of that.
`LICENSING.md` already assumed this shape before the code did: *"anything
Hawkstreak ships as a pack is bundled content and gets a row in the tables
above."*

If a pack ever gets big enough that this stops being true, `Pack` is the place a
source would be added, and nothing outside `pack.dart` and the library sheet
would have to know.

### Included in Pro, not sold separately

One non-consumable, bought once, unlocks every pack -- present and future. That
is what the shipped paywall copy promises, and it is what CLAUDE.md means by
"one product, bought once, forever". Per-pack purchases would need a product
catalogue, per-pack entitlement storage and a restore across N products, and
would make the paywall's third selling point a lie.

### The gate is on picking, not on playing

Selecting a locked row shows the paywall. A project that **already** points at a
pack break goes on playing it whatever the store currently says.

This is not laxity, it is the only safe rule. `ProPhase.checking` is the state
every cold start begins in, before the store has answered; gating at load time
would reset a paid-for project every time the app opened offline. And falling
back to the default break runs `_applyBreak`, which reslices every Chop Beat --
so a store hiccup would cost the user their patterns. Nothing about entitlement
is allowed to destroy work.

There is no receipt validation and no server here, and there is not going to be
one. See the note in `pro_controller.dart`: a user who defeats this has unlocked
a phone app with no server behind it, and there is nothing to defend.

## Adding a pack

1. **Make the audio.** `tool/make_break.dart` and `tool/make_kit.dart` generate
   everything Hawkstreak ships: original content, synthesised from scratch,
   deterministic from a seed, and clear by construction. Add build functions and
   a call in `main`, then `dart run tool/make_break.dart`. Regenerating rewrites
   the existing files byte for byte, so a diff that shows only the new WAVs is
   the tool telling you it stayed put.

   A break's file must be exactly the number of bars its `BreakRef` declares.
   `bars` is not cosmetic: slice divisions are per bar, so a wrong count makes
   every slice the wrong note value. The generator prints the bar count it
   wrote; check it against the `BreakRef`.

   A kit is exactly eight samples in the fixed positional order -- kick, snare,
   rim, clap, closed hat, open hat, shaker, conga. Labels can differ per kit,
   positions cannot, which is what lets a project switch kits and keep its
   pattern, including switching from a free kit to a paid one.

2. **Register it.** Add a `Pack` to `PackLibrary.all`, appended after the
   existing ones. Free packs must stay first: `BreakLibrary.defaultBreak` is the
   first break of the first pack, and a Pro pack in front of it would open the
   app behind its own paywall. There is a test for that.

3. **Declare the assets** in `pubspec.yaml` under `assets:`. A WAV that exists
   but is not declared ships in the repo and not in the app, which looks
   identical until the phone asks for it. There is a test for that too.

4. **Write the LICENSING.md rows**, one per break and one per kit, under a
   heading for the pack. Being Pro content buys no exemption; if anything it
   raises the stakes, because an unclearable free break is embarrassing and an
   unclearable paid one is a refund. `pack_library_test.dart` fails if a row is
   missing.

5. **Names.** A pack name and a break name are proper nouns: they are hardcoded,
   not in the ARB files, and stay English in every locale like the app's own
   name does. They are listed in `lib/l10n/GLOSSARY.md` under the words that
   stay English. Do not give a kit the same name as its pack -- the sheet then
   reads NIGHTSHIFT over NIGHTSHIFT. Kits are named in series: Hawkstreak 01,
   02, 03.

   **Display names are free to change; ids are not.** A project stores the id,
   so renaming one after a release orphans every project pointing at it and
   silently drops that project back to the default break.

6. **Run the tests.** `flutter test` whole, not just the new file: the derived
   lists mean a pack change reaches everything, and a green existing suite is
   the proof that it stayed invisible.

## What is in the library sheet

Grouped by pack under the existing BREAK and KIT headings, with the pack name
over each group. A locked row is dimmed and carries the PRO tag, and the tag is
on the row rather than only on the heading because the sheet scrolls and a
heading that has gone off the top is not a warning.

The sheet is scroll controlled and capped at 85% of the screen, so it can be as
tall as the library needs while always leaving a strip of scrim to dismiss it.
It will need a different shape -- a pack picker, probably -- somewhere around
the fourth or fifth pack. It is a list until then.
