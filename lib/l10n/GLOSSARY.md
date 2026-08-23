# Translator glossary

junglEngine is a breakbeat resequencer: a tool for cutting a drum loop into
slices and rearranging them on a grid, plus a small bass synthesiser. The people
using it are music producers, and the interface is deliberately terse.

Two things follow from that, and they govern every string in `app_en.arb`.

## 1. Some words stay English everywhere

These are engraved on the face of real hardware, or they name a value chosen
from a fixed engineering set. A producer in any country reads them faster in
English than in translation, exactly as they do on a drum machine's front panel.
**They never appear in the ARB files at all** — they are hardcoded in the app, so
there is nothing to do about them. They are listed here only so that when one
turns up *inside* a translatable string, you leave it alone:

> BPM · SWING · SLICES · SLICE · KIT · CHOP · SUB · VOL · PITCH ·
> TONE · CUTOFF · DRIVE · DECAY · GLIDE · WAV · MIDI · PRO ·
> kHz · bit · 44.1 kHz 16 bit · Kong · NN-XT · Files · iCloud · Drive ·
> the note names C to B · the kit slot labels KICK SNR RIM CLAP CH OH SHKR
> CNGA WOOD TAMB TOM · the app name junglEngine

Where one of these is embedded in a string you are translating, the string's
`@description` says so explicitly.

## 2. Everything else is translated, including the words that look technical

BAR, BARS, STEP, SLOT, BREAK, SONG, BEAT, CARD, MACHINE, ARRANGEMENT and
REPEATS **do** get translated. `BAR` cannot stay English while `2 BARS` is a
sentence with a plural in it, and the plural wins.

Domain meanings, so the translation is about the right thing:

| Term | What it means here |
|---|---|
| break | a sampled drum loop, the raw material of the whole app |
| slice | one piece the break was cut into |
| step | one cell in the sequencer grid |
| bar | a musical bar, four beats |
| beat | one pattern in the project (not a single drum hit) |
| song | an ordered list of patterns with repeat counts |
| card | one entry in that list |
| kit | a set of eight drum samples |
| one shot | a single drum sample played once, never looped |
| pad | one drum sound's row in the kit grid |
| lane | the horizontal track the bass notes sit in |
| accent | a louder, brighter note |
| chop | to cut audio into pieces |
| scramble | to randomly rearrange the slices |

## 3. Two registers, deliberately

- **UPPERCASE** for labels, buttons and headings. Most of the app.
- **Sentence case** for body copy: the descriptions under the export options and
  the Pro feature list.

Keep whichever register the English uses. `barCount` is the uppercase one and
`barCountSentence` is the sentence case one; they exist as a pair for exactly
this reason. In languages without letter case the two are simply identical, and
that is fine.

## 4. Length matters more than usual

This is a phone app with a dense, tightly packed interface. Several strings sit
in fixed size boxes and will be clipped rather than wrapped if they run long.
Every `@description` that has a tight budget says so in words, for example
"Fits a 42x30 chip, 8 characters max." Treat those as hard limits and find a
shorter phrasing rather than a literal one. Where the description says nothing
about length, the string is free to wrap.

## 5. Plurals

Use your language's full set of CLDR plural categories, not just one and other.
Russian needs `one`, `few`, `many`, `other`. Arabic needs `zero`, `one`, `two`,
`few`, `many`, `other`. The English template only shows `=1` and `other` because
that is all English has.

## 6. Numbers stay as they are

Do not add `format` to any placeholder and do not convert digits to another
numeral system. Every number in this app lands in a monospaced readout next to
other numbers, and Western Arabic numerals are what a producer expects on a
tempo display.
