// The C ABI of `packages/junglengine_engine/rust/src/ffi.rs`, one Dart
// declaration per `#[no_mangle]` function over there.
//
// Hand written rather than generated, because the boundary is deliberately
// small enough to read in one sitting and a generator would be a build step
// standing between a change and noticing it broke.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// The shared playhead, mapped rather than called.
///
/// Mirrors `TransportShared` in `rust/src/transport.rs` field for field, in
/// the same order: the 64 bit fields first so neither side has to reason about
/// padding. A Rust test asserts the size and alignment this depends on.
final class JeTransport extends Struct {
  @Uint64()
  external int planId;

  @Uint64()
  external int frame;

  @Uint64()
  external int positionBits;

  /// Edits that have become audible. Bumped once per measurement, so a reader
  /// can tell a new one from the last without a call and without a timestamp.
  @Uint64()
  external int editSeq;

  /// Microseconds between the last edit being published and the callback that
  /// rendered it. Read [editSeq] either side of this: the pair is written
  /// latency first, count second.
  @Uint64()
  external int editLatencyMicros;

  /// Odd while the audio thread is writing. Read either side of the fields and
  /// retry if it moved: one writer, so this half of the seqlock never waits.
  @Uint32()
  external int version;

  @Uint32()
  external int playing;

  @Int32()
  external int step;

  @Int32()
  external int stepCount;

  @Int32()
  external int entryIndex;

  /// Which section of the plan is sounding. A Beat id is a string and the
  /// audio callback may not touch one, so the index crosses and the Dart side
  /// looks the id up against the spec that plan was built from.
  @Int32()
  external int section;

  /// What the output device is doing: [jeDeviceOpen], [jeDeviceSuspended] or
  /// [jeDeviceLost]. The one field here the audio callback does not write, and
  /// so the one that is read on its own rather than through [version].
  @Uint32()
  external int deviceState;
}

/// Success. Anything negative is a failure whose reason is on [JeBindings.lastError].
const int jeOk = 0;

/// The output is open and the callback is running.
const int jeDeviceOpen = 0;

/// The device was handed back on purpose, by [JeBindings.suspend].
const int jeDeviceSuspended = 1;

/// The stream failed underneath the engine: a call arriving, a route change,
/// media services restarting. The engine has closed what was left of it and is
/// waiting to be told to try again.
const int jeDeviceLost = 2;

typedef JeNewNative = Pointer<Void> Function(Uint32);
typedef JeNewDart = Pointer<Void> Function(int);

typedef JeVoidHandleNative = Void Function(Pointer<Void>);
typedef JeVoidHandleDart = void Function(Pointer<Void>);

typedef JeIntHandleNative = Int32 Function(Pointer<Void>);
typedef JeIntHandleDart = int Function(Pointer<Void>);

typedef JeRateNative = Uint32 Function(Pointer<Void>);
typedef JeRateDart = int Function(Pointer<Void>);

typedef JePlanIdNative = Uint64 Function(Pointer<Void>);
typedef JePlanIdDart = int Function(Pointer<Void>);

typedef JeTransportNative = Pointer<JeTransport> Function(Pointer<Void>);
typedef JeTransportDart = Pointer<JeTransport> Function(Pointer<Void>);

typedef JeSetBreakNative =
    Int32 Function(Pointer<Void>, Pointer<Float>, Int64);
typedef JeSetBreakDart = int Function(Pointer<Void>, Pointer<Float>, int);

typedef JeSetKitNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Pointer<Float>>,
      Pointer<Int64>,
      Int32,
    );
typedef JeSetKitDart =
    int Function(Pointer<Void>, Pointer<Pointer<Float>>, Pointer<Int64>, int);

typedef JeSetSpecNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, Int64, Int32);
typedef JeSetSpecDart = int Function(Pointer<Void>, Pointer<Uint8>, int, int);

typedef JeLoopFramesNative = Int64 Function(Pointer<Uint8>, Int64);
typedef JeLoopFramesDart = int Function(Pointer<Uint8>, int);

typedef JeRenderOfflineNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, Int64, Int64, Pointer<Float>);
typedef JeRenderOfflineDart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, int, Pointer<Float>);

typedef JeAuditionIndexNative = Int32 Function(Pointer<Void>, Int32);
typedef JeAuditionIndexDart = int Function(Pointer<Void>, int);

/// A slot and the level to sound it at, in the spec's own velocity encoding.
typedef JeAuditionKitNative = Int32 Function(Pointer<Void>, Int32, Int32);
typedef JeAuditionKitDart = int Function(Pointer<Void>, int, int);

typedef JeAuditionClipNative =
    Int32 Function(Pointer<Void>, Pointer<Float>, Int64, Int32);
typedef JeAuditionClipDart =
    int Function(Pointer<Void>, Pointer<Float>, int, int);

typedef JeLastErrorNative = Pointer<Utf8> Function();
typedef JeLastErrorDart = Pointer<Utf8> Function();

/// The looked up entry points, resolved once.
class JeBindings {
  JeBindings(DynamicLibrary library)
    : newEngine = library.lookupFunction<JeNewNative, JeNewDart>(
        'je_engine_new',
      ),
      freeEngine = library.lookupFunction<JeVoidHandleNative, JeVoidHandleDart>(
        'je_engine_free',
      ),
      sampleRate = library.lookupFunction<JeRateNative, JeRateDart>(
        'je_engine_sample_rate',
      ),
      transport = library.lookupFunction<JeTransportNative, JeTransportDart>(
        'je_engine_transport',
      ),
      lastPlanId = library.lookupFunction<JePlanIdNative, JePlanIdDart>(
        'je_engine_last_plan_id',
      ),
      setBreak = library.lookupFunction<JeSetBreakNative, JeSetBreakDart>(
        'je_engine_set_break',
      ),
      setKit = library.lookupFunction<JeSetKitNative, JeSetKitDart>(
        'je_engine_set_kit',
      ),
      setSpec = library.lookupFunction<JeSetSpecNative, JeSetSpecDart>(
        'je_engine_set_spec',
      ),
      cancelQueuedSpec = library
          .lookupFunction<JeIntHandleNative, JeIntHandleDart>(
            'je_engine_cancel_queued_spec',
          ),
      start = library.lookupFunction<JeIntHandleNative, JeIntHandleDart>(
        'je_engine_start',
      ),
      stop = library.lookupFunction<JeIntHandleNative, JeIntHandleDart>(
        'je_engine_stop',
      ),
      suspend = library.lookupFunction<JeIntHandleNative, JeIntHandleDart>(
        'je_engine_suspend',
      ),
      resume = library.lookupFunction<JeIntHandleNative, JeIntHandleDart>(
        'je_engine_resume',
      ),
      auditionSlice = library
          .lookupFunction<JeAuditionIndexNative, JeAuditionIndexDart>(
            'je_engine_audition_slice',
          ),
      auditionKitSlot = library
          .lookupFunction<JeAuditionKitNative, JeAuditionKitDart>(
            'je_engine_audition_kit_slot',
          ),
      auditionClip = library
          .lookupFunction<JeAuditionClipNative, JeAuditionClipDart>(
            'je_engine_audition_clip',
          ),
      stopAuditionClip = library
          .lookupFunction<JeIntHandleNative, JeIntHandleDart>(
            'je_engine_stop_audition_clip',
          ),
      loopFrames = library.lookupFunction<JeLoopFramesNative, JeLoopFramesDart>(
        'je_engine_loop_frames',
      ),
      renderOffline = library
          .lookupFunction<JeRenderOfflineNative, JeRenderOfflineDart>(
            'je_engine_render_offline',
          ),
      _lastError = library.lookupFunction<JeLastErrorNative, JeLastErrorDart>(
        'je_last_error',
      );

  final JeNewDart newEngine;
  final JeVoidHandleDart freeEngine;
  final JeRateDart sampleRate;
  final JeTransportDart transport;
  final JePlanIdDart lastPlanId;
  final JeSetBreakDart setBreak;
  final JeSetKitDart setKit;
  final JeSetSpecDart setSpec;
  final JeIntHandleDart cancelQueuedSpec;
  final JeIntHandleDart start;
  final JeIntHandleDart stop;

  /// Closes the output and stops the transport, keeping everything else.
  final JeIntHandleDart suspend;

  /// Opens the output again. Returns the rate it opened at, which a phone is
  /// free to have changed while the device was closed, or a negative code.
  final JeIntHandleDart resume;
  final JeAuditionIndexDart auditionSlice;
  final JeAuditionKitDart auditionKitSlot;
  final JeAuditionClipDart auditionClip;
  final JeIntHandleDart stopAuditionClip;
  final JeLoopFramesDart loopFrames;
  final JeRenderOfflineDart renderOffline;
  final JeLastErrorDart _lastError;

  /// Why the last call on this thread failed, or null. Read immediately after
  /// a failure or not at all: the next failing call overwrites it.
  String? get lastError {
    final pointer = _lastError();
    return pointer == nullptr ? null : pointer.toDartString();
  }
}
