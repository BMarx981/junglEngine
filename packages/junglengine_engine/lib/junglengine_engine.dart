/// junglEngine's audio engine, over `dart:ffi`.
///
/// This package is the boundary and nothing else: the Rust crate, the platform
/// builds that compile it, and the entry points below. The `AudioEngine`
/// implementation that uses them lives in the app, in `lib/audio/`, because
/// that is where `RenderSpec` and `AudioClip` live and this package has no
/// business knowing what a Beat is.
library;

import 'dart:ffi';
import 'dart:io';

export 'src/bindings.dart';

import 'src/bindings.dart';

/// Where to find the compiled engine when it is not already in the process.
///
/// Set by the host test that drives the engine from the Dart VM, where there
/// is no Flutter bundle to have linked it. Never set in the app.
String? engineLibraryPathOverride;

JeBindings? _bindings;

/// The engine's entry points, looked up once.
///
/// On iOS and macOS the crate is a static library linked into the app binary,
/// so the symbols are already in the process. On Android it is a shared object
/// the loader has to be pointed at by name.
JeBindings get engineBindings => _bindings ??= JeBindings(_open());

DynamicLibrary _open() {
  final override = engineLibraryPathOverride;
  if (override != null) return DynamicLibrary.open(override);

  if (Platform.isAndroid) {
    return DynamicLibrary.open('libjunglengine_engine.so');
  }
  if (Platform.isIOS || Platform.isMacOS) {
    final process = DynamicLibrary.process();
    if (process.providesSymbol('je_engine_new')) return process;
    // A Dart VM rather than an app bundle: nothing linked the crate in, so
    // there is nowhere to look without being told where.
    throw StateError(
      'junglengine_engine is not linked into this process. Build the crate '
      'and set engineLibraryPathOverride to the library it produced.',
    );
  }
  throw UnsupportedError(
    'junglengine_engine has no build for ${Platform.operatingSystem}',
  );
}
