//! junglEngine's audio engine.
//!
//! The mixer and the sub synth, ported from Dart so they can run inside an
//! audio callback. Nothing here knows about devices yet: that is the next
//! stage. See `docs/M4.md` in the app repo for what this is for and how it is
//! measured against the flutter_soloud engine it replaces.

pub mod renderer;
pub mod spec;
pub mod sub_voice;

pub use renderer::{Clip, PatternRenderer, RenderPosition, Sources};
pub use spec::{Spec, SpecError};
