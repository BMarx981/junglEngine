//! The control thread, and the device it owns.
//!
//! One thread owns the cpal stream for its whole life. Every call from Dart
//! arrives here as a message rather than touching the stream directly, because
//! `cpal::Stream` is not `Send` on every backend and because opening, closing
//! and reopening a device is exactly the sort of slow, fallible thing that
//! must not happen on a caller's thread.
//!
//! The shape is `lira_graph::controller`, minus everything a phone does not
//! have: no device pickers, no input capture, no MIDI, no worker pool. One
//! output, opened once.

use std::sync::atomic::AtomicU64;
use std::sync::mpsc::{self, Receiver, RecvTimeoutError, Sender};
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use std::time::Duration;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleFormat, StreamConfig};

use crate::audio::AudioSide;
use crate::command::{Command, Publication, Retired, When};
use crate::plan::Plan;
use crate::renderer::PatternRenderer;
use crate::transport::TransportShared;

/// Commands control to audio. Drained every callback, so this only has to
/// absorb one block's worth of taps.
const COMMAND_CAPACITY: usize = 256;

/// Plans in flight control to audio. An edit publishes one; the callback
/// drains every block. Deep enough to absorb a whole drag of the tempo slider
/// between two callbacks.
const PLAN_CAPACITY: usize = 32;

/// Retired plans and clips audio to control. Sized past everything that feeds
/// it so the callback's push can never fail: a failed push there would mean
/// deallocating on the audio thread.
const TRASH_CAPACITY: usize = (PLAN_CAPACITY + COMMAND_CAPACITY) * 2;

/// How often the control loop wakes to drop retired plans while idle.
const TRASH_TICK: Duration = Duration::from_millis(200);

/// What the device is asked for. Small enough that an edit lands quickly,
/// large enough that the render loop is cheap. The device is free to give
/// something else, and CoreAudio and AAudio both do.
const PREFERRED_BLOCK_FRAMES: u32 = 512;

#[derive(Debug)]
pub enum DeviceError {
    NoOutputDevice,
    UnsupportedConfig(String),
    BuildStream(String),
    PlayStream(String),
    ControlThreadDown,
}

impl std::fmt::Display for DeviceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DeviceError::NoOutputDevice => write!(f, "no default audio output device"),
            DeviceError::UnsupportedConfig(e) => write!(f, "unsupported output config: {e}"),
            DeviceError::BuildStream(e) => write!(f, "could not build the output stream: {e}"),
            DeviceError::PlayStream(e) => write!(f, "could not start the output stream: {e}"),
            DeviceError::ControlThreadDown => write!(f, "the audio control thread is not running"),
        }
    }
}

impl std::error::Error for DeviceError {}

enum ControlMsg {
    Publish(Publication),
    Command(Command),
    Shutdown,
}

/// The engine, from the control side. Everything Dart holds a handle to.
pub struct Engine {
    to_control: Sender<ControlMsg>,
    control: Option<JoinHandle<()>>,

    /// The rate the device actually opened at, which is not always the one it
    /// was asked for: phones run their own clock and a 48 kHz device will
    /// simply say so. Everything the app decodes is resampled to this.
    sample_rate: u32,

    transport: Arc<TransportShared>,

    /// Publications so far. Stamped into each plan so the Dart side can tell
    /// which spec the playhead it is reading belongs to.
    next_plan_id: u64,
}

impl Engine {
    /// Opens the device and starts the control thread. The stream runs from
    /// here until shutdown, whether or not the sequencer is playing: that is
    /// what makes a tapped pad sound at once instead of after a stream start.
    pub fn new(requested_rate: u32, first_plan: Box<Plan>) -> Result<Engine, DeviceError> {
        let transport = Arc::new(TransportShared::default());
        let frame = Arc::new(AtomicU64::new(0));
        let (to_control, from_app) = mpsc::channel();
        let (rate_out, rate_in) = mpsc::channel();

        let control_transport = Arc::clone(&transport);
        let control_frame = Arc::clone(&frame);
        let control = thread::Builder::new()
            .name("junglengine-audio-control".into())
            .spawn(move || {
                control_loop(
                    requested_rate,
                    first_plan,
                    from_app,
                    rate_out,
                    control_transport,
                    control_frame,
                );
            })
            .map_err(|e| DeviceError::BuildStream(e.to_string()))?;

        match rate_in.recv() {
            Ok(Ok(sample_rate)) => Ok(Engine {
                to_control,
                control: Some(control),
                sample_rate,
                transport,
                next_plan_id: 1,
            }),
            Ok(Err(error)) => {
                let _ = control.join();
                Err(error)
            }
            Err(_) => Err(DeviceError::ControlThreadDown),
        }
    }

    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    pub fn transport(&self) -> &Arc<TransportShared> {
        &self.transport
    }

    pub fn next_plan_id(&mut self) -> u64 {
        let id = self.next_plan_id;
        self.next_plan_id += 1;
        id
    }

    /// The id of the most recent publication. The transport reports which plan
    /// the playhead belongs to, and that is only the newest one once a queued
    /// Beat swap has actually landed.
    pub fn last_plan_id(&self) -> u64 {
        self.next_plan_id - 1
    }

    pub fn publish(&self, plan: Box<Plan>, when: When) -> Result<(), DeviceError> {
        self.send(ControlMsg::Publish(Publication { plan, when }))
    }

    pub fn command(&self, command: Command) -> Result<(), DeviceError> {
        self.send(ControlMsg::Command(command))
    }

    fn send(&self, message: ControlMsg) -> Result<(), DeviceError> {
        self.to_control
            .send(message)
            .map_err(|_| DeviceError::ControlThreadDown)
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        let _ = self.to_control.send(ControlMsg::Shutdown);
        if let Some(control) = self.control.take() {
            // Joining is what closes the device: the stream lives on that
            // thread's stack and nothing else may drop it.
            let _ = control.join();
        }
    }
}

fn control_loop(
    requested_rate: u32,
    first_plan: Box<Plan>,
    from_app: Receiver<ControlMsg>,
    rate_out: Sender<Result<u32, DeviceError>>,
    transport: Arc<TransportShared>,
    frame: Arc<AtomicU64>,
) {
    let (mut commands_tx, commands_rx) = rtrb::RingBuffer::new(COMMAND_CAPACITY);
    let (mut plans_tx, plans_rx) = rtrb::RingBuffer::new(PLAN_CAPACITY);
    let (trash_tx, mut trash_rx) = rtrb::RingBuffer::new(TRASH_CAPACITY);

    let renderer = PatternRenderer::new(first_plan);
    let audio = AudioSide::new(
        renderer,
        commands_rx,
        plans_rx,
        trash_tx,
        Arc::clone(&transport),
        Arc::clone(&frame),
        requested_rate,
    );

    let stream = match open_stream(requested_rate, audio) {
        Ok(stream) => {
            let _ = rate_out.send(Ok(stream.sample_rate));
            stream
        }
        Err(error) => {
            let _ = rate_out.send(Err(error));
            return;
        }
    };

    // Whatever the callback is finished with, dropped here. Nothing below is
    // on an audio thread, so all of it is allowed to take as long as it likes.
    let drop_trash = |trash: &mut rtrb::Consumer<Retired>| while trash.pop().is_ok() {};

    loop {
        match from_app.recv_timeout(TRASH_TICK) {
            Ok(ControlMsg::Publish(publication)) => {
                // A full ring means the callback has not run since the last 32
                // edits, which on a live stream does not happen. If it ever
                // did, the newest plan is the one worth keeping and the
                // dropped one is superseded by it anyway.
                if let Err(rejected) = plans_tx.push(publication) {
                    drop(rejected);
                }
            }
            Ok(ControlMsg::Command(command)) => {
                if let Err(rejected) = commands_tx.push(command) {
                    drop(rejected);
                }
            }
            Ok(ControlMsg::Shutdown) => break,
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => break,
        }
        drop_trash(&mut trash_rx);
    }

    // Stopping the stream first means the callback is not running while the
    // last plans are dropped.
    drop(stream);
    drop_trash(&mut trash_rx);
}

/// The stream, and the rate it actually opened at.
struct OpenStream {
    #[allow(dead_code)]
    stream: cpal::Stream,
    sample_rate: u32,
}

fn open_stream(requested_rate: u32, audio: AudioSide) -> Result<OpenStream, DeviceError> {
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or(DeviceError::NoOutputDevice)?;

    let mut config = output_config(&device, requested_rate)?;
    let sample_rate = config.sample_rate;
    let channels = config.channels as usize;

    // Wrapped so the fallback below can hand the same callback to a second
    // attempt: `build_output_stream` consumes it.
    let mut audio = Some(audio);
    let mut build = |config: StreamConfig| {
        let mut side = audio.take().expect("built at most twice");
        device.build_output_stream(
            config,
            move |out: &mut [f32], _| {
                let frames = out.len() / channels;
                side.process(out, frames);
            },
            |error| {
                // Nothing to be done from here, and nothing that may allocate:
                // the Dart side sees this as the transport going quiet, and
                // `audio_session` is what handles the interruptions that cause
                // it.
                eprintln!("junglengine: output stream error: {error}");
            },
            None,
        )
    };

    // A short block is the whole point -- it is the delay between painting a
    // step and hearing it -- but it is a request. Some devices only run at the
    // size they have chosen, and being told no is not a reason to have no
    // audio at all.
    let stream = match build(config) {
        Ok(stream) => stream,
        Err(preferred) => {
            config.buffer_size = cpal::BufferSize::Default;
            match build(config) {
                Ok(stream) => stream,
                Err(_) => return Err(DeviceError::BuildStream(preferred.to_string())),
            }
        }
    };

    stream
        .play()
        .map_err(|e| DeviceError::PlayStream(e.to_string()))?;

    Ok(OpenStream {
        stream,
        sample_rate,
    })
}

/// Stereo f32 at the requested rate if the device will take it, and whatever
/// the device runs at if it will not.
///
/// A phone runs its own clock. Asking a 48 kHz device for 44.1 and being told
/// no is the normal case, not a failure: the app resamples what it decodes to
/// [`Engine::sample_rate`], so the only thing that matters is that both sides
/// agree on the number.
fn output_config(
    device: &cpal::Device,
    requested_rate: u32,
) -> Result<StreamConfig, DeviceError> {
    let supported: Vec<_> = device
        .supported_output_configs()
        .map_err(|e| DeviceError::UnsupportedConfig(e.to_string()))?
        .filter(|range| range.sample_format() == SampleFormat::F32)
        .filter(|range| range.channels() == 2)
        .collect();

    if supported.is_empty() {
        return Err(DeviceError::UnsupportedConfig(
            "no stereo f32 output config".into(),
        ));
    }

    let requested = requested_rate;
    let picked = supported
        .iter()
        .find(|range| {
            range.min_sample_rate() <= requested && requested <= range.max_sample_rate()
        })
        .map(|range| range.with_sample_rate(requested))
        .unwrap_or_else(|| {
            supported
                .iter()
                .min_by_key(|range| {
                    range
                        .max_sample_rate()
                        .abs_diff(requested_rate)
                        .min(range.min_sample_rate().abs_diff(requested_rate))
                })
                .expect("checked non-empty")
                .with_max_sample_rate()
        });

    let mut config: StreamConfig = picked.into();
    config.buffer_size = cpal::BufferSize::Fixed(PREFERRED_BLOCK_FRAMES);
    Ok(config)
}
