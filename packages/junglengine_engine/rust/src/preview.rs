//! The audition voice: what a tap on a cell, a pad or a trim handle sounds.
//!
//! The flutter_soloud engine keeps one `AudioSource` per slice and per Kit
//! slot, re-cut and re-encoded as WAV every time the division or the break
//! changes, purely so that a tap does not wait on the render queue. None of
//! that is needed once the mixer is the callback: the audio is already here,
//! and a tap is one voice reading a range of it.
//!
//! One at a time, deliberately. This is tap feedback, not a pad instrument.

use crate::plan::Clip;
use crate::sub_voice::soft_clip;

pub struct PreviewVoice {
    clip: Option<Clip>,
    active: bool,
    looping: bool,
    /// Read head, in frames of [`PreviewVoice::clip`].
    position: f64,
    start: f64,
    end: f64,
    rate: f64,
    gain: f64,
    /// Output frames played since this hit started, for the attack ramp.
    played: f64,
    attack_frames: f64,
    fade_frames: f64,
}

impl PreviewVoice {
    pub fn new(sample_rate: u32) -> PreviewVoice {
        let rate = sample_rate as f64;
        PreviewVoice {
            clip: None,
            active: false,
            looping: false,
            position: 0.0,
            start: 0.0,
            end: 0.0,
            rate: 1.0,
            gain: 1.0,
            played: 0.0,
            // The same ramps the mixer puts on a slice, for the same reason: a
            // slice boundary lands wherever the equal division put it, which
            // is regularly mid waveform, and an unramped start there clicks.
            attack_frames: (rate * 0.0004).round().max(1.0),
            fade_frames: (rate * 0.0015).round().max(1.0),
        }
    }

    pub fn is_active(&self) -> bool {
        self.active
    }

    /// Starts reading `clip` between `start` and `end`, replacing whatever was
    /// sounding. Returns the clip it displaced, for the caller to hand back to
    /// the control thread: dropping it here could deallocate.
    #[must_use = "the displaced clip must be dropped on the control thread"]
    pub fn play(
        &mut self,
        clip: Clip,
        start: usize,
        end: usize,
        rate: f64,
        gain: f64,
        looping: bool,
    ) -> Option<Clip> {
        let frames = clip.frames();
        let end = end.min(frames);
        if end <= start + 1 {
            return Some(clip);
        }
        let previous = self.clip.replace(clip);
        self.start = start as f64;
        self.end = end as f64;
        self.position = start as f64;
        self.rate = rate.max(0.0001);
        self.gain = gain;
        self.looping = looping;
        self.played = 0.0;
        self.active = true;
        previous
    }

    /// Silences the voice and gives its clip up. Never called on a path that
    /// could drop it here.
    #[must_use = "the released clip must be dropped on the control thread"]
    pub fn stop(&mut self) -> Option<Clip> {
        self.active = false;
        self.looping = false;
        self.clip.take()
    }

    /// Mixes `count` frames into `out`, starting at frame `at_frame`. Adds,
    /// because the pattern is already there.
    pub fn mix(&mut self, out: &mut [f32], at_frame: usize, count: usize) {
        if !self.active {
            return;
        }
        let Some(clip) = self.clip.as_ref() else {
            self.active = false;
            return;
        };
        let samples = &clip.samples;

        for i in 0..count {
            if self.position + 1.0 >= self.end {
                if !self.looping {
                    self.active = false;
                    return;
                }
                self.position = self.start;
                self.played = 0.0;
            }

            let mut g = self.gain;
            if self.played < self.attack_frames {
                g *= self.played / self.attack_frames;
            }
            let until = (self.end - self.position) / self.rate;
            if until < self.fade_frames {
                g *= until / self.fade_frames;
            }

            let index = self.position.floor() as usize;
            let t = self.position - index as f64;
            let a = index * 2;
            let l = samples[a] as f64 + (samples[a + 2] as f64 - samples[a] as f64) * t;
            let r = samples[a + 1] as f64 + (samples[a + 3] as f64 - samples[a + 1] as f64) * t;

            let o = (at_frame + i) * 2;
            // Soft clipped rather than clamped: an audition landing on top of a
            // loud bar is the one place in the engine where two full scale
            // things sum, and the master saturation the pattern already went
            // through is the right curve to catch it with.
            out[o] = soft_clip(out[o] as f64 + l * g) as f32;
            out[o + 1] = soft_clip(out[o + 1] as f64 + r * g) as f32;

            self.position += self.rate;
            self.played += 1.0;
        }
    }
}
