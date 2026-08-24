//! junglEngine's audio engine.
//!
//! The mixer and the sub synth, ported from Dart so they can run inside an
//! audio callback, plus the device, the control thread and the C ABI that get
//! them there. See `docs/M4.md` in the app repo for what this is for and how
//! it is measured against the flutter_soloud engine it replaces.

pub mod audio;
pub mod command;
pub mod device;
pub mod ffi;
pub mod offline;
pub mod plan;
pub mod preview;
pub mod renderer;
pub mod spec;
pub mod sub_voice;
pub mod transport;

pub use plan::{Clip, Plan, Sources, Timeline};
pub use renderer::{PatternRenderer, RenderPosition};
pub use spec::{Spec, SpecError};
