//! What the audio callback owns.
//!
//! Everything below runs inside the device callback. The rules that follow
//! from that, and that the rest of the crate exists to make keepable:
//!
//! - no allocation. Plans arrive built.
//! - no deallocation. Plans and clips leave whole, through the trash ring.
//! - no locks. Both directions are lock free SPSC rings.
//! - no blocking. Every ring operation is try-and-move-on.
//!
//! This is `lira_graph::render::RenderState`, scaled down to one stereo
//! output, four slice voices, sixteen kit voices, one sub and one audition.

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

use rtrb::{Consumer, Producer};

use crate::command::{Command, Publication, Retired, When};
use crate::preview::PreviewVoice;
use crate::renderer::PatternRenderer;
use crate::spec::KIT_SLOT_COUNT;
use crate::transport::TransportShared;

/// Volume a tapped slice sounds at, matching what the flutter_soloud engine
/// plays an audition source at.
const SLICE_AUDITION_GAIN: f64 = 0.92;

/// And the same for an imported clip being previewed on the trim screen.
const CLIP_AUDITION_GAIN: f64 = 0.92;

pub struct AudioSide {
    renderer: PatternRenderer,
    preview: PreviewVoice,

    commands: Consumer<Command>,
    plans: Consumer<Publication>,
    trash: Producer<Retired>,

    transport: Arc<TransportShared>,

    /// Frames the callback has produced since the stream opened. Shared so the
    /// control thread can stamp the frame an edit was published on, which is
    /// the "edit" half of stage 3's edit-to-audible measurement.
    frame: Arc<AtomicU64>,

    playing: bool,
}

impl AudioSide {
    pub fn new(
        renderer: PatternRenderer,
        commands: Consumer<Command>,
        plans: Consumer<Publication>,
        trash: Producer<Retired>,
        transport: Arc<TransportShared>,
        frame: Arc<AtomicU64>,
        sample_rate: u32,
    ) -> AudioSide {
        AudioSide {
            renderer,
            preview: PreviewVoice::new(sample_rate),
            commands,
            plans,
            trash,
            transport,
            frame,
            playing: false,
        }
    }

    /// One device callback. `out` is interleaved stereo and is overwritten.
    pub fn process(&mut self, out: &mut [f32], frames: usize) {
        self.drain_commands();
        self.drain_plans();

        if self.playing {
            self.renderer.render(out, frames);
            // A queued Beat can have landed on a bar line inside that render.
            self.collect_retired();
        } else {
            out[..frames * 2].fill(0.0);
        }

        self.preview.mix(out, 0, frames);

        let frame = self.frame.fetch_add(frames as u64, Ordering::Relaxed) + frames as u64;
        self.publish(frame);
    }

    fn publish(&self, frame: u64) {
        if !self.playing {
            return;
        }
        let at_frame = self.renderer.loop_frame();
        self.transport.publish(
            self.renderer.plan_id(),
            frame,
            true,
            self.renderer.section_at(at_frame),
            self.renderer.position_at(at_frame),
        );
    }

    fn drain_commands(&mut self) {
        while let Ok(command) = self.commands.pop() {
            match command {
                Command::Start => {
                    // A rewind is a fresh start, so anything waiting for a bar
                    // line that is never going to arrive goes with it.
                    self.bin_queued();
                    self.renderer.rewind();
                    self.playing = true;
                }
                Command::Stop => {
                    self.bin_queued();
                    self.renderer.rewind();
                    self.playing = false;
                    self.transport.set_playing(false);
                }
                Command::CancelQueued => self.bin_queued(),
                Command::AuditionSlice(index) => self.audition_slice(index),
                Command::AuditionKitSlot(slot) => self.audition_kit_slot(slot),
                Command::AuditionClip { clip, looping } => {
                    let frames = clip.frames();
                    let displaced = self.preview.play(
                        clip,
                        0,
                        frames,
                        1.0,
                        CLIP_AUDITION_GAIN,
                        looping,
                    );
                    self.bin(displaced);
                }
                Command::StopAuditionClip => {
                    let released = self.preview.stop();
                    self.bin(released);
                }
            }
        }
    }

    fn drain_plans(&mut self) {
        while let Ok(publication) = self.plans.pop() {
            let Publication { plan, when } = publication;
            if when == When::NextBar && self.playing && self.renderer.can_queue(&plan) {
                // Nothing is torn down and nothing restarts: the swap happens
                // inside the render loop, on the bar line, so the bar that is
                // playing finishes.
                let displaced = self.renderer.queue_plan(plan);
                self.bin(displaced);
                continue;
            }
            let retired = if self.renderer.can_adopt(&plan) {
                // Swapped in under the running playhead, so painting a step,
                // nudging a repeat count or dragging the tempo never restarts
                // the bar or cuts a ringing slice.
                self.renderer.adopt(plan)
            } else {
                // A different Beat, a different machine or a different break:
                // what is sounding cannot survive the change, so playback
                // starts again from the top.
                self.bin_queued();
                self.renderer.install(plan)
            };
            self.bin(Some(retired));
        }
    }

    fn audition_slice(&mut self, index: i32) {
        let plan = self.renderer.pending_plan();
        let beat = plan.spec.beat();
        let count = beat.slice_count;
        if count <= 0 || index < 0 || index as i64 >= count {
            return;
        }
        let clip = plan.sources.break_clip.clone();
        let total = clip.frames() as i64;
        let start = (index as f64 * total as f64 / count as f64).round() as i64;
        let end = ((index as i64 + 1) as f64 * total as f64 / count as f64).round() as i64;
        let end = end.clamp(0, total);
        let displaced = self.preview.play(
            clip,
            start.max(0) as usize,
            end.max(0) as usize,
            1.0,
            SLICE_AUDITION_GAIN,
            false,
        );
        self.bin(displaced);
    }

    fn audition_kit_slot(&mut self, slot: i32) {
        if slot < 0 || slot as usize >= KIT_SLOT_COUNT {
            return;
        }
        let plan = self.renderer.pending_plan();
        let Some(clip) = plan.sources.kit_clips.get(slot as usize).cloned() else {
            return;
        };
        // A tapped pad sounds at the slot's own volume and pitch, and at full
        // velocity: the pad is not a step, so there is no velocity on it.
        let settings = plan.spec.beat().slot(slot as usize);
        let frames = clip.frames();
        let displaced =
            self.preview
                .play(clip, 0, frames, settings.rate(), settings.volume, false);
        self.bin(displaced);
    }

    fn bin_queued(&mut self) {
        let queued = self.renderer.take_queued();
        self.bin(queued);
    }

    fn collect_retired(&mut self) {
        let retired = self.renderer.take_retired();
        self.bin(retired);
    }

    /// Hands one thing back for the control thread to drop.
    ///
    /// A full trash ring would mean dropping here, so the ring is sized past
    /// every queue that feeds it and the control thread drains it on a tick as
    /// well as on every publication. If it ever did fill, leaking is still the
    /// better of the two answers: a dropout is audible and a few hundred
    /// kilobytes are not.
    fn bin<T: Into<Retired>>(&mut self, item: Option<T>) {
        if let Some(item) = item {
            if let Err(full) = self.trash.push(item.into()) {
                std::mem::forget(full);
            }
        }
    }
}
