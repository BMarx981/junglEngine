//! The playhead, shared with the Dart side without a function call.
//!
//! The audio callback writes this struct at the end of every block; Dart maps
//! the pointer once and reads the fields straight out of it on the frame
//! callback it was already scheduling. No FFI call per frame, and no round
//! trip to a control thread that would only be reporting an estimate anyway.
//!
//! This is the accuracy the whole stage is about. The flutter_soloud engine
//! reads its playhead back from block markers against the frames the device
//! says it has consumed, because the mixer runs a quarter of a second ahead of
//! the speaker. Here the mixer *is* the speaker's callback, so the position
//! below is the frame that is sounding rather than a guess at it.

use std::sync::atomic::{AtomicI32, AtomicU32, AtomicU64, Ordering};

use crate::renderer::RenderPosition;

/// The output is open and the callback is running.
pub const DEVICE_OPEN: u32 = 0;

/// The device was handed back on purpose: an interruption, or the app going to
/// the background. Nothing is wrong and a resume will take it again.
pub const DEVICE_SUSPENDED: u32 = 1;

/// The stream failed underneath us. The control thread closes what is left of
/// it and waits to be told to try again, because on a phone the reason is
/// usually something that has to finish first -- a call, a route change -- and
/// reopening in a loop would only fail in a loop.
pub const DEVICE_LOST: u32 = 2;

/// The layout Dart maps. `#[repr(C)]` and the field order below are the wire
/// format: `JeTransport` in `packages/junglengine_engine/lib/src/bindings.dart`
/// mirrors it field for field. The 64 bit fields come first so neither side
/// has to reason about padding.
#[repr(C)]
pub struct TransportShared {
    /// Which publication the position below belongs to. During a queued Beat
    /// swap that is not the newest spec Dart sent, which is exactly why it is
    /// reported: Dart turns [`TransportShared::section`] into a Beat id
    /// against *this* plan, not against whatever it published last.
    pub plan_id: AtomicU64,

    /// Frames the callback has produced since the stream opened. Monotonic.
    pub frame: AtomicU64,

    /// Position through the current pass, 0..1, as `f64::to_bits`.
    pub position_bits: AtomicU64,

    /// Edits that have become audible. Bumped by the callback the moment a
    /// published plan first renders a sample, so the Dart side can tell one
    /// measurement from the next without a call.
    pub edit_seq: AtomicU64,

    /// Microseconds between the edit being published and the callback that
    /// first rendered it, which is stage 3's whole question. Read with
    /// [`edit_seq`] either side of it.
    ///
    /// [`edit_seq`]: TransportShared::edit_seq
    pub edit_latency_micros: AtomicU64,

    /// Bumped to odd before a write and back to even after it, so a reader
    /// that sees the same even value either side of its read knows the fields
    /// between did not move underneath it. One writer, so this is the cheap
    /// half of a seqlock: the callback never waits.
    pub version: AtomicU32,

    pub playing: AtomicU32,

    /// Step within the Beat that is sounding, not within the arrangement.
    pub step: AtomicI32,
    pub step_count: AtomicI32,

    /// Which Song card is sounding, or -1 outside song playback.
    pub entry_index: AtomicI32,

    /// Which section of the plan is sounding. A Beat id is a string, and the
    /// callback may not touch one, so the index crosses instead.
    pub section: AtomicI32,

    /// What the output device is doing: [`DEVICE_OPEN`], [`DEVICE_SUSPENDED`]
    /// or [`DEVICE_LOST`].
    ///
    /// Deliberately outside the seqlock above, because it is the one field
    /// here the audio callback does not write. The control thread sets it when
    /// it opens or closes the device, and cpal's error callback sets it to
    /// [`DEVICE_LOST`] when the stream fails underneath us -- a phone call, a
    /// route change, media services restarting. Dart reads it off the same
    /// mapped pointer as the playhead, which is what lets it notice a device
    /// that went away without polling the engine for it. See docs/M4.md.
    pub device_state: AtomicU32,
}

impl Default for TransportShared {
    fn default() -> Self {
        TransportShared {
            plan_id: AtomicU64::new(0),
            frame: AtomicU64::new(0),
            position_bits: AtomicU64::new(0),
            edit_seq: AtomicU64::new(0),
            edit_latency_micros: AtomicU64::new(0),
            version: AtomicU32::new(0),
            playing: AtomicU32::new(0),
            step: AtomicI32::new(0),
            step_count: AtomicI32::new(16),
            entry_index: AtomicI32::new(-1),
            section: AtomicI32::new(0),
            device_state: AtomicU32::new(DEVICE_OPEN),
        }
    }
}

impl TransportShared {
    /// Publishes one block's worth of playhead. Called by the audio callback
    /// and by nothing else.
    pub fn publish(
        &self,
        plan_id: u64,
        frame: u64,
        playing: bool,
        section: i32,
        at: RenderPosition,
    ) {
        let version = self.version.load(Ordering::Relaxed);
        self.version.store(version.wrapping_add(1), Ordering::Relaxed);
        // Release/Acquire around the body: the reader that sees the closing
        // even version must also see every field written before it.
        std::sync::atomic::fence(Ordering::Release);

        self.plan_id.store(plan_id, Ordering::Relaxed);
        self.frame.store(frame, Ordering::Relaxed);
        self.position_bits
            .store(at.position.to_bits(), Ordering::Relaxed);
        self.playing.store(u32::from(playing), Ordering::Relaxed);
        self.step.store(at.step, Ordering::Relaxed);
        self.step_count.store(at.step_count, Ordering::Relaxed);
        self.entry_index.store(at.entry_index, Ordering::Relaxed);
        self.section.store(section, Ordering::Relaxed);

        std::sync::atomic::fence(Ordering::Release);
        self.version.store(version.wrapping_add(2), Ordering::Relaxed);
    }

    /// Records one edit-to-audible measurement: the time between a plan being
    /// published and the block that first sounds it.
    ///
    /// Its own tiny seqlock rather than a field of [`TransportShared::publish`],
    /// because an edit happens when a thumb moves and a publication happens
    /// every block: pairing them would mean either republishing a stale
    /// measurement sixty times a second or losing one that landed between
    /// blocks. Latency first, then the counter, so a reader that sees a new
    /// count is looking at the measurement that belongs to it.
    ///
    /// The clock stops at the callback, which is where the engine's knowledge
    /// stops: what the device does with the block afterwards is a buffer
    /// neither engine can see, and it is what the camera in stage 3 is for.
    pub fn note_edit(&self, latency_micros: u64) {
        self.edit_latency_micros
            .store(latency_micros, Ordering::Relaxed);
        std::sync::atomic::fence(Ordering::Release);
        self.edit_seq.fetch_add(1, Ordering::Relaxed);
    }

    /// Marks the transport stopped without disturbing the position, so the
    /// grid keeps drawing the step the playhead came to rest on.
    pub fn set_playing(&self, playing: bool) {
        let version = self.version.load(Ordering::Relaxed);
        self.version.store(version.wrapping_add(1), Ordering::Relaxed);
        std::sync::atomic::fence(Ordering::Release);
        self.playing.store(u32::from(playing), Ordering::Relaxed);
        std::sync::atomic::fence(Ordering::Release);
        self.version.store(version.wrapping_add(2), Ordering::Relaxed);
    }

    /// Says what the device is doing. Called by the control thread, and by
    /// cpal's error callback with [`DEVICE_LOST`]: a relaxed store, which is
    /// all an error callback is allowed to do and all this needs.
    pub fn set_device_state(&self, state: u32) {
        self.device_state.store(state, Ordering::Relaxed);
    }

    pub fn device_state(&self) -> u32 {
        self.device_state.load(Ordering::Relaxed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Dart maps this struct by offset. If the layout moves, the playhead
    /// starts reading the wrong field, which looks like a bug in the
    /// sequencer rather than in the wire format.
    #[test]
    fn the_shared_layout_is_what_dart_maps() {
        // Five u64s, then six u32s, tail padded to the 8 byte alignment the
        // u64s ask for.
        assert_eq!(std::mem::size_of::<TransportShared>(), 72);
        assert_eq!(std::mem::align_of::<TransportShared>(), 8);
    }

    /// The device state is not under the seqlock, and must not be: the thread
    /// that says the stream has failed is not the thread writing the playhead.
    #[test]
    fn a_device_state_change_leaves_the_playhead_alone() {
        let shared = TransportShared::default();
        assert_eq!(shared.device_state(), DEVICE_OPEN);

        shared.publish(
            3,
            512,
            true,
            0,
            RenderPosition {
                step: 5,
                step_count: 16,
                entry_index: -1,
                position: 0.5,
            },
        );
        let version = shared.version.load(Ordering::Relaxed);

        shared.set_device_state(DEVICE_LOST);
        assert_eq!(shared.device_state(), DEVICE_LOST);
        assert_eq!(shared.version.load(Ordering::Relaxed), version);
        assert_eq!(shared.step.load(Ordering::Relaxed), 5);
    }

    #[test]
    fn an_edit_measurement_arrives_with_its_own_count() {
        let shared = TransportShared::default();
        assert_eq!(shared.edit_seq.load(Ordering::Relaxed), 0);

        shared.note_edit(512);
        assert_eq!(shared.edit_seq.load(Ordering::Relaxed), 1);
        assert_eq!(shared.edit_latency_micros.load(Ordering::Relaxed), 512);

        shared.note_edit(1024);
        assert_eq!(shared.edit_seq.load(Ordering::Relaxed), 2);
        assert_eq!(shared.edit_latency_micros.load(Ordering::Relaxed), 1024);
    }

    #[test]
    fn a_publish_leaves_the_version_even() {
        let shared = TransportShared::default();
        shared.publish(
            7,
            1024,
            true,
            1,
            RenderPosition {
                step: 3,
                step_count: 16,
                entry_index: 2,
                position: 0.25,
            },
        );
        assert_eq!(shared.version.load(Ordering::Relaxed) % 2, 0);
        assert_eq!(shared.plan_id.load(Ordering::Relaxed), 7);
        assert_eq!(shared.step.load(Ordering::Relaxed), 3);
        assert_eq!(shared.entry_index.load(Ordering::Relaxed), 2);
        assert_eq!(shared.section.load(Ordering::Relaxed), 1);
        assert_eq!(
            f64::from_bits(shared.position_bits.load(Ordering::Relaxed)),
            0.25
        );
    }
}
