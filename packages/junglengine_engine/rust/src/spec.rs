//! The render spec, read from the app's own JSON.
//!
//! This is deliberately the same shape a saved project holds: a `Beat` here
//! parses what `Beat.toJson()` writes over there, field for field, including
//! the two shapes a Chop step can take. One wire format for the file, for the
//! FFI boundary and for the parity fixtures means there is only one thing to
//! keep in step with the Dart models.
//!
//! Parsing is as forgiving as the Dart readers are: anything missing or the
//! wrong type falls back to the same default rather than failing the load. A
//! spec that failed to parse would be silence, and silence is a worse answer
//! than a straight bar.

use serde_json::Value;

pub const STEPS_PER_BAR: usize = 16;
pub const KIT_SLOT_COUNT: usize = 8;

/// Semitone to playback rate, the same table `KitSlot` holds, so a pitched
/// slot never calls `powf` at trigger time.
// The literals below are that table digit for digit. Two of them are near
// enough to std's sqrt(2) constants for clippy to notice; using the constants
// instead would change the last bits, put the two mixers out of step and make
// the parity test right to fail.
#[allow(clippy::approx_constant)]
pub const KIT_RATES: [f64; 25] = [
    0.5,
    0.5297315471,
    0.5612310242,
    0.5946035575,
    0.6299605249,
    0.6674199271,
    0.7071067812,
    0.7491535384,
    0.7937005260,
    0.8408964153,
    0.8908987181,
    0.9438743127,
    1.0,
    1.0594630944,
    1.1224620483,
    1.1892071150,
    1.2599210499,
    1.3348398542,
    1.4142135624,
    1.4983070769,
    1.5874010520,
    1.6817928305,
    1.7817974363,
    1.8877486254,
    2.0,
];

const KIT_MIN_PITCH: i64 = -12;
const KIT_MAX_PITCH: i64 = 12;

#[derive(Debug)]
pub struct SpecError(pub String);

impl std::fmt::Display for SpecError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::error::Error for SpecError {}

/// What a Chop step does to its slice. Data, not code: the mixer reads `rate`
/// and `retriggers` and has no per modifier branch.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StepMod {
    None,
    Reverse,
    Retrigger,
    PitchDown,
    HalfSpeed,
}

impl StepMod {
    pub fn from_code(code: &str) -> Self {
        match code {
            "rev" => StepMod::Reverse,
            "ret" => StepMod::Retrigger,
            "pd" => StepMod::PitchDown,
            "half" => StepMod::HalfSpeed,
            _ => StepMod::None,
        }
    }

    pub fn rate(self) -> f64 {
        match self {
            StepMod::None => 1.0,
            StepMod::Reverse => -1.0,
            StepMod::Retrigger => 1.0,
            StepMod::PitchDown => 0.7491535384,
            StepMod::HalfSpeed => 0.5,
        }
    }

    pub fn retriggers(self) -> i32 {
        match self {
            StepMod::Retrigger => 4,
            _ => 1,
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct ChopStep {
    pub slice: i64,
    pub r#mod: StepMod,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum KitVelocity {
    Soft,
    Medium,
    Hard,
}

impl KitVelocity {
    pub fn gain(self) -> f64 {
        match self {
            KitVelocity::Soft => 0.40,
            KitVelocity::Medium => 0.70,
            KitVelocity::Hard => 1.00,
        }
    }

    fn from_json(value: Option<&Value>) -> Option<Self> {
        match value.and_then(Value::as_i64) {
            Some(1) => Some(KitVelocity::Soft),
            Some(2) => Some(KitVelocity::Medium),
            Some(3) => Some(KitVelocity::Hard),
            _ => None,
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct KitSlot {
    pub volume: f64,
    pub pitch: i64,
}

impl Default for KitSlot {
    fn default() -> Self {
        KitSlot {
            volume: 0.8,
            pitch: 0,
        }
    }
}

impl KitSlot {
    pub fn rate(self) -> f64 {
        let index = (self.pitch - KIT_MIN_PITCH).clamp(0, KIT_RATES.len() as i64 - 1);
        KIT_RATES[index as usize]
    }
}

/// One cell of the sub lane. A note, a tie, an accent, or a rest.
#[derive(Clone, Copy, Debug, Default)]
pub struct SubStep {
    pub semitone: Option<i64>,
    pub tie: bool,
    pub accent: bool,
}

/// The sub synth's entire control surface. Six, and six is the ceiling.
#[derive(Clone, Copy, Debug)]
pub struct SubPatch {
    /// Sine at 0, triangle at 0.5, saw at 1.
    pub tone: f64,
    pub cutoff: f64,
    pub drive: f64,
    pub decay: f64,
    pub glide: f64,
    /// The Reese knob: 0 .. 30 cents either side of the note, 0 being one
    /// oscillator's worth of sound out of the pair.
    pub detune: f64,
}

impl Default for SubPatch {
    fn default() -> Self {
        SubPatch {
            // 0.125 on the three way morph is the 0.25 this default used to be
            // on the old sine to triangle blend. Same sound, new scale.
            tone: 0.125,
            cutoff: 0.45,
            drive: 0.2,
            decay: 0.35,
            glide: 0.3,
            detune: 0.0,
        }
    }
}

#[derive(Clone, Debug)]
pub struct Beat {
    pub id: String,
    pub is_kit: bool,
    pub bars: usize,
    pub slice_count: i64,
    pub swing: f64,
    pub chop: Vec<Option<ChopStep>>,
    /// `kit[slot][step]`.
    pub kit: Vec<Vec<Option<KitVelocity>>>,
    pub kit_slots: Vec<KitSlot>,
    pub sub: Vec<SubStep>,
    pub sub_patch: SubPatch,
    pub sub_root_midi: i64,
}

impl Beat {
    pub fn step_count(&self) -> usize {
        self.bars * STEPS_PER_BAR
    }

    /// How far an odd step is pushed late, as a fraction of one step.
    pub fn swing_offset_fraction(&self) -> f64 {
        self.swing * 0.5
    }

    pub fn slot(&self, index: usize) -> KitSlot {
        self.kit_slots.get(index).copied().unwrap_or_default()
    }
}

/// One Beat's turn on the timeline.
#[derive(Clone, Debug)]
pub struct Section {
    pub beat: Beat,
    /// Which Song card this pass came from, or -1 outside song playback.
    pub entry_index: i32,
}

#[derive(Clone, Debug)]
pub struct Spec {
    pub sample_rate: u32,
    pub bpm: f64,
    pub drum_gain: f64,
    pub sub_gain: f64,
    pub sections: Vec<Section>,
}

impl Spec {
    pub fn from_json_str(text: &str) -> Result<Spec, SpecError> {
        let value: Value = serde_json::from_str(text).map_err(|e| SpecError(e.to_string()))?;
        Spec::from_json(&value)
    }

    pub fn from_json(value: &Value) -> Result<Spec, SpecError> {
        let sample_rate = value
            .get("sampleRate")
            .and_then(Value::as_u64)
            .ok_or_else(|| SpecError("spec has no sampleRate".into()))?;
        let bpm = value
            .get("bpm")
            .and_then(Value::as_f64)
            .ok_or_else(|| SpecError("spec has no bpm".into()))?;
        let sections = match value.get("sections") {
            Some(Value::Array(items)) if !items.is_empty() => items
                .iter()
                .map(|item| Section {
                    beat: read_beat(item.get("beat")),
                    entry_index: item.get("entryIndex").and_then(Value::as_i64).unwrap_or(-1)
                        as i32,
                })
                .collect(),
            _ => return Err(SpecError("spec has no sections".into())),
        };
        Ok(Spec {
            sample_rate: sample_rate as u32,
            bpm,
            drum_gain: read_f64(value.get("drumGain"), 0.92),
            sub_gain: read_f64(value.get("subGain"), 0.80),
            sections,
        })
    }

    /// The Beat this spec is about: whatever plays first.
    pub fn beat(&self) -> &Beat {
        &self.sections[0].beat
    }

    pub fn is_song(&self) -> bool {
        self.sections[0].entry_index >= 0
    }
}

fn read_f64(value: Option<&Value>, fallback: f64) -> f64 {
    value.and_then(Value::as_f64).unwrap_or(fallback)
}

fn read_unit(value: Option<&Value>, fallback: f64) -> f64 {
    match value.and_then(Value::as_f64) {
        Some(v) => v.clamp(0.0, 1.0),
        None => fallback,
    }
}

fn read_beat(value: Option<&Value>) -> Beat {
    let value = value.cloned().unwrap_or(Value::Null);
    let bars = match value.get("bars").and_then(Value::as_u64) {
        Some(b) if matches!(b, 1 | 2 | 4 | 8) => b as usize,
        _ => 1,
    };
    let steps = bars * STEPS_PER_BAR;
    Beat {
        id: value
            .get("id")
            .and_then(Value::as_str)
            .unwrap_or("beat")
            .to_string(),
        is_kit: value.get("machine").and_then(Value::as_str) == Some("kit"),
        bars,
        slice_count: value
            .get("sliceCount")
            .and_then(Value::as_i64)
            .unwrap_or(16),
        swing: read_unit(value.get("swing"), 0.0),
        chop: read_chop(value.get("chop"), steps),
        kit: read_kit(value.get("kit"), steps),
        kit_slots: read_kit_slots(value.get("kitSlots")),
        sub: read_sub(value.get("sub"), steps),
        sub_patch: read_patch(value.get("subPatch")),
        sub_root_midi: value
            .get("subRootMidi")
            .and_then(Value::as_i64)
            .unwrap_or(36),
    }
}

/// A plain step is a bare integer, which is what M0 and M1 files hold. Only a
/// modified step costs a map.
fn read_chop(value: Option<&Value>, steps: usize) -> Vec<Option<ChopStep>> {
    let empty = Vec::new();
    let items = match value {
        Some(Value::Array(items)) => items,
        _ => &empty,
    };
    (0..steps)
        .map(|i| match items.get(i) {
            Some(Value::Number(n)) => n.as_i64().map(|slice| ChopStep {
                slice,
                r#mod: StepMod::None,
            }),
            Some(Value::Object(map)) => {
                map.get("s").and_then(Value::as_i64).map(|slice| ChopStep {
                    slice,
                    r#mod: map
                        .get("m")
                        .and_then(Value::as_str)
                        .map(StepMod::from_code)
                        .unwrap_or(StepMod::None),
                })
            }
            _ => None,
        })
        .collect()
}

fn read_kit(value: Option<&Value>, steps: usize) -> Vec<Vec<Option<KitVelocity>>> {
    let empty = Vec::new();
    let rows = match value {
        Some(Value::Array(rows)) => rows,
        _ => &empty,
    };
    (0..KIT_SLOT_COUNT)
        .map(|slot| {
            (0..steps)
                .map(|step| {
                    KitVelocity::from_json(
                        rows.get(slot)
                            .and_then(Value::as_array)
                            .and_then(|row| row.get(step)),
                    )
                })
                .collect()
        })
        .collect()
}

fn read_kit_slots(value: Option<&Value>) -> Vec<KitSlot> {
    let empty = Vec::new();
    let items = match value {
        Some(Value::Array(items)) => items,
        _ => &empty,
    };
    (0..KIT_SLOT_COUNT)
        .map(|i| match items.get(i) {
            Some(item) => KitSlot {
                volume: read_unit(item.get("vol"), 0.8),
                pitch: item
                    .get("pitch")
                    .and_then(Value::as_i64)
                    .unwrap_or(0)
                    .clamp(KIT_MIN_PITCH, KIT_MAX_PITCH),
            },
            None => KitSlot::default(),
        })
        .collect()
}

fn read_sub(value: Option<&Value>, steps: usize) -> Vec<SubStep> {
    let empty = Vec::new();
    let items = match value {
        Some(Value::Array(items)) => items,
        _ => &empty,
    };
    (0..steps)
        .map(|i| match items.get(i) {
            Some(Value::Object(map)) => SubStep {
                semitone: map.get("n").and_then(Value::as_i64),
                tie: map.get("t") == Some(&Value::Bool(true)),
                accent: map.get("a") == Some(&Value::Bool(true)),
            },
            _ => SubStep::default(),
        })
        .collect()
}

/// No `tone` migration here, unlike `SubPatch.fromJson` on the Dart side.
///
/// That one reads project files a user saved months ago. This one reads a
/// render spec Dart just wrote, so `tone` is always already on the three way
/// scale and `detune` is always present. Migrating twice would halve a live
/// patch.
fn read_patch(value: Option<&Value>) -> SubPatch {
    let d = SubPatch::default();
    match value {
        Some(v) if v.is_object() => SubPatch {
            tone: read_unit(v.get("tone"), d.tone),
            cutoff: read_unit(v.get("cutoff"), d.cutoff),
            drive: read_unit(v.get("drive"), d.drive),
            decay: read_unit(v.get("decay"), d.decay),
            glide: read_unit(v.get("glide"), d.glide),
            detune: read_unit(v.get("detune"), d.detune),
        },
        _ => d,
    }
}

/// Converts a MIDI note number to Hz.
pub fn midi_to_hz(midi: f64) -> f64 {
    440.0 * 2f64.powf((midi - 69.0) / 12.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The FFI boundary will be handed whatever a saved project holds,
    /// including files written by M0, so the reader has to default the way the
    /// Dart one does rather than refuse.
    #[test]
    fn a_bare_beat_reads_as_a_straight_chop_bar() {
        let spec = Spec::from_json_str(
            r#"{"sampleRate":44100,"bpm":170,"sections":[{"beat":{}}]}"#,
        )
        .expect("a spec with a bare beat should parse");

        let beat = spec.beat();
        assert!(!beat.is_kit);
        assert_eq!(beat.bars, 1);
        assert_eq!(beat.step_count(), 16);
        assert_eq!(beat.slice_count, 16);
        assert_eq!(beat.sub_root_midi, 36);
        assert_eq!(beat.swing, 0.0);
        assert_eq!(beat.sub_patch.cutoff, SubPatch::default().cutoff);
        assert_eq!(beat.kit_slots.len(), KIT_SLOT_COUNT);
        assert!(beat.chop.iter().all(Option::is_none));
        assert!(beat.sub.iter().all(|s| s.semitone.is_none() && !s.tie));
        assert_eq!(spec.drum_gain, 0.92);
        assert_eq!(spec.sections[0].entry_index, -1);
        assert!(!spec.is_song());
    }

    /// A plain step is a bare integer and a modified one is a map. Both shapes
    /// are in saved projects, so both have to read.
    #[test]
    fn chop_steps_read_in_both_shapes() {
        let spec = Spec::from_json_str(
            r#"{"sampleRate":44100,"bpm":170,"sections":[{"entryIndex":2,"beat":{
                "chop":[3,{"s":5,"m":"rev"},{"s":6,"m":"nonsense"},null]
            }}]}"#,
        )
        .expect("chop steps should parse");

        let chop = &spec.beat().chop;
        assert_eq!(chop[0].unwrap().slice, 3);
        assert_eq!(chop[0].unwrap().r#mod, StepMod::None);
        assert_eq!(chop[1].unwrap().slice, 5);
        assert_eq!(chop[1].unwrap().r#mod, StepMod::Reverse);
        // An unknown code is a modifier this build does not have, which is a
        // plain step rather than a broken file.
        assert_eq!(chop[2].unwrap().r#mod, StepMod::None);
        assert!(chop[3].is_none());
        assert!(spec.is_song());
    }

    /// The kit grid writes 0 for an empty cell, not null.
    #[test]
    fn kit_cells_read_velocity_or_nothing() {
        let spec = Spec::from_json_str(
            r#"{"sampleRate":44100,"bpm":170,"sections":[{"beat":{
                "machine":"kit",
                "kit":[[3,0,2,1]],
                "kitSlots":[{"vol":0.5,"pitch":-24},{"vol":2.0,"pitch":7}]
            }}]}"#,
        )
        .expect("a kit beat should parse");

        let beat = spec.beat();
        assert!(beat.is_kit);
        assert_eq!(beat.kit[0][0], Some(KitVelocity::Hard));
        assert_eq!(beat.kit[0][1], None);
        assert_eq!(beat.kit[0][2], Some(KitVelocity::Medium));
        assert_eq!(beat.kit[0][3], Some(KitVelocity::Soft));
        assert_eq!(beat.kit[1][0], None);
        // Out of range settings clamp instead of throwing, as they do in Dart.
        assert_eq!(beat.slot(0).pitch, -12);
        assert_eq!(beat.slot(0).rate(), 0.5);
        assert_eq!(beat.slot(1).volume, 1.0);
        assert_eq!(beat.slot(7).volume, KitSlot::default().volume);
    }

    #[test]
    fn a_spec_without_sections_is_an_error() {
        assert!(Spec::from_json_str(r#"{"sampleRate":44100,"bpm":170}"#).is_err());
        assert!(
            Spec::from_json_str(r#"{"sampleRate":44100,"bpm":170,"sections":[]}"#).is_err()
        );
        assert!(Spec::from_json_str("{").is_err());
    }
}
