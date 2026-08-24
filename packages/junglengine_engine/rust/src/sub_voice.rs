//! The whole sub synth: one monophonic voice.
//!
//! A direct port of `lib/audio/sub_voice.dart`, coefficient for coefficient.
//! Sine/triangle core, one lowpass, drive, amp envelope, glide. Five knobs. If
//! something wants a sixth, the answer is still no: see CLAUDE.md.

use crate::spec::SubPatch;

/// Chamberlin resonance, fixed.
const FILTER_Q: f64 = 0.85;

/// How much further open an accented note sits, in cutoff multiples.
const ACCENT_OPEN: f64 = 1.8;

/// The level an accented note is played at. The corner alone reads as duller,
/// not louder, so an accent is a corner and a few dB together.
const ACCENT_GAIN: f64 = 1.35;

const ATTACK_SECONDS: f64 = 0.004;

pub struct SubVoice {
    sample_rate: f64,
    patch: SubPatch,

    phase: f64,
    freq: f64,
    target_freq: f64,
    glide_coeff: f64,

    low: f64,
    band: f64,
    filter_f: f64,
    closed_f: f64,
    open_f: f64,
    accent: bool,

    env: f64,
    attack_step: f64,
    release_coeff: f64,
    gate: bool,

    drive_amount: f64,
    drive_makeup: f64,
}

impl SubVoice {
    pub fn new(sample_rate: u32) -> Self {
        let mut voice = SubVoice {
            sample_rate: sample_rate as f64,
            patch: SubPatch::default(),
            phase: 0.0,
            freq: 55.0,
            target_freq: 55.0,
            glide_coeff: 1.0,
            low: 0.0,
            band: 0.0,
            filter_f: 0.2,
            closed_f: 0.2,
            open_f: 0.2,
            accent: false,
            env: 0.0,
            attack_step: 1.0,
            release_coeff: 0.999,
            gate: false,
            drive_amount: 1.0,
            drive_makeup: 1.0,
        };
        voice.set_patch(SubPatch::default());
        voice
    }

    pub fn is_silent(&self) -> bool {
        !self.gate && self.env < 0.0001
    }

    pub fn set_patch(&mut self, patch: SubPatch) {
        self.patch = patch;

        let cutoff_hz = 60.0 * 50f64.powf(patch.cutoff);
        // Chamberlin is only stable well below Nyquist/2.
        let safe = cutoff_hz.min(self.sample_rate / 6.0);
        self.closed_f = 2.0 * (std::f64::consts::PI * safe / self.sample_rate).sin();
        let open = (cutoff_hz * ACCENT_OPEN).min(self.sample_rate / 6.0);
        self.open_f = 2.0 * (std::f64::consts::PI * open / self.sample_rate).sin();
        self.filter_f = if self.accent {
            self.open_f
        } else {
            self.closed_f
        };

        self.attack_step = 1.0 / (ATTACK_SECONDS * self.sample_rate).max(1.0);

        let release_seconds = 0.02 + patch.decay * patch.decay * 0.88;
        // Five time constants to effective silence.
        self.release_coeff = (-5.0 / (release_seconds * self.sample_rate)).exp();

        let glide_seconds = patch.glide * patch.glide * 0.22;
        self.glide_coeff = if glide_seconds <= 0.0 {
            1.0
        } else {
            1.0 - (-5.0 / (glide_seconds * self.sample_rate)).exp()
        };

        self.drive_amount = 1.0 + patch.drive * 11.0;
        self.drive_makeup = 1.0 / (1.0 + patch.drive * 2.2);
    }

    /// Starts a note. With `glide` the pitch slides from wherever it is and the
    /// envelope is not retriggered, which is what a tied cell means. With
    /// `accent` the filter opens for this note and closes again on the next.
    pub fn note_on(&mut self, frequency: f64, glide: bool, accent: bool) {
        self.target_freq = frequency;
        self.gate = true;
        self.accent = accent;
        self.filter_f = if accent { self.open_f } else { self.closed_f };
        if !glide {
            self.freq = frequency;
            self.phase = 0.0;
            self.env = if self.env > 0.35 { self.env } else { 0.0 };
        }
    }

    /// Holds the current pitch without retriggering.
    pub fn hold(&mut self) {
        self.gate = true;
    }

    pub fn note_off(&mut self) {
        self.gate = false;
    }

    /// Hard reset, so a rewind renders identically twice.
    pub fn reset(&mut self) {
        self.phase = 0.0;
        self.env = 0.0;
        self.gate = false;
        self.accent = false;
        self.filter_f = self.closed_f;
        self.low = 0.0;
        self.band = 0.0;
        self.freq = self.target_freq;
    }

    /// One mono sample.
    pub fn next_sample(&mut self) -> f64 {
        if self.is_silent() {
            self.low = 0.0;
            self.band = 0.0;
            return 0.0;
        }

        self.freq += (self.target_freq - self.freq) * self.glide_coeff;

        self.phase += self.freq / self.sample_rate;
        if self.phase >= 1.0 {
            self.phase -= self.phase.floor();
        }

        let sine = (2.0 * std::f64::consts::PI * self.phase).sin();
        let triangle = 4.0 * (self.phase - 0.5).abs() - 1.0;
        let mut x = sine + (triangle - sine) * self.patch.tone;

        // Soft clip into the filter, then take the makeup back out.
        x = soft_clip(x * self.drive_amount) * self.drive_makeup;

        // One lowpass.
        let high = x - self.low - FILTER_Q * self.band;
        self.band += self.filter_f * high;
        self.low += self.filter_f * self.band;

        if self.gate {
            self.env += self.attack_step;
            if self.env > 1.0 {
                self.env = 1.0;
            }
        } else {
            self.env *= self.release_coeff;
        }

        self.low * self.env * if self.accent { ACCENT_GAIN } else { 1.0 }
    }
}

/// Rational tanh approximation. Cheaper than a real one and close enough for a
/// saturator running per sample on a phone. Shared with the master bus, which
/// is the same curve by design.
pub fn soft_clip(x: f64) -> f64 {
    if x < -3.0 {
        return -1.0;
    }
    if x > 3.0 {
        return 1.0;
    }
    let x2 = x * x;
    x * (27.0 + x2) / (27.0 + 9.0 * x2)
}
