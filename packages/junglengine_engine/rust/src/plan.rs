//! What the control thread hands the audio thread.
//!
//! A [`Plan`] is everything the mixer needs to render: the pattern data, the
//! audio it reads, and every step boundary already worked out. All of it is
//! built on the control thread, published whole, and returned whole to be
//! dropped there. The audio callback never builds one and never drops one,
//! because both would mean allocating inside the callback.
//!
//! This is the shape of `lira_graph::plan`, scaled to an app whose entire
//! graph is four slice voices, sixteen kit voices and one sub.

use std::sync::Arc;

use crate::spec::{Spec, STEPS_PER_BAR};

/// Decoded audio, interleaved stereo, already at the engine's rate.
///
/// Held behind an `Arc` so a voice can keep the buffer it is reading alive
/// across a plan swap, exactly as the Dart renderer relies on the GC to.
#[derive(Clone)]
pub struct Clip {
    pub samples: Arc<Vec<f32>>,
}

impl Clip {
    pub fn new(samples: Vec<f32>) -> Self {
        Clip {
            samples: Arc::new(samples),
        }
    }

    pub fn silent(frames: usize) -> Self {
        Clip::new(vec![0.0; frames * 2])
    }

    pub fn frames(&self) -> usize {
        self.samples.len() / 2
    }
}

/// Everything the renderer needs that is not pattern data: the audio itself.
#[derive(Clone)]
pub struct Sources {
    pub break_clip: Clip,
    /// One clip per Kit slot, in slot order. Empty until the project kit has
    /// loaded, which only silences Kit Beats.
    pub kit_clips: Vec<Clip>,
}

impl Sources {
    pub fn new(break_clip: Clip, kit_clips: Vec<Clip>) -> Self {
        Sources {
            break_clip,
            kit_clips,
        }
    }
}

/// Where every step of one [`Spec`] starts, in frames.
///
/// A port of `RenderTimeline` in `lib/audio/pattern_renderer.dart`, with one
/// difference that is the whole point of this stage: it is built here, on the
/// control thread, rather than inside the renderer. Every `Vec` below is
/// allocated before the plan is published, so swapping a plan in is three
/// pointer moves.
pub struct Timeline {
    /// Frame each step starts on, plus one past the end. Rounded from an exact
    /// running position, so rounding cannot accumulate into drift, and
    /// carrying each Beat's swing in the offsets of its odd steps.
    boundaries: Vec<i64>,
    section_of_step: Vec<usize>,
    section_start_step: Vec<usize>,
    frames_per_step: f64,
}

impl Timeline {
    pub fn new(spec: &Spec) -> Timeline {
        let fps = spec.sample_rate as f64 * 60.0 / spec.bpm / 4.0;

        let steps: usize = spec.sections.iter().map(|s| s.beat.step_count()).sum();
        let mut boundaries = Vec::with_capacity(steps + 1);
        let mut section_of_step = Vec::with_capacity(steps);
        let mut section_start_step = Vec::with_capacity(spec.sections.len());
        let mut frame = 0.0f64;

        for (section, entry) in spec.sections.iter().enumerate() {
            let beat = &entry.beat;
            section_start_step.push(section_of_step.len());
            // Swing pushes the odd sixteenths late and leaves the even ones
            // where they were, so the bar still starts and ends where it
            // should however hard the pattern is shuffled.
            let offset = beat.swing_offset_fraction() * fps;
            for local in 0..beat.step_count() {
                let swung = if local % 2 == 1 { offset } else { 0.0 };
                boundaries.push((frame + local as f64 * fps + swung).round() as i64);
                section_of_step.push(section);
            }
            frame += beat.step_count() as f64 * fps;
        }
        boundaries.push(frame.round() as i64);

        Timeline {
            boundaries,
            section_of_step,
            section_start_step,
            frames_per_step: fps,
        }
    }

    /// Steps in the whole timeline: one bar for a one bar pattern, the entire
    /// arrangement in song mode.
    pub fn step_count(&self) -> usize {
        self.section_of_step.len()
    }

    /// Frames in one pass of the timeline.
    pub fn loop_frames(&self) -> i64 {
        *self.boundaries.last().unwrap_or(&0)
    }

    /// How many frames one step lasts at this tempo, before swing.
    pub fn frames_per_step(&self) -> f64 {
        self.frames_per_step
    }

    pub fn start_frame_of(&self, step: usize) -> i64 {
        self.boundaries[step]
    }

    pub fn step_length(&self, step: usize) -> i64 {
        self.boundaries[step + 1] - self.boundaries[step]
    }

    pub fn section_of(&self, step: usize) -> usize {
        self.section_of_step[step]
    }

    pub fn section_start(&self, section: usize) -> usize {
        self.section_start_step[section]
    }

    /// Whether `step` is the first step of a bar. Every Beat is a whole number
    /// of bars, so this is also true of the top of the timeline.
    pub fn is_bar_line(&self, step: usize) -> bool {
        step.is_multiple_of(STEPS_PER_BAR)
    }

    pub fn step_at_frame(&self, frame: i64) -> usize {
        let mut low = 0usize;
        let mut high = self.step_count() - 1;
        while low < high {
            let mid = (low + high + 1) >> 1;
            if self.boundaries[mid] <= frame {
                low = mid;
            } else {
                high = mid - 1;
            }
        }
        low
    }
}

/// One publication: what to play, what to play it from, and where every step
/// falls.
///
/// Carried between the threads in a `Box`, so handing one over moves a pointer
/// rather than a few hundred bytes of `Spec`.
pub struct Plan {
    /// Which publication this is. Stamped into the shared transport by the
    /// callback so the Dart side can tell which spec the playhead it is
    /// reading belongs to -- during a queued Beat swap that is not the newest
    /// spec it sent.
    pub id: u64,
    pub spec: Spec,
    pub sources: Sources,
    pub timeline: Timeline,
}

impl Plan {
    pub fn new(id: u64, spec: Spec, sources: Sources) -> Box<Plan> {
        let timeline = Timeline::new(&spec);
        Box::new(Plan {
            id,
            spec,
            sources,
            timeline,
        })
    }
}
