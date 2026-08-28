//! What crosses the control/audio boundary, in both directions.
//!
//! Control to audio is one lock free SPSC ring of the values below. Audio to
//! control is a second ring carrying nothing but things to drop, because the
//! audio thread is not allowed to deallocate: a `free` under a callback is a
//! dropout waiting for an unlucky allocator.

use crate::plan::{Clip, Plan};

/// When a published plan takes over. The Dart side's `SpecChange`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum When {
    /// At the next block boundary, without interrupting anything ringing.
    /// What every edit wants: paint a step and hear it on the next pass.
    Now,

    /// At the end of the bar being played. Changing which Beat is playing is a
    /// musical move rather than an edit, so it waits for the bar rather than
    /// chopping it in half. Falls back to [`When::Now`] with the transport
    /// stopped, because then there is no bar to wait for.
    NextBar,
}

impl When {
    /// The wire value. 0 and 1 are `SpecChange.now` and `SpecChange.nextBar`
    /// in that enum's declaration order.
    pub fn from_code(code: i32) -> When {
        match code {
            1 => When::NextBar,
            _ => When::Now,
        }
    }
}

/// One plan, on its way to the callback.
pub struct Publication {
    pub plan: Box<Plan>,
    pub when: When,
}

/// Everything else the control thread can ask for. Small and `Copy` apart from
/// the one variant that carries audio, which is the import screen previewing a
/// file that is not in the project yet.
pub enum Command {
    /// Rewind and run the sequencer.
    Start,
    /// Stop the sequencer and rewind. The stream stays open, so a pad still
    /// sounds the instant it is touched.
    Stop,
    /// Drop whatever [`When::NextBar`] queued, leaving what is playing alone.
    CancelQueued,
    AuditionSlice(i32),
    /// A Kit slot, and the level to sound it at: 1, 2 or 3 when the tap wrote
    /// a step, and anything else for a pad tap, which has no velocity on it.
    AuditionKitSlot {
        slot: i32,
        velocity: i32,
    },
    AuditionClip { clip: Clip, looping: bool },
    StopAuditionClip,
}

/// Something the callback is finished with, going back to be dropped on the
/// control thread.
pub enum Retired {
    Plan(Box<Plan>),
    Clip(Clip),
}

impl From<Box<Plan>> for Retired {
    fn from(plan: Box<Plan>) -> Retired {
        Retired::Plan(plan)
    }
}

impl From<Clip> for Retired {
    fn from(clip: Clip) -> Retired {
        Retired::Clip(clip)
    }
}
