//! Turns spec sections into interleaved stereo float samples.
//!
//! A port of `lib/audio/pattern_renderer.dart`. It is the only thing in the
//! engine that makes sound, and it stays the only one: playback pulls blocks
//! from it and so does export, because what you hear has to be what you export.
//!
//! Both machines render here, and so does the Song. Which machine a section
//! runs is a branch at step fire time, not a second renderer.
//!
//! Nothing here allocates and nothing here drops. That is the whole reason
//! this is in Rust: it runs inside the audio callback, where the Dart mixer
//! could only ever run ahead of one. Plans arrive built and leave whole, on
//! the [`PatternRenderer::take_retired`] path, to be dropped on the control
//! thread.

use std::sync::Arc;

use crate::plan::Plan;
use crate::spec::{midi_to_hz, KitSlot, KitVelocity, StepMod, SubStep, KIT_SLOT_COUNT};
use crate::sub_voice::{soft_clip, SubVoice};

const MAX_SLICE_VOICES: usize = 4;

/// Eight slots can fire on one step while the tails of the step before are
/// still ringing, so this is deliberately more than eight.
const MAX_KIT_VOICES: usize = 16;

/// Where the sequencer is, in terms the UI understands.
#[derive(Clone, Copy, Debug, Default)]
pub struct RenderPosition {
    /// Step within the Beat that is sounding, not within the arrangement.
    pub step: i32,
    pub step_count: i32,
    pub entry_index: i32,
    /// Position through the current pass, 0..1.
    pub position: f64,
}

pub struct PatternRenderer {
    /// What is playing, built and owned elsewhere. Never constructed here and
    /// never dropped here.
    plan: Box<Plan>,

    /// What takes over at the next bar line, if anything. See
    /// [`PatternRenderer::queue_plan`].
    queued: Option<Box<Plan>>,

    /// Where a plan retired inside [`PatternRenderer::render`] waits for the
    /// caller to collect it. One slot is enough: only a queued swap retires a
    /// plan from inside the render loop, only one plan can be queued at a
    /// time, and the caller drains this after every render.
    retired: Option<Box<Plan>>,

    sub: SubVoice,
    fade_frames: f64,
    attack_frames: f64,

    voices: [SliceVoice; MAX_SLICE_VOICES],
    kit_voices: [KitVoice; MAX_KIT_VOICES],

    step_index: usize,
    frames_to_next_step: i64,
    section_index: i64,
    tail: bool,
}

impl PatternRenderer {
    pub fn new(plan: Box<Plan>) -> Self {
        let sample_rate = plan.spec.sample_rate as f64;
        let mut renderer = PatternRenderer {
            sub: SubVoice::new(plan.spec.sample_rate),
            fade_frames: (sample_rate * 0.0015).round().max(1.0),
            attack_frames: (sample_rate * 0.0004).round().max(1.0),
            plan,
            queued: None,
            retired: None,
            voices: Default::default(),
            kit_voices: Default::default(),
            step_index: 0,
            frames_to_next_step: 0,
            section_index: -1,
            tail: false,
        };
        renderer.rewind();
        renderer
    }

    /// Which publication is sounding. The callback stamps this into the shared
    /// transport so the Dart side knows which spec the step it is drawing
    /// belongs to.
    pub fn plan_id(&self) -> u64 {
        self.plan.id
    }

    /// Steps in the whole timeline: one bar for a one bar pattern, the entire
    /// arrangement in song mode.
    pub fn step_count(&self) -> usize {
        self.plan.timeline.step_count()
    }

    /// Position within the timeline, in frames. Wraps with the loop.
    pub fn loop_frame(&self) -> i64 {
        self.plan.timeline.start_frame_of(self.step_index)
            + (self.step_length(self.step_index) - self.frames_to_next_step)
    }

    fn step_length(&self, step: usize) -> i64 {
        self.plan.timeline.step_length(step)
    }

    /// Whether `next` can be swapped in under the running playhead.
    ///
    /// The test is deliberately narrow: whatever is sounding right now has to
    /// still be sounding afterwards. Everything else about the timeline may
    /// change, which is what lets a card be added to a song, a repeat count be
    /// nudged or the tempo be dragged while the arrangement keeps playing.
    pub fn can_adopt(&self, next: &Plan) -> bool {
        if next.spec.sample_rate != self.plan.spec.sample_rate {
            return false;
        }
        if !Arc::ptr_eq(
            &next.sources.break_clip.samples,
            &self.plan.sources.break_clip.samples,
        ) {
            return false;
        }
        if next.spec.sections.is_empty() {
            return false;
        }
        let section = self.plan.timeline.section_of(self.step_index);
        if section >= next.spec.sections.len() {
            return false;
        }
        let playing = &self.plan.spec.sections[section].beat;
        let replacement = &next.spec.sections[section].beat;
        playing.id == replacement.id
            && playing.step_count() == replacement.step_count()
            && playing.is_kit == replacement.is_kit
    }

    /// Whether `next` could be queued to take over at a bar line.
    ///
    /// Much narrower than what [`PatternRenderer::can_adopt`] asks, because
    /// nothing has to survive a queued swap except the material the ringing
    /// voices are reading from: the pattern is allowed to change completely,
    /// that is the point of it.
    pub fn can_queue(&self, next: &Plan) -> bool {
        next.spec.sample_rate == self.plan.spec.sample_rate
            && Arc::ptr_eq(
                &next.sources.break_clip.samples,
                &self.plan.sources.break_clip.samples,
            )
            && !next.spec.sections.is_empty()
    }

    /// Swaps in edited data without disturbing the playhead or any voice that
    /// is ringing, so painting a step never interrupts the loop.
    ///
    /// Tempo, swing and the section list are all allowed to move here. Only
    /// [`PatternRenderer::can_adopt`] decides what is too much; anything it
    /// refuses needs [`PatternRenderer::install`] instead.
    ///
    /// Returns the plan that just stopped playing, for the caller to hand back
    /// to the control thread. Dropping it here would deallocate on the audio
    /// thread.
    #[must_use = "the retired plan must be dropped on the control thread"]
    pub fn adopt(&mut self, next: Box<Plan>) -> Box<Plan> {
        debug_assert!(
            self.can_adopt(&next),
            "adopt cannot change what is sounding; install a new plan instead"
        );
        let section = self.plan.timeline.section_of(self.step_index);
        let local = self.step_index - self.plan.timeline.section_start(section);
        let previous = self.step_length(self.step_index);

        let old = std::mem::replace(&mut self.plan, next);

        self.step_index = self.plan.timeline.section_start(section) + local;
        let now = self.step_length(self.step_index);
        if previous > 0 && now != previous {
            let scaled =
                (self.frames_to_next_step as f64 * now as f64 / previous as f64).round() as i64;
            self.frames_to_next_step = scaled.min(now).max(1);
        }
        self.section_index = section as i64;
        let patch = self.plan.spec.sections[self.plan.timeline.section_of(self.step_index)]
            .beat
            .sub_patch;
        self.sub.set_patch(patch);
        old
    }

    /// Replaces what is playing outright and starts again from the top, for a
    /// change [`PatternRenderer::can_adopt`] refuses: a different break, a
    /// different machine, a different sample rate.
    #[must_use = "the retired plan must be dropped on the control thread"]
    pub fn install(&mut self, next: Box<Plan>) -> Box<Plan> {
        let old = std::mem::replace(&mut self.plan, next);
        self.rewind();
        old
    }

    /// Lines `next` up to take over at the end of the bar being rendered.
    ///
    /// This is how a Beat is changed under a running transport: the swap lands
    /// on the bar line rather than the instant it was asked for, so choosing
    /// another Beat mid bar never chops the bar in half. It is deliberately
    /// not [`PatternRenderer::adopt`]'s job, which is the opposite promise: an
    /// edit is heard as soon as possible and never moves the playhead.
    ///
    /// Returns whatever was queued before, which nothing will now play.
    #[must_use = "the displaced plan must be dropped on the control thread"]
    pub fn queue_plan(&mut self, next: Box<Plan>) -> Option<Box<Plan>> {
        debug_assert!(
            self.can_queue(&next),
            "a queued plan must read the same clip at the same rate"
        );
        self.queued.replace(next)
    }

    pub fn has_queued(&self) -> bool {
        self.queued.is_some()
    }

    /// The plan an audition should read: whatever is queued, or what is
    /// playing when nothing is.
    ///
    /// A tap belongs to the Beat that is being switched *to*, not to the bar
    /// that is finishing. The Dart engine says the same thing by moving its
    /// current spec the moment a swap is queued, while the renderer keeps
    /// playing the old one.
    pub fn pending_plan(&self) -> &Plan {
        self.queued.as_deref().unwrap_or(&self.plan)
    }

    /// Drops the queued plan, leaving whatever is playing alone.
    #[must_use = "the cancelled plan must be dropped on the control thread"]
    pub fn take_queued(&mut self) -> Option<Box<Plan>> {
        self.queued.take()
    }

    /// Collects a plan that [`PatternRenderer::render`] retired at a bar line.
    /// Drained by the caller after every render, so the slot is always free by
    /// the time the next bar line comes round.
    #[must_use = "the retired plan must be dropped on the control thread"]
    pub fn take_retired(&mut self) -> Option<Box<Plan>> {
        self.retired.take()
    }

    /// Takes the queued plan over, at the bar line the render loop has just
    /// reached.
    ///
    /// The playhead goes to the top of the new timeline and every voice is
    /// left alone, so a slice or a one shot ringing across the join keeps
    /// ringing, exactly as it does when a song moves from one card to the next.
    fn adopt_queued(&mut self) {
        let next = self.queued.take().expect("checked by the caller");
        let old = std::mem::replace(&mut self.plan, next);
        self.step_index = 0;
        // -1 rather than 0, so the next fired step installs the new Beat's
        // patch.
        self.section_index = -1;
        debug_assert!(
            self.retired.is_none(),
            "the caller must drain the retired slot after every render"
        );
        self.retired = Some(old);
    }

    /// Returns to the top of the timeline and clears all voice state, so two
    /// renders from the same plan are sample identical.
    ///
    /// Anything waiting for a bar line is deliberately left alone: unlike the
    /// Dart renderer, which drops its queue here, this cannot drop. The caller
    /// takes the queue with [`PatternRenderer::take_queued`] first when a
    /// rewind should cancel it.
    pub fn rewind(&mut self) {
        self.step_index = 0;
        self.section_index = -1;
        self.tail = false;
        for v in self.voices.iter_mut() {
            v.active = false;
        }
        for v in self.kit_voices.iter_mut() {
            v.active = false;
            v.clip = None;
        }
        let patch = self.plan.spec.sections[0].beat.sub_patch;
        self.sub.set_patch(patch);
        self.sub.reset();
        self.frames_to_next_step = self.step_length(0);
        self.fire_step(0);
    }

    /// Renders `frame_count` frames of interleaved stereo into `out`, which
    /// must hold at least `frame_count * 2` floats. Overwritten, not mixed
    /// into.
    pub fn render(&mut self, out: &mut [f32], frame_count: usize) {
        out[..frame_count * 2].fill(0.0);
        let mut written = 0usize;
        while written < frame_count {
            let chunk = ((frame_count - written) as i64).min(self.frames_to_next_step);
            if chunk > 0 {
                self.render_chunk(out, written, chunk as usize);
                written += chunk as usize;
                self.frames_to_next_step -= chunk;
            }
            if self.frames_to_next_step <= 0 {
                let next = (self.step_index + 1) % self.step_count();
                // The one place a queued Beat can land: on a bar line, between
                // the last step of the bar and the first step of the next one.
                if self.queued.is_some() && self.plan.timeline.is_bar_line(next) {
                    self.adopt_queued();
                } else {
                    self.step_index = next;
                }
                self.frames_to_next_step = self.step_length(self.step_index);
                self.fire_step(self.step_index);
            }
        }
    }

    /// Resolves a frame of the timeline to something the UI can draw.
    pub fn position_at(&self, frame: i64) -> RenderPosition {
        let timeline = &self.plan.timeline;
        let total = timeline.loop_frames();
        let wrapped = if total <= 0 {
            0
        } else {
            frame.rem_euclid(total)
        };
        let step = timeline.step_at_frame(wrapped);
        let section = timeline.section_of(step);
        let start = timeline.section_start(section);
        let beat = &self.plan.spec.sections[section].beat;
        let pass_start = timeline.start_frame_of(start);
        let pass_frames = timeline.start_frame_of(start + beat.step_count()) - pass_start;
        RenderPosition {
            step: (step - start) as i32,
            step_count: beat.step_count() as i32,
            entry_index: self.plan.spec.sections[section].entry_index,
            position: if pass_frames <= 0 {
                0.0
            } else {
                (wrapped - pass_start) as f64 / pass_frames as f64
            },
        }
    }

    /// Which section is sounding at `frame`. Separate from
    /// [`PatternRenderer::position_at`] because a Beat id is a string the
    /// callback must not touch: the Dart side turns this index into an id
    /// against the spec it published.
    pub fn section_at(&self, frame: i64) -> i32 {
        let timeline = &self.plan.timeline;
        let total = timeline.loop_frames();
        let wrapped = if total <= 0 {
            0
        } else {
            frame.rem_euclid(total)
        };
        timeline.section_of(timeline.step_at_frame(wrapped)) as i32
    }

    fn render_chunk(&mut self, out: &mut [f32], at_frame: usize, count: usize) {
        let clip = &self.plan.sources.break_clip.samples;
        let clip_frames = self.plan.sources.break_clip.frames();
        let drum_gain = self.plan.spec.drum_gain;
        let sub_gain = self.plan.spec.sub_gain;
        let attack_frames = self.attack_frames;
        let fade_frames = self.fade_frames;

        for i in 0..count {
            let mut l = 0.0f64;
            let mut r = 0.0f64;

            for v in self.voices.iter_mut() {
                if !v.active {
                    continue;
                }
                if !v.advanceable(clip_frames) && !v.restart() {
                    v.active = false;
                    continue;
                }

                // Short ramps at both ends of a slice, and on a choke, so
                // rearranging mid transient does not click. Measured in output
                // frames, so a half speed slice ramps over the same amount of
                // time as a plain one.
                let mut g = v.gain;
                let since = v.played;
                let until = v.frames_until_end(clip_frames);
                if since < attack_frames {
                    g *= since / attack_frames;
                }
                if until < fade_frames {
                    g *= until / fade_frames;
                }

                let index = v.position.floor() as usize;
                let next = if index + 1 < clip_frames {
                    index + 1
                } else {
                    index
                };
                let t = v.position - index as f64;
                let a = index * 2;
                let b = next * 2;
                l += (clip[a] as f64 + (clip[b] as f64 - clip[a] as f64) * t) * g;
                r += (clip[a + 1] as f64 + (clip[b + 1] as f64 - clip[a + 1] as f64) * t) * g;

                v.advance();
                if v.fading {
                    v.gain -= v.fade_step;
                    if v.gain <= 0.0 {
                        v.active = false;
                    }
                }
            }

            for v in self.kit_voices.iter_mut() {
                if !v.active {
                    continue;
                }
                let index = v.position.floor() as usize;
                if index + 1 >= v.frames || v.clip.is_none() {
                    v.active = false;
                    v.clip = None;
                    continue;
                }
                // One shots are pitched by playback rate, so a slot tuned down
                // is also a slot that rings longer. Interpolated, because a
                // rate of 1.06 read without it is audibly grainy on a hat.
                let t = v.position - index as f64;
                let a = index * 2;
                let (a0, a1, b0, b1) = {
                    let s = v.clip.as_ref().expect("checked above");
                    (
                        s[a] as f64,
                        s[a + 1] as f64,
                        s[a + 2] as f64,
                        s[a + 3] as f64,
                    )
                };
                l += (a0 + (b0 - a0) * t) * v.gain;
                r += (a1 + (b1 - a1) * t) * v.gain;
                v.position += v.rate;
            }

            l *= drum_gain;
            r *= drum_gain;

            let sub = self.sub.next_sample() * sub_gain;
            l += sub;
            r += sub;

            let o = (at_frame + i) * 2;
            out[o] = soft_clip(l) as f32;
            out[o + 1] = soft_clip(r) as f32;
        }
    }

    /// Stops the sequencer but keeps rendering, so whatever is ringing can
    /// decay naturally. Used to capture the ring out at the end of an export.
    pub fn begin_tail(&mut self) {
        self.tail = true;
        self.sub.note_off();
    }

    fn fire_step(&mut self, step: usize) {
        if self.tail {
            return;
        }
        let section = self.plan.timeline.section_of(step);
        let local = step - self.plan.timeline.section_start(section);
        let step_frames = self.step_length(step);

        // Everything the step needs is copied out first, so nothing below
        // holds a borrow on the spec while the voices are touched. All of it
        // is `Copy`: no allocation happens on a step boundary.
        let (is_kit, slice_count, sub_patch, sub_root_midi) = {
            let beat = &self.plan.spec.sections[section].beat;
            (
                beat.is_kit,
                beat.slice_count,
                beat.sub_patch,
                beat.sub_root_midi,
            )
        };

        if section as i64 != self.section_index {
            // A song can run a different patch on the next card, and the patch
            // is per Beat. Nothing else about the voice is reset, so a note
            // ringing across the join keeps ringing.
            self.section_index = section as i64;
            self.sub.set_patch(sub_patch);
        }

        if is_kit {
            let mut fires: [Option<(KitVelocity, KitSlot)>; KIT_SLOT_COUNT] =
                [None; KIT_SLOT_COUNT];
            {
                let beat = &self.plan.spec.sections[section].beat;
                for (slot, fire) in fires.iter_mut().enumerate() {
                    if let Some(velocity) = beat.kit[slot][local] {
                        *fire = Some((velocity, beat.slot(slot)));
                    }
                }
            }
            for (slot, fire) in fires.iter().enumerate() {
                if let Some((velocity, settings)) = fire {
                    self.trigger_kit(slot, *velocity, *settings);
                }
            }
        } else {
            let cell = self.plan.spec.sections[section].beat.chop[local];
            if let Some(cell) = cell {
                self.trigger_slice(slice_count, cell.slice, cell.r#mod, step_frames);
            }
        }

        let cell: SubStep = self.plan.spec.sections[section].beat.sub[local];
        match cell.semitone {
            Some(semitone) => {
                let hz = midi_to_hz((sub_root_midi + semitone) as f64);
                self.sub.note_on(hz, cell.tie, cell.accent);
            }
            None if cell.tie => self.sub.hold(),
            None => self.sub.note_off(),
        }
    }

    fn trigger_slice(&mut self, slice_count: i64, index: i64, r#mod: StepMod, step_frames: i64) {
        let total = self.plan.sources.break_clip.frames() as i64;
        if slice_count <= 0 || index < 0 || index >= slice_count {
            return;
        }

        let start = (index as f64 * total as f64 / slice_count as f64).round() as i64;
        let end = ((index + 1) as f64 * total as f64 / slice_count as f64).round() as i64;
        let end = end.clamp(0, total);
        if end <= start {
            return;
        }

        // Monophonic grid: the new hit chokes whatever is ringing, but the old
        // voice is faded rather than cut dead.
        let fade_frames = self.fade_frames;
        for v in self.voices.iter_mut() {
            if v.active && !v.fading {
                v.fading = true;
                v.fade_step = v.gain / fade_frames;
            }
        }

        let reverse = r#mod.rate() < 0.0;
        let retriggers = r#mod.retriggers();
        let voice = free_voice(&mut self.voices);
        voice.active = true;
        voice.fading = false;
        voice.fade_step = 0.0;
        voice.gain = 1.0;
        voice.start_frame = start;
        voice.end_frame = end;
        voice.reverse = reverse;
        voice.rate = r#mod.rate().abs();
        // A retrigger is the head of the slice, fired again on each
        // subdivision of the step. Everything else plays once, all the way
        // through.
        voice.hit_frames = if retriggers > 1 {
            step_frames as f64 / retriggers as f64
        } else {
            0.0
        };
        voice.hits_left = retriggers - 1;
        voice.restart_head();
    }

    /// Fires one Kit slot. Nothing is choked: slots are independent by spec, so
    /// an open hat rings under the next closed hat exactly as it would on a
    /// machine with no choke groups.
    fn trigger_kit(&mut self, slot: usize, velocity: KitVelocity, settings: KitSlot) {
        let clip = match self.plan.sources.kit_clips.get(slot) {
            Some(clip) if clip.frames() >= 2 => clip.clone(),
            _ => return,
        };
        let frames = clip.frames();
        let voice = free_kit_voice(&mut self.kit_voices);
        voice.active = true;
        voice.frames = frames;
        voice.clip = Some(clip.samples);
        voice.position = 0.0;
        voice.rate = settings.rate();
        voice.gain = settings.volume * velocity.gain();
    }
}

/// Prefers an idle slot, otherwise steals the one closest to finishing.
fn free_voice(voices: &mut [SliceVoice; MAX_SLICE_VOICES]) -> &mut SliceVoice {
    let pick = voices
        .iter()
        .position(|v| !v.active)
        .unwrap_or_else(|| nearest_to_done(voices.iter().map(SliceVoice::remaining)));
    &mut voices[pick]
}

/// Same rule as the slice pool: steal from whatever has least left to play,
/// which is the voice you are least likely to hear disappear.
fn free_kit_voice(voices: &mut [KitVoice; MAX_KIT_VOICES]) -> &mut KitVoice {
    let pick = voices
        .iter()
        .position(|v| !v.active)
        .unwrap_or_else(|| nearest_to_done(voices.iter().map(KitVoice::remaining)));
    &mut voices[pick]
}

/// Index of the smallest value, first one winning a tie. An idle voice reports
/// -1, so it always wins.
fn nearest_to_done(remaining: impl Iterator<Item = f64>) -> usize {
    let mut pick = 0usize;
    let mut nearest = f64::INFINITY;
    for (i, left) in remaining.enumerate() {
        if left < nearest {
            nearest = left;
            pick = i;
        }
    }
    pick
}

/// A slice of the break, playing.
///
/// Reads at a rate and in a direction, which is what the step modifiers come
/// down to: reverse walks backwards, pitch down and half speed read slower, and
/// a retrigger is the same voice sent back to the head of the slice.
struct SliceVoice {
    active: bool,
    fading: bool,
    reverse: bool,
    start_frame: i64,
    end_frame: i64,
    position: f64,
    rate: f64,
    gain: f64,
    fade_step: f64,
    /// Output frames one retrigger hit lasts, or 0 when the slice plays once.
    hit_frames: f64,
    /// Retrigger hits still to come after this one.
    hits_left: i32,
    /// Output frames played since this hit started.
    played: f64,
}

impl Default for SliceVoice {
    fn default() -> Self {
        SliceVoice {
            active: false,
            fading: false,
            reverse: false,
            start_frame: 0,
            end_frame: 0,
            position: 0.0,
            rate: 1.0,
            gain: 1.0,
            fade_step: 0.0,
            hit_frames: 0.0,
            hits_left: 0,
            played: 0.0,
        }
    }
}

impl SliceVoice {
    /// Puts the read head at the top of the slice, which for a reversed voice
    /// is its last frame.
    fn restart_head(&mut self) {
        self.position = if self.reverse {
            (self.end_frame - 1) as f64
        } else {
            self.start_frame as f64
        };
        self.played = 0.0;
    }

    /// Output frames left before this hit ends, whichever comes first: the end
    /// of the slice or the end of the retrigger subdivision.
    fn frames_until_end(&self, clip_frames: usize) -> f64 {
        let limit = if self.reverse {
            self.position - self.start_frame as f64
        } else {
            self.end_frame.min(clip_frames as i64) as f64 - self.position
        };
        let to_slice_end = if self.rate <= 0.0 {
            limit
        } else {
            limit / self.rate
        };
        if self.hit_frames <= 0.0 {
            return to_slice_end;
        }
        to_slice_end.min(self.hit_frames - self.played)
    }

    fn advanceable(&self, clip_frames: usize) -> bool {
        if self.hit_frames > 0.0 && self.played >= self.hit_frames {
            return false;
        }
        if self.reverse {
            return self.position > self.start_frame as f64;
        }
        self.position < (self.end_frame - 1) as f64 && self.position < clip_frames as f64 - 1.0
    }

    /// Starts the next retrigger hit. False when there is none, which retires
    /// the voice.
    fn restart(&mut self) -> bool {
        if self.hits_left <= 0 {
            return false;
        }
        self.hits_left -= 1;
        self.restart_head();
        true
    }

    fn advance(&mut self) {
        self.position += if self.reverse { -self.rate } else { self.rate };
        self.played += 1.0;
    }

    /// Output frames of audio left in this voice, counting the hits still to
    /// come. -1 when idle, so an idle voice always wins voice stealing.
    fn remaining(&self) -> f64 {
        if !self.active {
            return -1.0;
        }
        let left = if self.reverse {
            self.position - self.start_frame as f64
        } else {
            self.end_frame as f64 - self.position
        };
        let base = if self.rate <= 0.0 {
            left
        } else {
            left / self.rate
        };
        base + self.hits_left as f64
            * if self.hit_frames > 0.0 {
                self.hit_frames
            } else {
                0.0
            }
    }
}

struct KitVoice {
    active: bool,
    /// Interleaved stereo samples of the slot's one shot, held directly so the
    /// inner loop never goes through a lookup.
    clip: Option<Arc<Vec<f32>>>,
    frames: usize,
    position: f64,
    rate: f64,
    gain: f64,
}

impl Default for KitVoice {
    fn default() -> Self {
        KitVoice {
            active: false,
            clip: None,
            frames: 0,
            position: 0.0,
            rate: 1.0,
            gain: 1.0,
        }
    }
}

impl KitVoice {
    /// Frames of audio left to play, at this voice's rate.
    fn remaining(&self) -> f64 {
        if self.active {
            (self.frames as f64 - self.position) / self.rate
        } else {
            -1.0
        }
    }
}
