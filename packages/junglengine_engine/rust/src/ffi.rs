//! The C ABI, and the whole of it.
//!
//! Narrow on purpose. This is `AudioEngine` in `lib/audio/engine.dart` and
//! nothing more: if a function here has no counterpart on that interface, it
//! does not belong. The interface was written at M0 so that the engine behind
//! it could be replaced without the grid, the sequencer or the exporter
//! noticing, and the way to keep that true is to refuse to widen the boundary.
//!
//! Everything crosses at human speed. A spec is JSON -- the same JSON a saved
//! project holds -- parsed on the caller's thread, never in the callback. The
//! playhead does not cross at all: it is read straight out of the shared
//! struct [`je_engine_transport`] hands back.
//!
//! Conventions: `0` is success and a negative number is a failure whose reason
//! is on [`je_last_error`]. Every entry point catches panics, because
//! unwinding into Dart is undefined behaviour rather than a crash report.

use std::cell::RefCell;
use std::ffi::{c_char, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::time::Instant;

use crate::command::{Command, When};
use crate::device::Engine;
use crate::offline::render_offline;
use crate::plan::{Clip, Plan, Sources, Timeline};
use crate::spec::Spec;

pub const JE_OK: i32 = 0;
pub const JE_ERR_NULL: i32 = -1;
pub const JE_ERR_SPEC: i32 = -2;
pub const JE_ERR_ENGINE: i32 = -3;
pub const JE_ERR_PANIC: i32 = -4;

thread_local! {
    static LAST_ERROR: RefCell<Option<CString>> = const { RefCell::new(None) };
}

fn set_error(message: impl Into<Vec<u8>>) {
    let text = CString::new(message).unwrap_or_else(|_| {
        CString::new("junglengine: error message contained a nul byte")
            .expect("literal has no nul")
    });
    LAST_ERROR.with(|slot| *slot.borrow_mut() = Some(text));
}

/// The last failure on this thread, or null. Valid until the next failing call
/// on the same thread, so the Dart side reads it immediately or not at all.
///
/// # Safety
/// The returned pointer is owned by the engine and must not be freed.
#[no_mangle]
pub extern "C" fn je_last_error() -> *const c_char {
    LAST_ERROR.with(|slot| match slot.borrow().as_ref() {
        Some(text) => text.as_ptr(),
        None => ptr::null(),
    })
}

/// Runs `body`, turning a panic into an error code rather than letting it
/// unwind across the ABI.
fn guard<T>(fallback: T, body: impl FnOnce() -> T) -> T {
    match catch_unwind(AssertUnwindSafe(body)) {
        Ok(value) => value,
        Err(_) => {
            set_error("junglengine: the engine panicked");
            fallback
        }
    }
}

/// What Dart holds a pointer to.
///
/// The source audio is cached here rather than travelling with every spec: a
/// break is seconds of samples and a step edit publishes a spec sixty times a
/// second. Each published plan takes an `Arc` of whatever is cached, which is
/// also what makes an edit adoptable -- the renderer's test for "this can be
/// swapped in under the playhead" is that the new plan reads the same buffer.
pub struct EngineHandle {
    engine: Engine,
    break_clip: Clip,
    kit_clips: Vec<Clip>,
}

impl EngineHandle {
    fn sources(&self) -> Sources {
        Sources::new(self.break_clip.clone(), self.kit_clips.clone())
    }
}

/// Opens the device and starts the control thread, or returns null with the
/// reason on [`je_last_error`].
///
/// `sample_rate` is a request. The device may run at another rate and phones
/// regularly do, so the caller reads [`je_engine_sample_rate`] afterwards and
/// resamples what it decodes to that.
#[no_mangle]
pub extern "C" fn je_engine_new(sample_rate: u32) -> *mut EngineHandle {
    guard(ptr::null_mut(), || {
        // Something has to be loaded before the first spec arrives, because
        // the mixer is running from the moment the device opens. One empty bar
        // over two frames of silence is the smallest thing that is a valid
        // plan.
        let silence = Clip::silent(2);
        let spec = match Spec::from_json_str(&format!(
            r#"{{"sampleRate":{sample_rate},"bpm":170,"sections":[{{"beat":{{}}}}]}}"#
        )) {
            Ok(spec) => spec,
            Err(error) => {
                set_error(format!("junglengine: {error}"));
                return ptr::null_mut();
            }
        };
        let plan = Plan::new(0, spec, Sources::new(silence.clone(), Vec::new()));

        match Engine::new(sample_rate, plan) {
            Ok(engine) => Box::into_raw(Box::new(EngineHandle {
                engine,
                break_clip: silence,
                kit_clips: Vec::new(),
            })),
            Err(error) => {
                set_error(format!("junglengine: {error}"));
                ptr::null_mut()
            }
        }
    })
}

/// Closes the device, joins the control thread and frees everything. The
/// pointer is invalid afterwards.
///
/// # Safety
/// `handle` must come from [`je_engine_new`] and must not be used again.
#[no_mangle]
pub unsafe extern "C" fn je_engine_free(handle: *mut EngineHandle) {
    if handle.is_null() {
        return;
    }
    guard((), || {
        drop(unsafe { Box::from_raw(handle) });
    })
}

/// The rate the device actually opened at.
///
/// # Safety
/// `handle` must come from [`je_engine_new`].
#[no_mangle]
pub unsafe extern "C" fn je_engine_sample_rate(handle: *const EngineHandle) -> u32 {
    let Some(handle) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    handle.engine.sample_rate()
}

/// The shared playhead. Mapped once and read directly, which is the point of
/// it: no call per frame, and no estimate.
///
/// # Safety
/// `handle` must come from [`je_engine_new`]. The pointer is valid until
/// [`je_engine_free`].
#[no_mangle]
pub unsafe extern "C" fn je_engine_transport(
    handle: *const EngineHandle,
) -> *const crate::transport::TransportShared {
    match unsafe { handle.as_ref() } {
        Some(handle) => std::sync::Arc::as_ptr(handle.engine.transport()),
        None => ptr::null(),
    }
}

/// Loads the project break: interleaved stereo, already at
/// [`je_engine_sample_rate`]. Copied, so the caller may free `samples` on
/// return.
///
/// Takes effect on the next [`je_engine_set_spec`], because the audio a plan
/// reads and the pattern that reads it have to arrive together.
///
/// # Safety
/// `samples` must point to `frames * 2` floats.
#[no_mangle]
pub unsafe extern "C" fn je_engine_set_break(
    handle: *mut EngineHandle,
    samples: *const f32,
    frames: i64,
) -> i32 {
    guard(JE_ERR_PANIC, || {
        let Some(handle) = (unsafe { handle.as_mut() }) else {
            set_error("junglengine: null engine");
            return JE_ERR_NULL;
        };
        handle.break_clip = unsafe { read_clip(samples, frames) };
        JE_OK
    })
}

/// Loads the project kit: `count` clips, each interleaved stereo at the engine
/// rate. Copied, so the caller may free everything on return.
///
/// # Safety
/// `clips` must point to `count` pointers and `frames` to `count` lengths,
/// each clip holding `frames[i] * 2` floats.
#[no_mangle]
pub unsafe extern "C" fn je_engine_set_kit(
    handle: *mut EngineHandle,
    clips: *const *const f32,
    frames: *const i64,
    count: i32,
) -> i32 {
    guard(JE_ERR_PANIC, || {
        let Some(handle) = (unsafe { handle.as_mut() }) else {
            set_error("junglengine: null engine");
            return JE_ERR_NULL;
        };
        if count <= 0 || clips.is_null() || frames.is_null() {
            handle.kit_clips = Vec::new();
            return JE_OK;
        }
        let count = count as usize;
        let pointers = unsafe { std::slice::from_raw_parts(clips, count) };
        let lengths = unsafe { std::slice::from_raw_parts(frames, count) };
        handle.kit_clips = (0..count)
            .map(|i| unsafe { read_clip(pointers[i], lengths[i]) })
            .collect();
        JE_OK
    })
}

/// Installs what should be playing.
///
/// `json` is the app's own spec JSON. `when` is `SpecChange`: 0 for now, 1 for
/// the next bar line. Safe to call while the transport is running -- that is
/// the whole point -- and safe to call sixty times a second, because the plan
/// it builds is published to the callback rather than handed to it.
///
/// # Safety
/// `json` must point to `len` bytes of UTF-8.
#[no_mangle]
pub unsafe extern "C" fn je_engine_set_spec(
    handle: *mut EngineHandle,
    json: *const u8,
    len: i64,
    when: i32,
) -> i32 {
    guard(JE_ERR_PANIC, || {
        let Some(handle) = (unsafe { handle.as_mut() }) else {
            set_error("junglengine: null engine");
            return JE_ERR_NULL;
        };
        let spec = match unsafe { read_spec(json, len) } {
            Ok(spec) => spec,
            Err(code) => return code,
        };
        let sources = handle.sources();
        let id = handle.engine.next_plan_id();
        let mut plan = Plan::new(id, spec, sources);
        // Stamped here, on the caller's thread, rather than on the control
        // thread: what stage 3 is measuring is the delay the app's thumb sees,
        // and the hop to the control thread is part of it.
        plan.published_at = Some(Instant::now());
        match handle.engine.publish(plan, When::from_code(when)) {
            Ok(()) => JE_OK,
            Err(error) => {
                set_error(format!("junglengine: {error}"));
                JE_ERR_ENGINE
            }
        }
    })
}

/// Which publication [`je_engine_set_spec`] last made. The transport reports
/// the id of the plan the playhead it is showing belongs to, which during a
/// queued Beat swap is the previous one.
///
/// # Safety
/// `handle` must come from [`je_engine_new`].
#[no_mangle]
pub unsafe extern "C" fn je_engine_last_plan_id(handle: *const EngineHandle) -> u64 {
    match unsafe { handle.as_ref() } {
        Some(handle) => handle.engine.last_plan_id(),
        None => 0,
    }
}

/// Frames in one pass of `json`'s pattern. Export multiplies this by the
/// number of bars asked for. Negative on a spec that will not parse.
///
/// # Safety
/// `json` must point to `len` bytes of UTF-8.
#[no_mangle]
pub unsafe extern "C" fn je_engine_loop_frames(json: *const u8, len: i64) -> i64 {
    guard(JE_ERR_PANIC as i64, || {
        let spec = match unsafe { read_spec(json, len) } {
            Ok(spec) => spec,
            Err(code) => return code as i64,
        };
        Timeline::new(&spec).loop_frames()
    })
}

/// Renders `json` faster than real time into `out`, which must hold
/// `frame_count * 2` floats.
///
/// This is what makes WAV export go through the engine rather than around it:
/// the same mixer, the same voices, the same tail fold, so an exported file is
/// what was playing.
///
/// # Safety
/// `json` must point to `len` bytes of UTF-8 and `out` to `frame_count * 2`
/// writable floats.
#[no_mangle]
pub unsafe extern "C" fn je_engine_render_offline(
    handle: *mut EngineHandle,
    json: *const u8,
    len: i64,
    frame_count: i64,
    out: *mut f32,
) -> i32 {
    guard(JE_ERR_PANIC, || {
        let Some(handle) = (unsafe { handle.as_mut() }) else {
            set_error("junglengine: null engine");
            return JE_ERR_NULL;
        };
        if out.is_null() || frame_count <= 0 {
            set_error("junglengine: nothing to render into");
            return JE_ERR_NULL;
        }
        let spec = match unsafe { read_spec(json, len) } {
            Ok(spec) => spec,
            Err(code) => return code,
        };
        let frame_count = frame_count as usize;
        let plan = Plan::new(0, spec, handle.sources());
        let rendered = render_offline(plan, frame_count);
        let target = unsafe { std::slice::from_raw_parts_mut(out, frame_count * 2) };
        target.copy_from_slice(&rendered);
        JE_OK
    })
}

/// Plays an arbitrary clip immediately, replacing whatever the previous call
/// started. Interleaved stereo at the engine rate, copied on the way in.
///
/// This is how the import screen lets you hear a trim before committing to it,
/// so it takes samples rather than an index: what is being auditioned is not
/// in the project yet.
///
/// # Safety
/// `samples` must point to `frames * 2` floats.
#[no_mangle]
pub unsafe extern "C" fn je_engine_audition_clip(
    handle: *mut EngineHandle,
    samples: *const f32,
    frames: i64,
    looping: i32,
) -> i32 {
    guard(JE_ERR_PANIC, || {
        let Some(handle) = (unsafe { handle.as_mut() }) else {
            set_error("junglengine: null engine");
            return JE_ERR_NULL;
        };
        let clip = unsafe { read_clip(samples, frames) };
        send(
            handle,
            Command::AuditionClip {
                clip,
                looping: looping != 0,
            },
        )
    })
}

macro_rules! simple_command {
    ($name:ident, $doc:expr, $command:expr) => {
        #[doc = $doc]
        ///
        /// # Safety
        /// `handle` must come from [`je_engine_new`].
        #[no_mangle]
        pub unsafe extern "C" fn $name(handle: *mut EngineHandle) -> i32 {
            guard(JE_ERR_PANIC, || {
                let Some(handle) = (unsafe { handle.as_mut() }) else {
                    set_error("junglengine: null engine");
                    return JE_ERR_NULL;
                };
                send(handle, $command)
            })
        }
    };
}

simple_command!(
    je_engine_start,
    "Rewinds and runs the sequencer.",
    Command::Start
);
simple_command!(
    je_engine_stop,
    "Stops the sequencer and rewinds. The device stays open, so a tapped pad still sounds at once.",
    Command::Stop
);
simple_command!(
    je_engine_cancel_queued_spec,
    "Drops whatever a next-bar publication queued, leaving what is playing alone.",
    Command::CancelQueued
);
simple_command!(
    je_engine_stop_audition_clip,
    "Stops whatever `je_engine_audition_clip` started. Never affects the transport.",
    Command::StopAuditionClip
);

/// Gives the output device back, and stops the transport with it.
///
/// What the phone asks for when a call arrives, when another app takes the
/// output, or when the app goes to the background: holding a device open there
/// is a battery cost with nothing listening at the end of it. Everything else
/// is kept -- the loaded plan, the cached break and kit -- so
/// [`je_engine_resume`] carries on rather than reloads.
///
/// Idempotent. Suspending a suspended engine is a no-op, not an error.
///
/// # Safety
/// `handle` must come from [`je_engine_new`].
#[no_mangle]
pub unsafe extern "C" fn je_engine_suspend(handle: *mut EngineHandle) -> i32 {
    guard(JE_ERR_PANIC, || {
        let Some(handle) = (unsafe { handle.as_mut() }) else {
            set_error("junglengine: null engine");
            return JE_ERR_NULL;
        };
        match handle.engine.suspend() {
            Ok(()) => JE_OK,
            Err(error) => {
                set_error(format!("junglengine: {error}"));
                JE_ERR_ENGINE
            }
        }
    })
}

/// Takes the output device again, and returns the rate it opened at this time.
/// Negative on a device that will not open, with the reason on
/// [`je_last_error`]; the caller tries again the next time the platform says
/// the output is available.
///
/// The rate is returned rather than assumed because a phone can come back on a
/// different route than it went away on. When it has moved, everything the app
/// decoded is at the wrong rate: it resamples and republishes, and the
/// transport stays stopped until it does.
///
/// # Safety
/// `handle` must come from [`je_engine_new`].
#[no_mangle]
pub unsafe extern "C" fn je_engine_resume(handle: *mut EngineHandle) -> i32 {
    guard(JE_ERR_PANIC, || {
        let Some(handle) = (unsafe { handle.as_mut() }) else {
            set_error("junglengine: null engine");
            return JE_ERR_NULL;
        };
        match handle.engine.resume() {
            Ok(rate) => rate as i32,
            Err(error) => {
                set_error(format!("junglengine: {error}"));
                JE_ERR_ENGINE
            }
        }
    })
}

/// Plays one slice of the current break immediately, for tap feedback. Never
/// affects the transport.
///
/// # Safety
/// `handle` must come from [`je_engine_new`].
#[no_mangle]
pub unsafe extern "C" fn je_engine_audition_slice(
    handle: *mut EngineHandle,
    slice: i32,
) -> i32 {
    guard(JE_ERR_PANIC, || {
        let Some(handle) = (unsafe { handle.as_mut() }) else {
            set_error("junglengine: null engine");
            return JE_ERR_NULL;
        };
        send(handle, Command::AuditionSlice(slice))
    })
}

/// Plays one Kit slot immediately, at that slot's own volume and pitch, for
/// tap feedback. Never affects the transport.
///
/// `velocity` is the level the tap wrote, in the spec's own encoding: 1 soft,
/// 2 medium, 3 hard. Anything else is a pad tap, which has no velocity on it
/// and sounds at full.
///
/// # Safety
/// `handle` must come from [`je_engine_new`].
#[no_mangle]
pub unsafe extern "C" fn je_engine_audition_kit_slot(
    handle: *mut EngineHandle,
    slot: i32,
    velocity: i32,
) -> i32 {
    guard(JE_ERR_PANIC, || {
        let Some(handle) = (unsafe { handle.as_mut() }) else {
            set_error("junglengine: null engine");
            return JE_ERR_NULL;
        };
        send(handle, Command::AuditionKitSlot { slot, velocity })
    })
}

fn send(handle: &EngineHandle, command: Command) -> i32 {
    match handle.engine.command(command) {
        Ok(()) => JE_OK,
        Err(error) => {
            set_error(format!("junglengine: {error}"));
            JE_ERR_ENGINE
        }
    }
}

/// # Safety
/// `json` must point to `len` bytes of UTF-8.
unsafe fn read_spec(json: *const u8, len: i64) -> Result<Spec, i32> {
    if json.is_null() || len <= 0 {
        set_error("junglengine: empty spec");
        return Err(JE_ERR_SPEC);
    }
    let bytes = unsafe { std::slice::from_raw_parts(json, len as usize) };
    let text = match std::str::from_utf8(bytes) {
        Ok(text) => text,
        Err(error) => {
            set_error(format!("junglengine: spec is not UTF-8: {error}"));
            return Err(JE_ERR_SPEC);
        }
    };
    Spec::from_json_str(text).map_err(|error| {
        set_error(format!("junglengine: {error}"));
        JE_ERR_SPEC
    })
}

/// # Safety
/// `samples` must point to `frames * 2` floats, or be null for silence.
unsafe fn read_clip(samples: *const f32, frames: i64) -> Clip {
    if samples.is_null() || frames <= 0 {
        return Clip::silent(2);
    }
    let source = unsafe { std::slice::from_raw_parts(samples, frames as usize * 2) };
    Clip::new(source.to_vec())
}
