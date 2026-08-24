# junglengine_engine

junglEngine's audio engine, in Rust. The mixer and the sub synth, ported from
`lib/audio/` so they can run inside an audio callback instead of ahead of one.

This is stage 1 of M4 and nothing in the app calls it yet. Why it exists, what
it is measured against and what comes next is `docs/M4.md`.

```sh
cd rust
cargo build --release
cargo clippy --all-targets
```

## What is here

- `rust/src/spec.rs` — the render spec, read from the app's own JSON. A `Beat`
  here parses what `Beat.toJson()` writes there, field for field, including
  both shapes a Chop step can take. One wire format for the file, for the FFI
  boundary and for the parity fixtures.
- `rust/src/sub_voice.rs` — the sub synth. Five parameters, and five is still
  the ceiling.
- `rust/src/renderer.rs` — the mixer. Both machines, the song, the swing, the
  step modifiers, the master saturation. Nothing below the block loop
  allocates.
- `rust/src/bin/je_render.rs` — renders a fixture spec to raw f32, for the
  parity test.
- `rust/src/bin/je_bench.rs` — times the mixer, for the A/B.

## Proving it is the same mixer

```sh
flutter test test/audio/rust_parity_test.dart   # from the app root
```

Renders four fixtures through both mixers and compares them frame by frame.
Nothing is committed as a golden: the Dart side writes the source audio it
rendered with and the Rust binary reads exactly those bytes.

## Timing it against the Dart mixer

```sh
dart compile exe tool/engine_bench.dart -o build/engine_bench
./build/engine_bench
```

The AOT number is the one to quote. A release build of the app is AOT.
