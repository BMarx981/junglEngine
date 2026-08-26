# junglengine_engine

junglEngine's audio engine, in Rust, and the `dart:ffi` boundary to it.

The mixer and the sub synth are ports of `lib/audio/`, so that they can run
*inside* an audio callback instead of ahead of one. That is the whole argument
for M4 and it is about latency, not speed: why, and what it is measured
against, is `docs/M4.md`.

Nothing runs this by default. `--dart-define=JE_LIRA_ENGINE=true` picks it over
flutter_soloud, and both ship until the A/B on a phone says which one stays.

**Building junglEngine needs a Rust toolchain.** <https://rustup.rs>. The
platform builds add the targets they need themselves.

```sh
cd rust
cargo build --release
cargo clippy --all-targets
cargo test
```

## What is here

The mixer, unchanged in intent since stage 1:

- `rust/src/spec.rs` — the render spec, read from the app's own JSON. A `Beat`
  here parses what `RenderSpec.toEngineJson` writes there, field for field,
  including both shapes a Chop step can take. One wire format for the file, for
  the FFI boundary and for the parity fixtures.
- `rust/src/sub_voice.rs` — the sub synth. Five parameters, and five is still
  the ceiling.
- `rust/src/renderer.rs` — the mixer. Both machines, the song, the swing, the
  step modifiers, the master saturation.
- `rust/src/offline.rs` — the export path: the whole render in one call, with
  the ring out folded back over the head of the file.

And the device, which is what stage 2 added:

- `rust/src/plan.rs` — what the control thread hands the audio thread. Pattern
  data, the audio it reads, and every step boundary already worked out. Built
  whole, published whole, returned whole.
- `rust/src/device.rs` — the control thread and the cpal stream. One thread
  owns the stream for its whole life.
- `rust/src/audio.rs` — what the callback owns. No allocation, no
  deallocation, no locks, no blocking.
- `rust/src/command.rs` — what crosses, in both directions. The second
  direction carries nothing but things to drop.
- `rust/src/preview.rs` — the audition voice. One tap, one voice reading a
  range of audio that is already there.
- `rust/src/transport.rs` — the playhead, as a `#[repr(C)]` struct of atomics
  Dart maps once and reads without a call. It also carries the M4 edit-to-
  audible measurement, which is one more thing the callback leaves behind
  rather than one more call.
- `rust/src/ffi.rs` — the C ABI, and the whole of it. Eighteen entry points,
  one per method on `AudioEngine` plus the transport and the last error. If a
  function here has no counterpart on that interface, it does not belong.

Dart:

- `lib/src/bindings.dart` — one declaration per entry point, hand written,
  because the boundary is small enough to read in one sitting.
- `lib/junglengine_engine.dart` — where to find the library. Static and already
  in the process on iOS and macOS, a named shared object on Android.

The `AudioEngine` implementation is *not* here. It is `lib/audio/lira_engine.dart`
in the app, because that is where `RenderSpec` and `AudioClip` live and this
package has no business knowing what a Beat is.

## The platform builds

- `rust/build_apple.sh ios` → `ios/junglengine_engine.xcframework`. A device
  slice and a simulator slice are different platforms, not different
  architectures, so they cannot share one static library.
- `rust/build_apple.sh macos` → `macos/libjunglengine_engine.a`, fat.
- `rust/build_android.sh <ndk> <out>` → one `.so` per ABI, linked with the
  NDK's own clang wrappers so the toolchain requirement stays rustup and
  nothing else.

Each podspec runs the Apple script twice: once at `pod install`, so there is
something to vendor, and once before every compile, so editing Rust and hitting
run works the way editing Dart does. Gradle runs the Android script before
`preBuild`.

CocoaPods only. Swift Package Manager has no equivalent of `prepare_command`
and the build has to run cargo before anything can be vendored, so `flutter
build` warns that this plugin does not support SPM. It still builds.

**Android needs API 26**, because AAudio does. The library's `minSdk` is left
at the app's 24 on purpose so that depending on this package does not silently
raise the whole app's minimum; below 26 the shared object does not load. See
`docs/M4.md`.

## Proving it is the same mixer

```sh
flutter test test/audio/rust_parity_test.dart   # from the app root
flutter test test/audio/lira_engine_test.dart
```

The first renders four fixtures through both mixers and compares them frame by
frame, on both the playback path and the export path. Nothing is committed as a
golden: the Dart side writes the source audio it rendered with and the Rust
binary reads exactly those bytes.

The second drives `LiraAudioEngine` the way the app does — over the FFI, with a
real device open — for everything the mixer parity test cannot reach: the ABI,
the control thread, the plan ring, the queued Beat swap and the shared
transport.

Both skip, loudly, when there is no cargo on the machine, and the second also
skips when there is no audio output. `flutter test` has to pass on a checkout
that has never built the engine.

## Playing something out of a real device

```sh
cd rust && cargo run --release --bin je_device 4
```

Opens the default output and plays a bar through the whole stack, then
republishes under the running transport. This is the smoke test for a platform
nobody has tried yet; on a phone, the app with `JE_LIRA_ENGINE=true` is the
same test with Dart on the other end.

## Timing it against the Dart mixer

```sh
dart compile exe tool/engine_bench.dart -o build/engine_bench
./build/engine_bench
```

The AOT number is the one to quote. A release build of the app is AOT.
